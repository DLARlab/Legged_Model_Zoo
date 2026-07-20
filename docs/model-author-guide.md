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
bounds, topology, and activity. Solver decisions belong to the problem;
integrated physical state belongs to the model. Do not reuse legacy matrix row
numbers outside a named layout/adapter.

```matlab
height = lmz.schema.VariableSpec('height', 'Unit', 'm', ...
    'DefaultValue', 1, 'LowerBound', 0.1, 'UpperBound', 3, ...
    'Scale', 1, 'Topology', 'bounded');
schema = lmz.schema.VariableSchema(height);
```

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
named `ResidualBlock` values in `ProblemEvaluation`; an `n`-decision,
`n-1`-residual full-rank formulation supports one-dimensional continuation.
Derive fitting problems from `OptimizationProblem`, return a scalar objective,
named terms, diagnostics, constraints, and bounds. Numerical services call
these contracts; model code does not call `fsolve`, `fmincon`, or continuation
engines directly.

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

At minimum test discovery, descriptor validation, schema ordering, default
simulation, residual/objective, solve where advertised, short continuation
where advertised, scene construction, artifact round trip, malformed inputs,
and clean removal of an external registration. Follow
[testing-a-model.md](testing-a-model.md).
