# Model author guide

This guide describes the supported route for adding a model without changing
`src/+lmz`. Executable reference implementations are the generated
`example_hopper` project produced by `tools/new_model.m`, the built-in
`tutorial_hopper`, and the separate external analytic hopper under
`tests/fixtures/external_plugins/analytic_hopper`.

## Generate an inactive project

Start Legged Model Zoo, add the tools directory for the command, and generate
into a new external directory:

```matlab
startup;
toolsPath = fullfile(lmz.util.ProjectPaths.root(), 'tools');
addpath(toolsPath);
cleanup = onCleanup(@() rmpath(toolsPath));
outputRoot = fullfile(tempdir, 'my_lmz_plugin');
mkdir(outputRoot);
report = new_model('example_hopper', outputRoot);
registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
    outputRoot, 'IncludeBuiltIns', false);
model = registry.createModel('example_hopper');
```

The generator creates `models/+lmzmodels/+example_hopper`,
`catalog/example_hopper`, `tests/generated/example_hopper`, an executable
example, and `plugin.json`. It rejects IDs already owned by the built-in
catalog and refuses to activate the production catalog unless
`ActivateProductionCatalog=true` is explicit.

## Package and manifest

A model derives from `lmz.api.LeggedModel`. It provides identity and version,
capabilities, physical-state and parameter schemas, problem construction,
simulation, named kinematics, and plot descriptors. The catalog manifest binds
the model ID to the implementation class. IDs use lowercase letters, digits,
and underscores; the catalog directory must equal the ID.

External roots are executable MATLAB code. Register one only after reviewing
it:

```matlab
registry = lmz.registry.ModelRegistry.discoverWithPlugins('/reviewed/plugin');
```

Registration validates `plugin.json`, adds exactly its declared `models`
directory, checks that the resolved class is inside that canonical root, and
removes the path lease with the registry. It never recursively adds a tree.

## Problem descriptors and maturity

Place one descriptor in `catalog/<id>/problems/<problem-id>.json` per problem.
Choose `simulation`, `nonlinear_equation`, or `optimization`. Record
`implemented`, `maturity`, `validationStatus`, provenance, and the exact
capabilities. Maturity belongs to the problem, not the model:

- `tutorial`: explanatory analytic behavior;
- `experimental`: usable but not a validated scientific claim;
- `compatibility`: preserved import/evaluator boundary;
- `validated`: evidence-backed scientific behavior.

Only `source-equivalent` may describe a comparison with an immutable source
baseline. The registry derives model-level capabilities from implemented
problem descriptors.

## State, parameter, and decision schemas

Build ordered schemas from `lmz.schema.VariableSpec`. Specify units, scale,
bounds, topology, activity, role, and energy effect. Solver decisions belong to
the problem; integrated physical state belongs to the model. Do not reuse
legacy matrix row numbers outside a named layout/adapter.

```matlab
height = lmz.schema.VariableSpec('height', 'Unit', 'm', ...
    'DefaultValue', 1, 'LowerBound', 0.1, 'UpperBound', 3, ...
    'Scale', 1, 'Topology', 'bounded', 'Role', 'physical', ...
    'EnergyEffect', 'state_dependent');
schema = lmz.schema.VariableSchema(height);
```

Roles are `physical`, `control`, `schedule`, and `derived`; energy effects are
`invariant`, `state_dependent`, `work_input`, and `unknown`. Old artifacts
without these fields load conservatively as `physical`/`unknown`. Do not call a
stiffness or rest-length change energy neutral merely because state is fixed.

## Simulation and hybrid modes

Simple models may construct `SimulationResult` directly. Hybrid models derive
from `lmz.simulation.HybridSystem` and supply modes, an event policy, and reset
maps. `HybridSimulator` orders simultaneous events by time, priority, and
declaration order. The public trajectory retains the final post-event sample
at a repeated time; `EventRecords` retain both pre- and post-event states.
Guard callbacks live only in trusted MATLAB code and are never read from JSON.

The built-in scheduled-impact example is
`models/+lmzmodels/+tutorial_hopper/HopperSystem.m`. The isolated namespace
variant used to prove external discovery is
`tests/fixtures/external_plugins/analytic_hopper/models/+lmzplugins/+analytic_hopper/HopperSystem.m`.

## Nonlinear and optimization problems

Derive periodic residual problems from `NonlinearEquationProblem`. Return
named `ResidualBlock` values in `ProblemEvaluation`. For decision dimension
`n` and residual Jacobian `J_F`, a regular one-dimensional continuation family
requires

\[
n-\operatorname{rank}(J_F)=1.
\]

Do not impose the overly restrictive generic rule that residual row count must
equal `n-1`; formulation-specific redundant rows are possible. Derive fitting
problems from `OptimizationProblem`, return a scalar objective, named terms,
diagnostics, constraints, and bounds. Numerical services call these contracts;
model code does not call `fsolve`, `fmincon`, or continuation engines directly.

## Poincaré sections and strides

Declare built-in sections in `catalog/<id>/poincare_sections.json` and load
them with `PoincareSectionRegistry`. Supported declarative kinds are
`named_event`, `state_plane`, and `composite`. Record direction, pre/post side,
minimum return time, required event sequence, occurrence, section coordinates,
symmetry, maturity, and validation status. JSON is data only; nonlinear section
code must resolve uniquely inside the explicitly trusted plugin root.

Use `StrideDefinition` to bind start/stop section fingerprints and symmetry.
Suppress the initial section root until minimum return time and required events
are satisfied. Diagnose grazing through directional derivatives. Translation
invariance uses `PlanarTranslationSymmetry`, never an undocumented dropped
state index. See [poincare-sections.md](poincare-sections.md).

## Contact timing versus periodicity

A model that supports timing-only solve implements
`lmz.schedule.ContactConstraintProvider`. Its evaluation receives fixed initial
state, fixed physical parameters, and one explicit `EventSchedule`; it returns
contact rows and one stop-section row. It must not add state-periodicity rows or
run a hidden solver. `SectionReturnTimingProblem` and `ContactTimingService`
own charting and orchestration.

A periodic problem separately compares returned and initial section
coordinates under the declared symmetry. Do not reuse a timing-only result as
a periodicity claim. See [contact-timing-solve.md](contact-timing-solve.md).

## Multi-stride and energy contracts

Represent each stride with `StrideSpec` and the sequence with `StridePlan`.
Completion is explicit through `MissingStridePolicy`; `request_user` returns a
structured missing-data result and never opens a prompt. Runtime provider,
checkpoint, or timing-corrector callbacks are trusted configuration and are not
serialized.

Physical parameters copy exactly by default. Schedule changes use named
completion policies. Control changes require a model-specific energy check;
unknown energy effects are rejected. Validate
`E(x,p_after)-E(x,p_before)-declaredWork` with `EnergyConsistencyPolicy` and
record diagnostics. Complete schedules before optimization or expose timings as
decision variables—never solve timings invisibly inside an objective. See
[multi-stride-planning.md](multi-stride-planning.md).

## Kinematics, scenes, and plots

Return a `lmz.viz.PlotPlugin` from `getVisualizationPlugin`. Its
`KinematicsFrame` maps declared scene frame names to finite 2-D poses.
`SceneRenderer2D` consumes only validated declarative primitives. See
[visualization-authoring.md](visualization-authoring.md).

## Built-in data and legacy adapters

Built-in data manifests record relative paths, SHA-256 values, dimensions,
source commits, and redistribution decisions. Resolve every relative path
inside the manifest root. If a legacy format is required, isolate raw indexing
and import/export in one adapter and retain a native artifact round-trip test.
Never put legacy indexing into GUI or generic service code.

## Artifacts and GUI integration

Use `Solution.toArtifact`, result `toArtifact` methods, and `ArtifactStore`.
Do not serialize model objects or callbacks. Registry-bound problems propagate
their descriptors into solutions. Generic GUI integration comes from problem
capabilities and `getVisualizationPlugin`; no model-ID branch is required.

## Required tests

At minimum test discovery, descriptor validation, schema ordering and role
metadata, default simulation, section crossing/transversality, timing-only fixed
data, residual/objective, solve where advertised, Jacobian rank for continuation,
short continuation where advertised, stride completion/energy policies, scene
construction, artifact round trip, malformed inputs, absence of core prompts,
and clean removal of an external registration. Follow
[testing-a-model.md](testing-a-model.md) and the executable sequence in
[getting-started-build-a-model.md](getting-started-build-a-model.md).
