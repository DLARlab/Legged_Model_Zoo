# Codex Round 2 Completion Prompt — Legged Model Zoo

Act as the senior MATLAB numerical-software architect and implementation engineer responsible for completing the existing **Legged Model Zoo** repository.

This is an implementation task. Work directly in the existing local clone, modify code, run tests, and leave the repository in a release-candidate state. Do not stop after writing a plan, architecture notes, interfaces, or placeholder classes.

---

## 1. Repositories and source-of-truth rules

The workspace is expected to contain local clones of:

1. `Legged_Model_Zoo`
2. `SLIP_Model_Zoo`
3. `2022_A_Template_Model_Explains_Jerboa_Gait_Transitions`
4. `2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights`

Locate them from the common workspace root. Verify Git remotes and record current commit SHAs.

Use the existing `Legged_Model_Zoo` clone as the target. **Do not create a second project.**

Treat the three legacy repositories as immutable reference inputs:

- do not edit them;
- do not commit inside them;
- do not run formatting over them;
- do not use destructive Git commands;
- do not clone or download replacements;
- verify at the end that their working trees remain unchanged.

The target repository may contain user changes beyond the public GitHub state. Begin with:

```bash
git -C <Legged_Model_Zoo> status --short
git -C <Legged_Model_Zoo> rev-parse HEAD
git -C <Legged_Model_Zoo> log --oneline --decorate -10
```

Never discard uncommitted user work. Do not use `git reset --hard`, `git clean -fd`, force checkout, history rewriting, or force push. Do not push.

The public repository was last observed at commit:

```text
e3b2e95ab3397f510f6aec8a5d7154e0e92e3197
```

The local checkout is authoritative if it is newer.

You may inspect the prior commit

```text
984399acf1612bd3915f252124da2e86d9e006b0
```

for ideas or recoverable tests, but **do not restore it wholesale**. It contained broad, compressed scaffolding, a continuation dimension restriction that is not valid for all legacy problems, and several placeholder implementations. Reuse only code that is independently reviewed, reformatted, tested, and consistent with the architecture below.

---

## 2. Verified current state that this round must advance

Read these files before editing:

```text
MIGRATION_STATUS.md
README.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/architecture.md
docs/legacy-inventory.md
docs/legacy-data-contracts.md
docs/legacy-algorithms.md
docs/baseline-fixtures.md
docs/migration-map.md
docs/provenance.md
```

The observed repository state is:

- Phase 0 inventory: partial.
- Phase 1 core scaffold: partial.
- Phase 2 quadruped vertical slice: only a boundary adapter and stubs.
- Solve and continuation: not started in the current tree.
- GUI: not started.
- Jerboa and load-pulling models: inventory/stubs only.
- No MATLAB unit, integration, regression, example, or GUI test has been executed.
- Native numerical evaluation is not implemented.
- No numerical equivalence is claimed.

The currently retained implementation is intentionally small:

```text
src/+lmz/+api/
src/+lmz/+schema/
src/+lmz/+registry/ModelRegistry.m
src/+lmz/+data/Solution.m
src/+lmz/+io/ArtifactStore.m
models/+lmzmodels/.../Model.m
models/+lmzmodels/+slipquadruped/Results29Adapter.m
catalog/
a small unit/static test set
```

Before adding major functionality, verify and fix these likely defects:

1. `ModelRegistry.discover()` appears to ascend four directory levels from
   `src/+lmz/+registry`; this likely resolves to a catalog outside the project.
   Replace ad hoc path traversal with a tested `ProjectPaths` utility.

2. `lmzmodels.slipquadruped.Model` currently advertises `simulate`, `solve`,
   `continue`, and `visualize` as supported although `simulate` throws
   `lmz:LegacyUnavailable`. Capabilities must be truthful and derived from
   implemented problem/service support.

3. `VariableChart.retract` canonicalizes cyclic variables using periods
   resolved from the base point. When the period variable changes in the same
   step, canonicalization must use the candidate/new period. Add a regression
   test.

4. Manifest validation is shallow. It does not yet validate referenced problem
   descriptors, scene files, implementation classes, duplicate problem IDs,
   supported schema versions, or catalog completeness.

5. `ArtifactStore.validate` checks field presence only. Add structural,
   dimensional, schema, version, and finite-value validation.

6. `Results29Adapter` currently returns a raw struct. It must eventually
   produce and consume the native `SolutionBranch`/artifact contracts while
   retaining exact legacy round-trip export.

7. Existing MATLAB code is highly compressed. Refactor modified files into
   readable, reviewable MATLAB: one statement per logical line, explicit
   validation, stable error IDs, and documentation on public APIs.

Treat these as hypotheses to verify, not excuses to skip tests.

---

## 3. Completion objective

Deliver a framework in which all three models use the same public APIs for the operations they support.

The dependency direction is:

```text
GUI
  -> application services
  -> model-independent algorithms
  -> problem contracts
  -> model / simulator / model-specific adapters
```

Required completed workflows:

### SLIP quadruped

```text
legacy branch import
-> named solution selection
-> deterministic residual evaluation
-> simulation
-> gait classification
-> trajectory/force visualization
-> root solve/refinement
-> second-seed generation
-> bidirectional pseudo-arclength continuation
-> parameter homotopy
-> branch-family scan
-> native artifact save/load
-> legacy results export
-> GUI use
```

### Jerboa biped

```text
legacy branch import
-> residual/simulation
-> gait classification
-> root solve
-> generic continuation
-> trajectory-fit optimization
-> visualization/animation
-> native persistence
-> GUI use where capabilities apply
```

### Load-pulling quadruped

```text
legacy X_accum import
-> single- and multi-stride decoding
-> simulation with load/tugline outputs
-> decomposed fitting objectives
-> optimization
-> footfall/leg/tugline/sensitivity visualization
-> native persistence
-> GUI use where capabilities apply
```

Do not declare the project complete until the release gates in Section 16 are satisfied or accurately marked blocked by a missing external prerequisite.

---

## 4. Non-negotiable engineering rules

1. Target MATLAB R2019b or the oldest newer release proven necessary by the
   reference code.
2. Optimization Toolbox may be required. Parallel Computing Toolbox is
   optional and must have a synchronous fallback.
3. Do not use `global` in new framework code.
4. Do not use `restoredefaultpath`, `addpath(genpath(...))`, `eval`, `evalin`,
   or `assignin`.
5. `startup.m` may add only the target project's `src` and `models` roots.
6. Generic packages must not contain model-specific indices such as
   `X(14:22)`, `P(15)`, or `results(23:29,:)`.
7. Raw positional indexing is permitted only inside a named model-specific
   layout, codec, adapter, or evaluator and must be documented and tested.
8. GUI code must not call `fsolve`, `fmincon`, `fminsearch`, legacy zero
   functions, or continuation algorithms directly.
9. A native residual evaluation must be deterministic and must not silently
   launch another nonlinear solve.
10. Event-time projection/repair must be an explicit preprocessing service,
    not a hidden residual side effect.
11. Parameter transforms such as `abs`, clipping, or forced bounds must be
    explicit, versioned, validated, and recorded in diagnostics.
12. All random perturbations must accept and record a seed or `RandStream`.
13. All long algorithms must receive progress, logging, pause, cancellation,
    and checkpoint behavior through `RunContext`.
14. Persist plain structs, not live handle objects, as the public artifact
    contract.
15. JSON is declarative. Never execute code or expressions read from JSON.
16. Never claim numerical equivalence or a passing test unless it was actually
    executed.
17. Preserve source headers and record provenance for every migrated legacy
    function.
18. The completed target must run without adding the original repositories to
    the MATLAB path.

---

## 5. Execution protocol

Proceed through the gates below without asking for confirmation between gates.

At the beginning of each gate:

1. inspect the current implementation;
2. identify the smallest end-to-end increment;
3. add or update tests first when behavior is ambiguous;
4. implement;
5. run the applicable test subset;
6. update `MIGRATION_STATUS.md` and `docs/TEST_STATUS.md` with exact evidence.

Do not create dozens of empty abstract classes in parallel. A vertical slice
that executes is more valuable than broad scaffolding.

Use conservative, documented assumptions. When source comments, code, and
fixtures conflict, fixtures plus executed behavior are authoritative. Record
the decision in `docs/KNOWN_DIFFERENCES.md` or an ADR.

---

# GATE A — Repair and validate the retained scaffold

## A1. Toolchain detection

Search for MATLAB, including common installation locations if it is not on
`PATH`. Record:

```matlab
version
ver
license('test','Optimization_Toolbox')
license('test','Distrib_Computing_Toolbox')
usejava('desktop')
```

Do not treat Octave as proof of MATLAB compatibility. Octave may be used only
for limited supplementary checks, clearly labeled as such.

Create a root-level validation entry point:

```text
run_tests.m
```

It must:

- call `startup`;
- add only the test utilities needed for the test run;
- run all tests recursively;
- print a concise summary;
- return nonzero/fail in batch mode when any test fails.

Recommended batch command:

```bash
matlab -batch "cd('<TARGET>'); results=run_tests; assert(~any([results.Failed]));"
```

## A2. Project paths and startup

Implement:

```text
lmz.util.ProjectPaths
```

with tested methods for:

- project root;
- `src`;
- `models`;
- `catalog`;
- `tests`;
- `examples`;
- temporary/checkpoint roots.

Do not derive roots independently in multiple classes.

Fix registry discovery and add tests that run from:

- repository root;
- an unrelated current working directory;
- a path containing spaces.

## A3. Registry and catalog validation

Upgrade `ModelRegistry` and introduce explicit descriptor loaders/validators.

Validate:

- manifest schema version;
- unique model ID;
- semantic model version string;
- implementation class exists and is under `lmzmodels.*`;
- declared problem IDs are unique;
- every declared problem descriptor exists;
- every descriptor has a supported kind and implementation binding;
- referenced scene exists when visualization is advertised;
- model instantiation returns `lmz.api.LeggedModel`;
- capabilities match implemented problems/services.

Add complete catalog entries for all three models, even when a capability is
temporarily false.

## A4. Schema and chart correctness

Complete and test:

```text
VariableSpec
VariableSchema
VariableChart
DiagonalMetric
```

Required behavior:

- pack/unpack by stable names;
- group selection;
- defaults, bounds, scales, labels, units, notes;
- topology validation;
- Euclidean, positive, bounded, angle, and cyclic-time variables;
- candidate-period-aware retraction;
- centered cyclic difference;
- canonicalization idempotence;
- invalid/nonpositive period rejection;
- changing-period regression;
- table metadata generation;
- struct round trip and schema versioning.

Do not impose one global angle interval if a variable declares a different
valid canonical interval.

## A5. Core data contracts

Implement readable, validated, struct-convertible classes or value objects:

```text
lmz.api.BaseProblem
lmz.api.NonlinearEquationProblem
lmz.api.OptimizationProblem
lmz.api.SimulationRequest
lmz.api.SimulationResult
lmz.api.EventRecord
lmz.data.ProblemEvaluation
lmz.data.ResidualBlock
lmz.data.Solution
lmz.data.SolutionBranch
lmz.data.RunRecord
lmz.data.Dataset
lmz.api.RunContext
lmz.api.CancellationToken
lmz.api.PauseToken
```

`SimulationResult` must expose:

- time;
- named state schema and state matrix;
- named modes/contact states;
- event records with pre/post states;
- named observables;
- parameters;
- diagnostics;
- provenance.

## A6. Artifact persistence

Upgrade `ArtifactStore` to support:

- atomic temp-save, validation, and rename;
- solution, branch, simulation, optimization-run, and checkpoint artifacts;
- schema/model/problem identity;
- ordered decision and parameter names;
- units/topology/scales;
- finite numeric values;
- compatible matrix dimensions;
- residual/objective diagnostics;
- source lineage;
- random seed;
- source repository SHAs;
- MATLAB/code versions;
- load-time version dispatch;
- checkpoint/resume metadata.

Add corruption, missing-field, bad-dimension, wrong-version, and round-trip
tests.

### Gate A acceptance

- All retained core tests pass in MATLAB.
- Registry discovery works from an unrelated directory.
- All three models instantiate.
- Capabilities are truthful.
- No numerical model capability is claimed merely by a stub.

---

# GATE B — Complete inventory and capture executable baselines

The existing inventory is too brief. Finish transitive dependency analysis for
the selected entry points.

## B1. Dependency inventory

For each legacy model, document:

- entry points;
- called functions;
- generated symbolic functions;
- globals;
- path mutations;
- toolboxes;
- packed-vector layouts;
- event ordering/reset behavior;
- residual blocks;
- solver options;
- output layouts;
- duplicate utilities;
- stale/missing references;
- licenses and copied-file provenance.

Update:

```text
docs/legacy-inventory.md
docs/legacy-data-contracts.md
docs/legacy-algorithms.md
docs/baseline-fixtures.md
docs/provenance.md
docs/migration-map.md
```

## B2. Fixture materialization

Use the already identified fixtures:

```text
SLIP quadruped:
  PK_20_2.mat

Jerboa:
  Section2_solution_examples/W1.mat

Load pulling:
  Section2_Single_Stride_Replication/P3_Individual_1_TR.mat
```

Create small, standalone regression fixtures under:

```text
tests/fixtures/
```

Prefer minimal extracted columns/fields rather than copying large unrelated
datasets. Add scripts that regenerate each extracted fixture from the immutable
source repositories. Store source file hashes and source commit SHAs.

## B3. Legacy baseline capture

Create isolated scripts that temporarily add only the required legacy paths,
execute the reference functions, save plain baseline structs, and restore the
path with `onCleanup`.

Capture at minimum:

### Quadruped

For several representative columns, including an adjacent seed pair:

- 22-entry decision;
- 7-entry parameters;
- residual vector;
- residual norm;
- `T`, `Y`, `P`;
- GRFs;
- event states;
- gait name/abbreviation;
- event-time canonicalization;
- solver result for one seed when feasible.

Use the deterministic `skipSolve` path for residual regression. Capture the
explicit event-time repair path separately.

### Jerboa

For representative walk and, when available, run/hop/skip/asymmetric fixtures:

- 12-entry decision;
- two offsets;
- residual;
- `T`, `Y`, `P`;
- event states;
- energy/output values;
- gait classification;
- one root-solve result when feasible.

Record any structurally zero or redundant residual component rather than
silently deleting it.

### Load pulling

Capture:

- decoded first-stride layout;
- decoded later-stride layout;
- single- and multi-stride simulation;
- quadruped/load states;
- events;
- GRFs;
- leash force;
- `P`;
- stride-duration term;
- footfall-timing term;
- loading-force term;
- total objective and R-squared diagnostics.

### Gate B acceptance

- Baseline scripts execute in MATLAB.
- Baseline artifacts are committed to `tests/fixtures` or generated
  reproducibly during the test setup.
- Every baseline contains provenance and measured tolerances.
- No source repository is modified.

If MATLAB is genuinely unavailable, implement all capture scripts and mark
Gate B blocked. Do not claim completion of numerical gates.

---

# GATE C — Finish the SLIP quadruped vertical slice

Complete this gate before broad GUI work or migration of the other models.

## C1. Model-specific schemas and layouts

Implement named, tested schemas for:

### Periodic decision, 22 entries

Initial state:

```text
dx
y
dy
phi
dphi
alphaBL
dalphaBL
alphaFL
dalphaFL
alphaBR
dalphaBR
alphaFR
dalphaFR
```

Event timing:

```text
tBL_TD
tBL_LO
tFL_TD
tFL_LO
tBR_TD
tBR_LO
tFR_TD
tFR_LO
tAPEX
```

### Parameters, 7 entries

```text
k_leg
k_swing
J_pitch
l_leg
phi_neutral
l_b
k_r_leg
```

### Integrated physical state, 14 entries

Include translational position `x` and the corresponding velocity/state
ordering used by the legacy simulator. Do not conflate physical state with the
periodic decision vector.

Implement explicit layout/codec classes. Raw indices must stay inside them.

## C2. Vendored legacy evaluator

Audit the exact transitive dependencies of:

```text
Quadrupedal_ZeroFun_v2.m
```

Copy only the minimum required implementation into an isolated package such as:

```text
models/+lmzmodels/+slipquadruped/+legacy/
```

Rename or package functions to prevent collisions. Preserve source headers and
record file-level provenance. The target must run without the reference
repository on the path.

Do not change equations during the first equivalence pass.

Implement an evaluator boundary returning a structured result, not positional
multiple outputs.

## C3. Periodic problem and explicit projection

Implement:

```text
lmzmodels.slipquadruped.PeriodicApexProblem
lmzmodels.slipquadruped.EventScheduleProjector
lmzmodels.slipquadruped.GaitClassifier
lmzmodels.slipquadruped.Kinematics
lmzmodels.slipquadruped.Model
```

`PeriodicApexProblem.evaluate` must:

- validate decision and parameters;
- canonicalize through the chart;
- invoke deterministic legacy evaluation with hidden repair disabled;
- return named/scaled residual blocks;
- return simulation and diagnostics when requested;
- report physical validity separately from solver convergence.

`EventScheduleProjector` may perform the legacy event-time repair, but only as
an explicit operation invoked by a seed-preparation service.

The model must own physical simulation. The problem converts a decision into a
`SimulationRequest`.

## C4. Native branch adapter

Upgrade `Results29Adapter` so that it:

- imports a 29-by-N matrix into a `SolutionBranch`;
- assigns named decisions and parameters;
- preserves original column order;
- validates finite values and consistent dimensions;
- stores source file/hash/provenance;
- exports exactly to the legacy 29-row representation;
- converts to/from the native artifact contract.

## C5. Equivalence tests

Add tests comparing the new adapter/evaluator to Gate B baselines:

- residual values;
- event times;
- event states;
- time vector;
- interpolated state trajectories;
- GRFs;
- gait classification;
- branch import/export.

Do not choose tolerances arbitrarily. Measure them, document absolute and
relative tolerances, and explain any difference.

### Gate C acceptance

This command-line workflow executes without reference repos on the path:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip.quadruped.planar.v2');
problem = model.createProblem('periodic_apex', struct());

adapter = lmzmodels.slipquadruped.Results29Adapter();
branch = adapter.loadBranch('<fixture>');
solution = branch.point(1);

simulation = lmz.services.SimulationService().simulate( ...
    problem, solution, struct(), lmz.api.RunContext.synchronous(0));
```

All quadruped baseline-equivalence tests pass.

---

# GATE D — Generic solving, seed generation, continuation, and scans

## D1. Nonlinear solver services

Implement:

```text
lmz.solvers.FsolveSolver
lmz.solvers.MultiStartSolver
lmz.services.SolveService
lmz.services.SeedService
```

Requirements:

- consume only `NonlinearEquationProblem`;
- support square and overdetermined residuals;
- preserve residual-block scaling;
- validate options/toolbox availability;
- expose solver iteration callbacks through `RunContext`;
- record complete diagnostics and provenance;
- never hard-code a model variable index;
- never silently replace `fsolve` with another algorithm;
- provide reproducible multistart perturbations.

## D2. Correct continuation geometry

For a problem

\[
F:\mathbb{R}^{n}\rightarrow\mathbb{R}^{m},
\]

do **not** require \(m=n-1\).

A regular one-dimensional local solution set requires

\[
n-\operatorname{rank} J_F(u)=1.
\]

Legacy formulations may be overdetermined but rank-deficient because residual
directions are dependent. Do not delete residual components merely to make a
square system.

The problem contract must declare its expected local manifold dimension.
When a Jacobian is available or can be estimated robustly, report the
numerical rank/nullity and conditioning. A mismatch is a diagnostic or
problem-policy decision, not a generic hard-coded residual-count check.

Use the product chart and diagonal metric:

\[
\delta_k = \operatorname{difference}(u_k,u_{k-1}),
\qquad
\tau_k = \frac{\delta_k}{\|W\delta_k\|_2},
\]

\[
u_{\mathrm{pred}}
=
\operatorname{retract}(u_k,h_k\tau_k).
\]

The corrector residual is

\[
G(u)=
\begin{bmatrix}
S_F F(u)\\
(W\tau_k)^\mathsf{T}
W\,\operatorname{difference}(u,u_{\mathrm{pred}})
\end{bmatrix},
\]

where \(S_F\) is the residual-block scaling supplied by the problem.

Canonical wrapping is for persistence and display. Local branch geometry uses
chart differences and lifted representatives.

## D3. Continuation components

Implement readable classes/functions for:

```text
ContinuationOptions
ContinuationSnapshot
ContinuationResult
SecantPredictor
PseudoArclengthCorrector
StepSizeController
CurvatureController
BacktrackingController
DuplicateDetector
StagnationDetector
LoopClosureDetector
ContinuationAcceptancePolicy
PseudoArclengthContinuation
ContinuationService
CheckpointStore
```

Preserve and generalize the useful behavior of the quadruped continuation:

- search both directions;
- cyclic timing lifting;
- schema scaling;
- predictor/corrector;
- adaptive numerical step;
- curvature restriction;
- correction backtracking;
- duplicate rejection;
- historical segment loop closure;
- cooperative pause/cancel;
- atomic checkpoints;
- resume;
- accepted/rejected progress events;
- logs and explicit termination reasons.

Move all of these out of the engine:

- plots;
- prompts;
- file naming;
- gait names;
- speed thresholds;
- quadruped indices;
- model-specific residual tolerances;
- topology heuristics.

## D4. Analytic continuation tests

Add at least:

1. A fold problem

\[
F(x,\lambda)=x^2-\lambda=0
\]

that passes through \((0,0)\).

2. A closed analytic curve for loop-closure detection.

3. A problem with a cyclic variable.

4. An overdetermined rank-deficient problem demonstrating that residual count
   need not equal \(n-1\).

Test:

- tangent orientation;
- predictor;
- metric-consistent corrector;
- step adaptation;
- fold traversal;
- cancellation;
- checkpoint/resume;
- loop closure;
- duplicate rejection;
- changing-period chart behavior.

## D5. Second seed, homotopy, and family scan

Implement:

```text
SecondSeedSolver
ParameterHomotopy
BranchCatalog
BranchFamilyScan
```

Second-seed generation must solve the periodic equations plus a
metric/chart-aware distance condition, use reproducible fallback directions,
and report residual and achieved radius.

`ParameterHomotopy` transports one solution or a seed pair across a named
parameter using adaptive steps and problem validation.

`BranchFamilyScan`:

- repeats one-dimensional branches at requested parameter values;
- uses artifact metadata rather than filenames;
- supports source lineage;
- resumes existing compatible output;
- reports completed, skipped, failed, and blocked targets.

Do not call this true two-dimensional continuation. Reserve
`SurfaceContinuation` for a future surface-tracing method.

## D6. Quadruped numerical tests

Run:

- seed refinement from a roadmap point;
- second-seed generation;
- a short branch in each direction;
- checkpoint/resume;
- parameter homotopy;
- a small branch-family scan.

Every accepted point must satisfy the configured residual and feasibility
policies. Compare with legacy behavior without requiring identical adaptive
sample positions.

### Gate D acceptance

The quadruped can be solved and continued exclusively through generic services.
No file under `src/+lmz/+continuation`, `+solvers`, or `+services` contains a
quadruped variable name or raw quadruped index.

---

# GATE E — Visualization, animation, and a usable GUI

## E1. Scene and kinematics

Replace the placeholder quadruped scene with a complete named-frame scene:

```text
world
body
hip_back
hip_front
foot_bl
foot_fl
foot_br
foot_fr
```

Support primitives needed by the current projects:

```text
polygon/rigid link
point/marker
line segment
spring
rope
ground
force vector
trail
text
```

Implement:

```text
lmz.viz.SceneSpec
lmz.viz.SceneValidator
lmz.viz.SceneRenderer2D
lmz.viz.AnimationController
lmz.viz.Recorder
lmz.viz.BranchPlot
lmz.viz.TrajectoryPlot
lmz.viz.ObservablePlot
```

The model supplies named kinematics. The renderer never indexes raw model
vectors. The animation controller owns interpolation, playback, pause/stop,
frame rate, and recording.

## E2. Application services

Implement service boundaries for:

```text
RegistryService
DataService
SimulationService
SolveService
SeedService
ContinuationService
OptimizationService
VisualizationService
ArtifactService
```

All must have a synchronous path. Optional background execution may use
`parfeval` only when available.

## E3. Programmatic GUI

Implement:

```text
apps/LeggedModelZooApp.m
lmz.gui.AppState
lmz.gui.AppController
reviewable view/component classes
```

Minimum functional areas:

- model/problem selector;
- data folder and artifact browser;
- legacy import;
- 2-D/3-D branch explorer using named variables/observables;
- hover and selected-point inspection;
- schema-generated decision and parameter tables;
- simulation and normalized-time scrubber;
- trajectory/GRF/observable views;
- animation run/stop and export;
- solve/refine controls;
- reproducible seed noise;
- second-seed controls;
- continuation run/pause/stop/resume;
- parameter homotopy;
- branch-family scan;
- status/log/diagnostic panel.

Use capabilities to hide unsupported actions. The GUI must not contain
numerical algorithms or model-specific indexing.

### Gate E acceptance

- A headless controller test exercises model selection, import, selection,
  simulation, solve request, continuation request, and artifact save.
- A GUI construction/smoke test runs when a display is available.
- The quadruped vertical slice is usable through both command line and GUI.

---

# GATE F — Migrate the Jerboa biped through the same APIs

Implement:

```text
lmzmodels.jerboabiped.Model
lmzmodels.jerboabiped.PeriodicApexProblem
lmzmodels.jerboabiped.Results14Adapter
lmzmodels.jerboabiped.GaitClassifier
lmzmodels.jerboabiped.Kinematics
lmzmodels.jerboabiped.TrajectoryFitProblem
model catalog/problem/scene descriptors
```

Requirements:

- preserve the legacy 12-entry decision plus two offsets;
- keep fixed legacy constants fixed in the compatibility problem unless a
  separate versioned parameterized problem is introduced;
- vendor the minimum transitive evaluator dependencies with provenance;
- preserve redundant/zero residual behavior for compatibility and document it;
- support overdetermined residual solving;
- run the same generic solve and continuation services;
- migrate walk, run, hop, skip, and asymmetric fixtures where available;
- decompose trajectory fitting into named objective terms and constraints;
- supply visualization/animation;
- persist native artifacts and support legacy export.

### Gate F acceptance

A Jerboa fixture can be imported, simulated, classified, solved, continued for
a short branch, visualized, and saved/reloaded using the same public service
interfaces as the quadruped.

---

# GATE G — Migrate the load-pulling quadruped

Implement:

```text
lmzmodels.quadload.Model
lmzmodels.quadload.SingleStrideProblem
lmzmodels.quadload.MultiStrideFitProblem
lmzmodels.quadload.MultiStrideDecisionSchema
lmzmodels.quadload.MultiStrideSimulator
lmzmodels.quadload.QuadLoadXAccumAdapter
lmzmodels.quadload.Kinematics
catalog/problem/scene descriptors
```

Resolve the packed layout from fixtures and executed source behavior. Centralize
the first-stride and later-stride logic; do not duplicate it in the simulator
and objective.

Represent and test the observed layout:

\[
44 + 13(N-1)
\]

when confirmed by the fixtures.

Decompose optimization into independently testable terms:

```text
StrideDurationMismatch
FootfallTimingMismatch
LoadingForceMismatch
CompositeObjective
R2Metrics
```

Each term owns:

- weight;
- normalization;
- resampling policy;
- diagnostics;
- contribution.

Simulation must expose:

- quadruped states;
- load states;
- contact modes;
- event records;
- GRFs;
- leash/tugline force;
- parameters;
- stride boundaries;
- diagnostics.

Add footfall, leg-trajectory, tugline-force, and sensitivity plot plugins when
the loaded dataset contains the required data.

### Gate G acceptance

- Single-stride baseline equivalence passes.
- Multi-stride packing round trips.
- Objective terms match legacy baseline values within measured tolerances.
- A short optimization smoke test reduces the objective from its initial value.
- Native artifacts round-trip.
- The GUI exposes simulation and optimization for this model through
  capabilities.

---

# GATE H — Native hybrid abstraction and release hardening

Only after adapter equivalence is established, extract reusable hybrid
simulation concepts:

```text
HybridSystem
HybridMode
HybridEvent
ScheduledEventPolicy
GuardEventPolicy
ResetMap
HybridSimulator
```

At minimum, `ScheduledEventPolicy` must:

- validate/canonicalize schedules;
- sort events with stable tie handling;
- determine modes over each interval;
- integrate mode flow;
- apply named reset maps;
- record pre/post-event states;
- concatenate trajectories without corrupting duplicate event samples;
- compute named forces/outputs;
- expose diagnostics.

Migrate at least one complete model to this native path while keeping the
legacy adapter as a regression oracle. Do not rewrite all equations
simultaneously.

Add:

- code-quality checks;
- namespace collision checks;
- `which -all` checks for critical functions;
- manifest/scene validation;
- architecture checks over both `src` and `models`, with a documented allowlist
  for model adapters;
- documentation and examples;
- release validation script.

---

## 6. Public API target

The principal user workflow should be close to:

```matlab
startup;

registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip.quadruped.planar.v2');
problem = model.createProblem('periodic_apex', struct());

adapter = lmzmodels.slipquadruped.Results29Adapter();
branch = adapter.loadBranch(fixturePath);
seed = branch.point(1);

context = lmz.api.RunContext.synchronous(42);

simulation = lmz.services.SimulationService().simulate( ...
    problem, seed, struct(), context);

solveResult = lmz.services.SolveService().solve( ...
    problem, seed, struct(), context);

seedPair = lmz.services.SeedService().makeSecondSeed( ...
    problem, solveResult.Solution, 0.05, struct(), context);

continuationResult = lmz.services.ContinuationService().run( ...
    problem, seedPair, struct('InitialStep',0.05), context);

lmz.io.ArtifactStore.save( ...
    'quadruped_branch.lmz.mat', ...
    continuationResult.Branch.toArtifact());
```

Keep capitalization and MATLAB naming internally consistent. Do not preserve a
bad API merely because a placeholder used it.

---

## 7. Required examples

Create and execute when possible:

```text
examples/demo_registry.m
examples/demo_slip_quadruped_import_simulate.m
examples/demo_slip_quadruped_solve.m
examples/demo_slip_quadruped_continuation.m
examples/demo_parameter_homotopy.m
examples/demo_branch_family_scan.m
examples/demo_jerboa_biped.m
examples/demo_jerboa_fit.m
examples/demo_quadruped_load_single_stride.m
examples/demo_quadruped_load_multi_stride_fit.m
examples/launch_gui.m
```

Examples must use only public APIs and must not add legacy repositories to the
path.

---

## 8. Required test coverage

Use `matlab.unittest`.

At minimum, retain or create:

```text
TestProjectPaths
TestModelDescriptorValidation
TestRegistryDiscovery
TestRegistryDuplicateIds
TestVariableSpecValidation
TestVariableSchemaPackUnpack
TestVariableChart
TestChangingPeriodRetraction
TestNonpositivePeriodRejection
TestDiagonalMetric
TestArtifactRoundTrip
TestArtifactValidation
TestRunContext
TestCancellationAndPause
TestLegacyQuadrupedAdapter
TestSlipQuadrupedResidualEquivalence
TestSlipQuadrupedSimulationEquivalence
TestSlipQuadrupedGaitClassification
TestFsolveSolver
TestMultiStartReproducibility
TestSecondSeedSolver
TestAnalyticFoldContinuation
TestOverdeterminedContinuation
TestContinuationCancellation
TestContinuationCheckpointResume
TestContinuationLoopClosure
TestParameterHomotopy
TestBranchFamilyScan
TestSceneValidation
TestSceneRendererKinematicsBoundary
TestHeadlessAppController
TestAppConstruction
TestJerboaAdapter
TestJerboaResidualEquivalence
TestJerboaSimulationEquivalence
TestJerboaSolveAndContinuation
TestJerboaObjectiveTerms
TestQuadLoadXAccumAdapter
TestMultiStridePacking
TestQuadLoadSimulationEquivalence
TestLoadObjectiveComponents
TestArchitectureRules
```

Regression trajectory tests must interpolate to a common time grid and compare
with documented absolute and relative tolerances. Event/reset samples must be
tested separately rather than obscured by interpolation.

---

## 9. Documentation and status deliverables

Complete:

```text
README.md
LICENSE
THIRD_PARTY_NOTICES.md
MIGRATION_STATUS.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/architecture.md
docs/model-author-guide.md
docs/configuration-reference.md
docs/data-format.md
docs/continuation.md
docs/gui-design.md
docs/migration-map.md
docs/provenance.md
docs/legacy-inventory.md
docs/legacy-data-contracts.md
docs/legacy-algorithms.md
docs/baseline-fixtures.md
```

Restore or adopt the repository's intended BSD 3-Clause project license
after verifying it with the repository owner/history. Add
`THIRD_PARTY_NOTICES.md` listing vendored source files, source repositories,
copyright headers, and applicable licenses. Do not remove or replace upstream
notices.

Add ADRs for:

- model/problem/service separation;
- declarative configuration;
- native artifact format;
- chart-aware continuation;
- legacy adapter strategy;
- scene format;
- synchronous/background job execution.

`MIGRATION_STATUS.md` must use evidence-based statuses:

```text
Not started
Partial
Implemented, untested
Tested
Blocked
```

Every `Tested` row must cite the exact command and result in
`docs/TEST_STATUS.md`.

---

## 10. Release validation commands

When MATLAB is available, run at least:

```bash
matlab -batch "cd('<TARGET>'); startup; registry=lmz.registry.ModelRegistry.discover(); disp(registry.listModels());"
```

```bash
matlab -batch "cd('<TARGET>'); results=run_tests; assert(~any([results.Failed]));"
```

Run every example in a controlled smoke-test harness. Run GUI smoke tests only
when a display is available; always run the headless controller tests.

Also run static checks for:

```text
global
restoredefaultpath
addpath(genpath
eval / evalin / assignin
direct optimizer calls from GUI
direct legacy zero-function calls from generic packages
raw model-specific indices in generic packages
missing catalog files/classes
duplicate model/problem IDs
scene references to missing frames
namespace collisions
```

Record exact commands, MATLAB release, toolbox availability, counts, failures,
and skipped tests.

---

## 11. Completion/release gates

Do not mark the project complete unless all applicable items hold.

### Core release gate

- registry discovers and instantiates all three models;
- registry works outside repository CWD;
- schemas/charts/artifacts/run controls pass tests;
- capabilities are truthful;
- no architecture violations remain.

### Quadruped release gate

- fixture imports;
- residual and simulation equivalence pass;
- gait classification works;
- solve/refinement works;
- second seed works;
- bidirectional continuation works;
- checkpoint/resume works;
- parameter homotopy and branch-family scan work;
- visualization/animation work;
- native save/load and legacy export work;
- command-line and GUI workflows work.

### Jerboa release gate

- import, residual, simulation, classification, solve, continuation,
  trajectory fitting, visualization, and persistence pass.

### Load release gate

- single/multi-stride packing, simulation, objective terms, optimization,
  visualization, and persistence pass.

### Documentation release gate

- status and test documents exactly match executed evidence;
- known differences are explicit;
- source provenance is complete;
- examples are runnable;
- original repositories remain unchanged.

If a release gate is blocked solely because MATLAB or a required toolbox is
not installed, complete every non-execution task, provide one-command
validation scripts, and mark the gate **Blocked**, not **Tested** or
**Complete**.

---

## 12. Final report format

At the end, report:

1. target repository path and final HEAD/working-tree state;
2. current MATLAB/toolbox availability;
3. files/classes implemented or materially changed;
4. legacy files vendored and their provenance;
5. exact commands executed;
6. exact test totals: passed, failed, incomplete, skipped;
7. baseline numerical differences and tolerances;
8. release gates satisfied;
9. release gates blocked and the precise reason;
10. remaining concrete work, if any.

Do not write “all tests pass” without the command output. Do not call stubs,
manifests, or unexecuted tests completed functionality.

Begin now by auditing the local target against this prompt, repairing Gate A,
and then continue through the gates without asking for confirmation.
