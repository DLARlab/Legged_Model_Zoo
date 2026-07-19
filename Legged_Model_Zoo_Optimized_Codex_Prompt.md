# Optimized Codex Implementation Prompt — Legged Model Zoo

Act as the senior MATLAB software architect and implementation engineer for a new project named **Legged Model Zoo**. Work directly in the local workspace. Produce runnable code, tests, examples, migration records, and a working GUI vertical slice—not only plans or architecture documents.

## 1. Local inputs and target workspace

The workspace contains local clones of these repositories, but their absolute paths are unknown:

1. `2022_A_Template_Model_Explains_Jerboa_Gait_Transitions`
2. `2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights`
3. `SLIP_Model_Zoo`

Locate them using local filesystem tools such as `find`, `rg --files`, and `rg`. Do not clone, download, or use the network. When Git metadata exists, verify candidate directories from their `origin` remotes and record the selected paths and commit SHAs.

Treat all three repositories as immutable reference inputs. Do not edit, rename, reformat, delete, or commit files inside them.

Create the new project at `$TARGET_DIR` when that environment variable is defined. Otherwise create a sibling directory named `Legged_Model_Zoo` under the common workspace root. Do not overwrite nonempty existing work. If the target already contains a partial project, inspect it, preserve valid work, and continue incrementally.

The new project must run without adding the three source repositories to the MATLAB path. Copy or adapt only the minimal required legacy files into an isolated `vendor/dlar/` area, preserving copyright/license headers and recording provenance and modifications.

## 2. Mission and implementation priority

Build a MATLAB object-oriented framework that generalizes:

- hybrid legged-model simulation;
- periodic-solution search and refinement;
- deterministic multistart search;
- optimization and experimental-data fitting;
- one-dimensional numerical continuation;
- parameter homotopy and branch-family scans;
- solution-branch visualization and gait classification;
- model visualization, animation, and recording;
- versioned, self-describing persistence;
- an extensible programmatic `uifigure` GUI.

Implement in this priority order:

1. inventory and reproducible legacy baselines;
2. core contracts, schemas, registry, data objects, and persistence;
3. complete SLIP quadruped command-line vertical slice;
4. generic solution search and continuation extracted from the quadruped code;
5. minimal class-based GUI using the generic services;
6. Jerboa migration through the same APIs;
7. load-pulling quadruped migration and objective decomposition;
8. native hybrid-dynamics refactoring only after adapter regression tests pass.

Do not begin broad GUI polish or superficial migration of all models before the quadruped vertical-slice gate passes. Do not ask for confirmation between phases. Make conservative, documented assumptions and proceed. When a task is blocked, record the exact blocker and continue with independent work.

## 3. Compatibility and non-negotiable rules

1. MATLAB is the primary language. Preserve compatibility with the oldest release required by the local projects; absent contrary evidence, target MATLAB R2019b or later and avoid language/library features unavailable in the chosen minimum release.
2. Optimization Toolbox may be required for numerical solving. Parallel Computing Toolbox is optional and must never be required for the synchronous path.
3. Do not use `global` variables in new framework code.
4. Do not use `restoredefaultpath`, `addpath(genpath(...))`, `eval`, `evalin`, or `assignin`.
5. `startup.m` may add only the project `src` and `models` code roots explicitly. Catalogs, examples, apps, tests, fixtures, and documentation are accessed by path and are not recursively added.
6. Generic framework packages must not contain model-specific positional indices such as `X(14:22)`, `P(15)`, or `results(23:29,:)`.
7. Positional indexing is allowed only in a named model-specific layout or legacy adapter, with a schema comment and unit/regression tests.
8. JSON is declarative. Never evaluate code or expressions from JSON. A manifest may name a validated implementation ID or a class restricted to approved namespaces such as `lmzmodels.*`.
9. Keep model physics, numerical problems, algorithms, orchestration services, runtime data, and presentation as separate layers.
10. Preserve legacy MAT compatibility only through explicit import/export adapters.
11. Every random perturbation must accept and record an RNG seed or stream.
12. Long-running work receives progress, pause, cancellation, logging, RNG, and checkpoint facilities through a GUI-independent `RunContext`.
13. A native residual or objective evaluation must be deterministic and must not launch another solver internally.
14. Event-time projection, seed repair, and parameter transforms are explicit operations, not hidden side effects of residual evaluation.
15. Do not silently apply `abs`, clipping, or arbitrary replacement to physical parameters in native code. Use validation, bounds, or an explicit documented transform. Legacy compatibility transforms must be reported in diagnostics.
16. Do not silently change numerical behavior before regression fixtures exist.
17. Do not claim a numerical result, equivalence result, or test passed unless it was actually executed.
18. Do not label a heuristic contact-pattern change as a proven bifurcation. Name it `TopologyChangeGuard` unless a mathematically justified Jacobian-rank or eigenvalue criterion is implemented.
19. Do not call a repeated parameter scan “two-dimensional continuation.” Name it `BranchFamilyScan`; reserve `SurfaceContinuation` for a future method that traces a two-dimensional solution manifold.

## 4. Required architecture

Use this dependency direction:

```text
GUI -> application services -> numerical algorithms -> Problem interface
                                                     -> Model/simulator

Visualization <- SimulationResult
Persistence   <- Solution / SolutionBranch / RunRecord
```

The GUI must never directly call `fsolve`, `fmincon`, `fminsearch`, a concrete legacy zero function, or a legacy continuation routine.

Implement these distinct concepts.

### 4.1 Model

A model owns physical meaning:

- physical state and parameter schemas;
- hybrid modes, flows, guards, scheduled events, and reset maps;
- physical simulation;
- kinematics and named visual frames;
- named outputs and observables;
- supported problem factories and capability flags.

Do not create inheritance by leg count. Use composition and capabilities.

### 4.2 Problem

A problem owns one mathematical task built on a model:

- decision and parameter schemas;
- mapping from a decision vector to a `SimulationRequest`;
- residual or objective and constraints;
- local chart operations and numerical metric;
- admissibility/feasibility validation;
- named continuation observables;
- construction of `Solution` objects.

Examples:

- quadruped periodic apex orbit;
- Jerboa periodic apex orbit;
- Jerboa trajectory fit;
- quadruped-load single-stride periodic problem;
- quadruped-load multi-stride fit.

### 4.3 Algorithms

Algorithms depend only on problem contracts and collaborators:

- root solving;
- multistart search;
- seed projection;
- second-seed construction;
- optimization;
- continuation;
- parameter homotopy;
- branch-family scanning.

### 4.4 Services

Services orchestrate algorithms, persistence, model/problem selection, simulation, visualization, and jobs. They are the only numerical entry points used by the GUI.

### 4.5 Data

Use typed value objects or disciplined structs for solutions, branches, simulations, events, diagnostics, provenance, and run records. Do not expose anonymous packed matrices as the public API.

### 4.6 Presentation

Presentation includes branch plots, plot plugins, scene rendering, animation, recording, app state, controllers, and GUI views. Presentation does not implement numerical algorithms.

## 5. Core contracts

Implement abstract contracts close to the following. Adjust exact MATLAB syntax for the supported release, but preserve responsibility boundaries.

### 5.1 `lmz.api.LeggedModel`

```text
getManifest
getCapabilities
getPhysicalStateSchema
getParameterSchema
listProblems
createProblem
simulate(SimulationRequest, RunContext)
kinematics(SimulationFrame)
getPlotDescriptors
```

### 5.2 `lmz.api.BaseProblem`

```text
getDescriptor
getDecisionSchema
getParameterSchema
validateDecision
canonicalize              % persistence/display representation
difference                % local chart difference
retract                   % local chart update
scale                     % positive numerical scales
decodeDecision
toSimulationRequest
validateSolution
listObservables
evaluateObservables
makeSolution
```

### 5.3 `lmz.api.NonlinearEquationProblem`

```text
residual
evaluate                  % residual plus optional cached simulation/diagnostics
unknownDimension
residualDimension
expectedLocalDimension
optionalJacobian
```

### 5.4 `lmz.api.OptimizationProblem`

```text
objective
objectiveTerms
nonlinearConstraints
bounds
optionalLinearConstraints
```

### 5.5 Variable schemas and charts

Implement `VariableSpec`, `VariableSchema`, `VariableChart`, `ProductChart`, and `DiagonalMetric`.

Each variable supports:

- stable name;
- human and LaTeX labels;
- group;
- unit and nondimensionalization note;
- default value;
- lower and upper bounds;
- positive numerical scale;
- topology: Euclidean, positive, bounded, angle, or cyclic time;
- optional named period source for cyclic time.

Provide name lookup, group selection, pack/unpack, validation, table generation, schema versioning, canonicalization, local difference, and retraction. Reject duplicate names, invalid bounds, nonpositive scales, and unresolved/nonpositive period references.

### 5.6 Run and data objects

Implement at least:

```text
RunContext
CancellationToken
PauseToken
ProgressSink
LogSink
CheckpointSink
SimulationRequest
SimulationResult
EventRecord
ResidualEvaluation
Solution
SolutionPair
SolutionBranch
SolveResult
ContinuationSnapshot
ContinuationResult
OptimizationResult
RunRecord
Dataset
ValidationReport
GaitClassification
ArtifactStore
LegacyAdapter
```

`SimulationResult` exposes named time, states, modes/contact states, events, forces, observables, parameters, diagnostics, and provenance. Numeric matrices may be used internally, but public access is schema-based.

## 6. Generic numerical solution search

Implement:

```text
lmz.solvers.RootSolver
lmz.solvers.FsolveSolver
lmz.solvers.MultiStartSolver
lmz.solvers.SeedProjector
lmz.solvers.SecondSeedSolver
lmz.optimization.Optimizer
lmz.optimization.FminconSolver
lmz.optimization.FminsearchSolver
ObjectiveTerm
CompositeObjective
ConstraintTerm
```

`FsolveSolver` consumes only `NonlinearEquationProblem`. It must not call a model-specific zero function directly.

A solve result records:

- decision vector and decoded values;
- residual vector and norm;
- exit flag and solver output;
- model/problem/schema versions;
- options;
- source seed;
- random seed/stream identity;
- timestamps;
- MATLAB version;
- source/code versions and provenance.

`SeedProjector` performs any event-time or physical seed repair explicitly. `SecondSeedSolver` augments the base residual with a problem-defined chart/metric distance equation. Multistart behavior must be reproducible.

Decompose fitting objectives into named terms. At minimum support trajectory position/height, leg angles, stride duration, footfall timing, and loading/tugline force. Each term owns its weight, normalization, resampling policy, diagnostics, and contribution.

## 7. Generic one-dimensional continuation

### 7.1 Mathematical condition

Do **not** require the residual to have exactly `n-1` rows. Let

\[
F:\mathcal{M}\subseteq\mathbb{R}^n\rightarrow\mathbb{R}^m.
\]

Under the standard constant-rank regularity assumptions, a one-dimensional local solution set requires Jacobian nullity one:

\[
n-\operatorname{rank} J_F(u)=1.
\]

A problem must declare `expectedLocalDimension = 1`. When a Jacobian is available, verify the numerical rank within a documented tolerance. When it is unavailable, treat the declaration as an assumption and perform secant/solver consistency checks; do not claim a proof of manifold dimension. This supports square but rank-deficient legacy residuals as well as rectangular formulations.

### 7.2 Product-chart predictor and corrector

For accepted points `u_(k-1)` and `u_k`, let

```text
delta = chart.difference(u_k, u_(k-1))
s     = problem.scale(u_k, u_(k-1))
W     = diag(1./s)
tau   = delta / norm(W*delta)
uPred = chart.retract(u_k, h*tau)
```

For a cyclic variable with period `T > 0`, use the centered difference

\[
d_T(a,b)=\operatorname{mod}(a-b+T/2,T)-T/2.
\]

Reject nonfinite or nonpositive periods.

Correct with the augmented residual

\[
G(u)=
\begin{bmatrix}
F(u)\\
(W\tau)^\mathsf{T}W\,\operatorname{difference}(u,u_{\mathrm{pred}})
\end{bmatrix}=0.
\]

The corrector must support rectangular residuals. Canonical wrapping is for persistence and display; local branch geometry uses lifted chart coordinates.

Use the same chart and metric consistently for prediction, correction, curvature, step length, duplicate detection, stagnation, and closure detection.

### 7.3 Continuation components

Implement:

```text
ContinuationEngine
SecantPredictor
PseudoArclengthCorrector
ContinuationOptions
ContinuationAcceptancePolicy
IterationStepController
CurvatureStepController
BacktrackingController
BranchClosureDetector
ContinuationTerminationPolicy
ContinuationSnapshot
```

Preserve useful behavior from `NumericalContinuation1D_Quadruped_v2`:

- both-direction search;
- timing lifting;
- variable scaling;
- step reduction after correction failure;
- iteration- and curvature-based adaptation;
- duplicate rejection;
- stagnation and loop closure detection;
- preview/progress events;
- cooperative pause/stop;
- atomic checkpointing and resume;
- structured logs and termination reasons.

Move plotting, prompts, gait policies, concrete filenames, MAT layouts, speed limits, parameter maps, and model-specific tolerances out of the engine.

Separate:

```text
ContinuationEngine    % traces one branch
ParameterHomotopy     % transports one seed or seed pair
BranchCatalog         % indexes native artifact metadata
BranchFamilyScan      % repeats branches at target parameter values
```

Before changing suspicious legacy behavior, add regression tests for weighted corrector scaling, curvature-history updates, duplicate accepted points, the Jerboa retry condition, nonpositive periods, speed-dependent tolerances, and hard-coded state/contact terminations.

## 8. Hybrid simulation

Provide extension contracts for:

```text
HybridSystem
HybridMode
HybridEvent
EventPolicy
ScheduledEventPolicy
GuardEventPolicy
HybridSimulator
```

`ScheduledEventPolicy` must canonicalize and sort event schedules, determine modes on intervals, integrate flows, apply named resets, retain pre/post-event states, and compute named forces and outputs. `GuardEventPolicy` is an extension point for future state-triggered events.

For initial migration, adapters may delegate complete evaluation to legacy zero functions. Extract native flows/resets/outputs only after golden regression tests pass. Keep legacy and native evaluators selectable during differential testing.

## 9. Registry, manifests, and scene configuration

Use this consistent project layout:

```text
Legged_Model_Zoo/
  README.md
  startup.m
  MIGRATION_STATUS.md
  src/+lmz/
    +api
    +schema
    +registry
    +simulation
    +problems
    +solvers
    +continuation
    +optimization
    +services
    +data
    +io
    +viz
    +gui
    +util
  models/+lmzmodels/
    +slipquadruped
    +jerboabiped
    +quadload
  catalog/
    slip_quadruped/
    jerboa_biped/
    quadruped_load/
  vendor/dlar/
  apps/
  examples/
  tests/unit/
  tests/integration/
  tests/regression/
  tests/architecture/
  tests/fixtures/
  tools/model_template/
  docs/adr/
```

Each `catalog/<model>/` contains:

```text
manifest.json
model.json
problems/<problem>.json
scene.lmz.json
optional defaults and example metadata
```

Implement `lmz.registry.ModelRegistry` to discover `catalog/*/manifest.json`, validate schema versions, detect duplicate IDs, diagnose missing implementation classes, list models/problems, and instantiate them. The GUI must not contain a hard-coded model list.

Create these models and problem descriptors:

- `slip.quadruped.planar.v2`: periodic apex;
- `jerboa.biped.offset`: periodic apex and trajectory fit;
- `slip.quadruped.load`: single-stride periodic and multi-stride fit.

Configuration may bind stable implementation IDs/classes but may not contain executable equations.

Implement a safe `scene.lmz.json` format supporting named frames and these primitives:

- polygon/rigid link;
- point mass/marker;
- line segment;
- spring;
- rope;
- ground;
- force vector;
- trail;
- text.

The model returns named transforms, points, and observables. The scene binds primitives to those names. Never evaluate expressions from a scene file. URDF may be supported through an optional adapter, but it is not the only or required visualization format.

## 10. Persistence

Save native MAT files as one top-level plain struct named `artifact`, never as the primary serialization of live class instances.

Include at least:

```text
schemaVersion
artifactType
modelId
modelVersion
problemId
problemVersion
problemConfiguration
decisionSchema
parameterSchema
decisionValues
parameterValues
observables
residualsOrObjectiveTerms
diagnostics
exitFlags
classificationAndTopology
algorithmOptions
lineage
sourceSeed
sourceDataset
randomSeed
sourceCommitSHAs
createdAt
matlabVersion
codeVersion
```

Use atomic temporary save, validation, and rename. Support checkpoints and resume. Runtime objects provide `toStruct`/`fromStruct` where useful. Write legacy variables such as `results` or `X_accum` only through explicit legacy exporters.

Implement importers/exporters for:

- quadruped 29-row `results`: 13 initial states, 9 event times, 7 parameters;
- Jerboa 14-row branches: 12 decision entries plus two offsets;
- quadruped-load `X_accum` and associated experimental/weight/sensitivity fields.

## 11. Mandatory source inventory and baselines

Inspect at least the following and recursively trace their called helpers, generated functions, MAT/FIG fixtures, globals, path mutations, solver calls, and toolbox dependencies.

### SLIP quadruped

```text
SLIP_Model_Zoo/SLIP_Quadruped/README.md
SLIP_Model_Zoo/SLIP_Quadruped/SLIP_Quadruped_GUI.m
Quadrupedal_ZeroFun_v2.m
SolveQuadrupedalZE.m
NumericalContinuation1D_Quadruped_v2.m
NumericalContinuation2D_Quadruped_v2.m
EventTimingRegulation.m
Gait_Identification.m
graphics, oscillator, branch, recording, and roadmap files
```

### Jerboa

```text
Main.m
Section3_optimization/Optimization.m
Stored_Functions/ZeroFunc_BipedApex_offset.m
Stored_Functions/ZeroFunc_BipedApex_offset_optimization.m
Stored_Functions/NumericalContinuation1D.m
Stored_Functions/ContinuationEqn.m
Stored_Functions/Gaitidentify.m
Stored_Functions/ShowTrajectory_BipedalDemo.m
all objective, constraint, resampling, and graphics dependencies
```

### Load-pulling quadruped

```text
Section2_Single_Stride_Replication.m
Section3_Gait_Transition_Replication.m
Stored_Functions/Dynamics/Quad_Load_ZeroFun_Transition_v2.m
Stored_Functions/SimulateQuadLoadStrides.m
Stored_Functions/fms_NStridesObjectiveFcn_Quad_Load_v2.m
Stored_Functions/EventTimingRegulation.m
all called files under Stored_Functions/Graphics
```

Before numerical refactoring, create:

```text
docs/legacy-inventory.md
docs/legacy-data-contracts.md
docs/legacy-algorithms.md
docs/baseline-fixtures.md
docs/provenance.md
docs/KNOWN_DIFFERENCES.md
docs/TEST_STATUS.md
```

Baseline scripts must capture representative residuals, events, trajectories, forces, classifications, objective terms, and source/fixture hashes. Do not invent a project license when source licensing is unclear; preserve headers and document the issue.

## 12. Migration phases and gates

### Phase 0 — Inventory and baselines

Deliver the inventory documents, selected fixtures, source SHAs, and executable baseline scripts. Run them when MATLAB is available.

**Gate:** data layouts and at least one regression point per model are documented; unresolved dependencies are explicitly listed.

### Phase 1 — Core scaffold

Implement schemas/charts, registry, manifests, data objects, `RunContext`, artifact storage, logging, cancellation/pause, and an analytic nonlinear test problem.

**Gate:** manifest/schema/artifact/analytic-solver tests pass, or exact unexecuted status is recorded.

### Phase 2 — SLIP quadruped vertical slice

Implement:

```text
lmzmodels.slipquadruped.Model
PeriodicApexProblem
Results29Adapter
LegacyEvaluator
GaitClassifier
Kinematics
VisualizationProvider
model-specific feasibility/topology policies
manifest, schemas, and scene
```

Initially wrap `Quadrupedal_ZeroFun_v2` in its no-inner-solve mode. Confine all raw layout mappings to `Results29Adapter` and `LegacyEvaluator`. Return native `ResidualEvaluation` and `SimulationResult` objects.

Create command-line examples to import a roadmap branch, select a point, evaluate residuals, simulate, classify, render on supplied axes, save a native artifact, and reload it.

**Gate:** the new adapter matches the legacy residual/event/trajectory/GRF/classification fixture within documented tolerances, and the project runs without adding source repositories to the path.

### Phase 3 — Generic solve and continuation

Implement `FsolveSolver`, explicit seed projection, deterministic multistart, second-seed construction, continuation, parameter homotopy, branch catalog, branch-family scan, checkpoint/resume, and logs.

Compare generic continuation with legacy continuation from the same seed pair. Exact point-for-point equality is not required when adaptive sampling changes; require validated periodic points on the same branch, chart continuity, comparable observables/direction, and documented termination differences.

**Gate:** analytic continuation tests pass and a short quadruped solve/branch runs through generic APIs with no quadruped-specific indices or policies in generic packages.

### Phase 4 — Minimal GUI vertical slice

Implement `lmz.gui.LeggedModelZooApp` plus a launcher in `apps/`. Separate:

```text
AppState
AppController
ServiceContainer
ModelBrowserView
DatasetView
BranchExplorerView
SolutionInspectorView
SimulationView
SolveView
ContinuationView
OptimizationView
StatusLogView
TaskRunner
```

Required behavior:

- dynamic model/problem selection from registry capabilities;
- legacy/native data loading;
- named 2-D/3-D branch axes;
- schema-generated solution editor;
- simulation and normalized-time scrubbing;
- animation and recording;
- solve/refine and reproducible seed noise;
- second seed, continuation, parameter homotopy, and branch scan;
- status, progress, diagnostics, pause, cancel, checkpoint, and resume;
- model-specific plot plugins only where genuinely needed.

Numerical work must live in services, not nested callbacks. Provide a synchronous `TaskRunner` path that always works; optional `parfeval` support must have a synchronous fallback.

**Gate:** app/controller construction and headless controller tests pass; GUI smoke tests run only when a display is available.

### Phase 5 — Jerboa migration

Implement:

```text
lmzmodels.jerboabiped.Model
PeriodicApexProblem
TrajectoryFitProblem
Results14Adapter
LegacyEvaluator
GaitClassifier
Kinematics
VisualizationProvider
```

Represent hard-coded stiffness/frequency and left/right swing offsets as explicit named parameters/defaults, while preserving adapter equivalence first. Use the same generic solver, continuation engine, optimization layer, persistence, and GUI services. Keep the old Jerboa continuation only as a regression baseline.

Migrate walk, run, hop, skip, and asymmetric-run fixtures when available.

### Phase 6 — Load-pulling quadruped migration

Implement:

```text
lmzmodels.quadload.Model
SingleStridePeriodicProblem
MultiStrideFitProblem
QuadLoadXAccumAdapter
MultiStrideDecisionSchema
MultiStrideSimulator
StrideDurationObjective
FootfallTimingObjective
LoadingForceObjective
Kinematics
VisualizationProvider
```

Centralize all first-stride and per-additional-stride packing in one schema/packer used by both simulation and objectives. Resolve discrepancies between comments, code, and stored lengths from fixtures and adapter tests; record the decision.

Return quadruped/load states, events, contacts, GRFs, leash force, and diagnostics. Port footfall, leg-trajectory, tugline-force, animation, and sensitivity views as model-specific plot plugins.

### Phase 7 — Native hybrid refactor

Only after adapter regression gates pass, extract duplicated scheduled-event integration, contact logic, resets, force calculations, and common utilities into the native hybrid layer. Keep legacy and native evaluators selectable and add differential tests. Remove copied legacy duplicates only after equivalence and provenance review.

## 13. Architecture checks

Add static or unit checks rejecting in generic packages:

- `global`;
- `restoredefaultpath`;
- `addpath(genpath`;
- direct calls to concrete legacy zero functions;
- direct GUI calls to MATLAB optimizers or continuation engines;
- unexplained model-specific positional indexing;
- executable configuration strings;
- GUI dependencies from schema, simulation, solver, continuation, optimization, data, or I/O packages.

Also verify:

- every artifact has schema/model/problem identity and ordered variable names;
- every randomized run stores its seed;
- every continuation run has checkpoints and termination reasons;
- every model has a command-line smoke test;
- source repositories remain unmodified.

## 14. Testing

Use `matlab.unittest` with unit, integration, regression, and architecture suites. Implement at least:

```text
TestManifestValidation
TestRegistryDiscovery
TestVariableSchemaPackUnpack
TestProductChart
TestNonpositivePeriodRejection
TestArtifactRoundTrip
TestLegacyQuadrupedAdapter
TestQuadrupedResidualEquivalence
TestQuadrupedSimulationEquivalence
TestFsolveSolver
TestSecondSeedSolver
TestAnalyticContinuation
TestContinuationCheckpointResume
TestBranchFamilyScanMetadata
TestJerboaResidualEquivalence
TestJerboaContinuationSmoke
TestQuadLoadResidualEquivalence
TestMultiStridePacking
TestObjectiveAggregation
TestSceneFrameValidation
TestArchitectureRules
TestAppController
TestAppSmoke
```

For trajectory regression, interpolate onto a common time grid and use measured, documented absolute/relative tolerances. Store baseline provenance.

When MATLAB is available, repeatedly run:

```bash
matlab -batch "cd('<TARGET>'); startup; results = runtests('tests','IncludeSubfolders',true); assert(~any([results.Failed]));"
```

Also run representative command-line examples. GUI rendering tests may skip cleanly in headless sessions.

When MATLAB is unavailable or unlicensed, run static, JSON, and filesystem checks; implement all MATLAB tests and runners; write `docs/TEST_STATUS.md`; and mark MATLAB tests as **not executed**, never passed.

## 15. Required examples and authoring template

Create:

```text
examples/demo_registry.m
examples/demo_slip_quadruped_import_simulate.m
examples/demo_slip_quadruped_solve.m
examples/demo_slip_quadruped_continuation.m
examples/demo_parameter_homotopy.m
examples/demo_branch_family_scan.m
examples/demo_jerboa_biped.m
examples/demo_jerboa_fit.m
examples/demo_quadload_single_stride.m
examples/demo_quadload_multi_stride_fit.m
apps/launch_legged_model_zoo.m
```

The primary API should resemble:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip.quadruped.planar.v2');
problem = model.createProblem('periodic_apex', struct());

adapter = lmzmodels.slipquadruped.Results29Adapter();
branch = adapter.loadBranch(legacyBranchFile);
seed = branch.point(1);

context = lmz.api.RunContext.synchronous();
solveResult = lmz.services.SolveService().solve(problem, seed, struct(), context);
seedPair = lmz.services.SeedService().makeSecondSeed( ...
    problem, solveResult.solution, 0.05, struct(), context);
continuationResult = lmz.services.ContinuationService().run( ...
    problem, seedPair, struct('InitialStep', 0.05), context);

lmz.io.ArtifactStore.save( ...
    'quadruped_branch.lmz.mat', continuationResult.branch.toArtifact());
```

Create `tools/model_template/` with manifest/problem/scene templates, model/problem class skeletons, tests, and a runnable example.

## 16. Documentation and status records

Write:

```text
README.md
docs/architecture.md
docs/model-author-guide.md
docs/configuration-reference.md
docs/continuation.md
docs/migration-map.md
docs/provenance.md
docs/KNOWN_DIFFERENCES.md
docs/TEST_STATUS.md
MIGRATION_STATUS.md
```

Create concise ADRs for model/problem separation, configuration bindings, artifact persistence, scene format, continuation extraction, and legacy-vs-native evaluation.

Update `MIGRATION_STATUS.md` after every phase with completed, partial, blocked, tested, and untested items.

## 17. Work protocol

- Inspect and baseline before editing numerical code.
- Make small coherent changes.
- Run available tests after each gate.
- Do not stop after abstract stubs or documentation.
- Do not claim equivalence without numerical regression output.
- Preserve legacy behavior in adapters before improving native behavior.
- Trace uncertain local dependencies instead of guessing.
- Document stale references; do not create fake placeholder functions.
- Avoid unnecessary third-party dependencies.
- Preserve source headers and provenance.
- Keep the source repositories unchanged.

## 18. Completion criteria and final report

The **minimum successful implementation pass** requires:

1. inventory/baseline records;
2. validated registry and schemas;
3. native data/artifact round trip;
4. complete quadruped import/evaluate/simulate/classify/visualize/solve/continue command-line workflow through generic services;
5. generic continuation with no quadruped-specific indices, names, plots, prompts, filenames, or acceptance policies;
6. minimal class-based GUI vertical slice;
7. architecture checks and available tests executed.

The **full project is complete** only when Jerboa and load-pulling fixtures also use the same generic APIs and their regression/objective tests pass.

At the end, report exactly:

- target project path;
- principal classes and files created;
- legacy files copied, wrapped, or refactored;
- source commit SHAs;
- every command/test actually run and its exact result;
- numerical differences and tolerances;
- unresolved blockers;
- completed and incomplete phases;
- the next concrete implementation step.

Begin now with repository discovery, source inventory, and baseline-fixture selection. Then implement the quadruped vertical slice. Do not ask the user for confirmation between phases.
