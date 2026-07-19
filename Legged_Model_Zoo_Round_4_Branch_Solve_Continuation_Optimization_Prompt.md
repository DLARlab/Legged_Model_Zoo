# Codex Round 4 — Implement Branch, Solution, Solve, Continuation, and Optimization

You are the senior MATLAB numerical-software engineer completing the existing
`DLARlab/Legged_Model_Zoo` repository.

Work directly in the current local clone. This is an implementation round, not
an architecture-only, simulation-demo, or GUI-shell round.

The five currently placeholder workflows must become executable:

```text
Branch
Solution
Solve
Continuation
Optimization
```

Do not finish with placeholder tabs, disabled controls, synthetic solver
results, empty abstract classes, or another status report saying that a
baseline is still required.

---

## 1. Current repository and verified starting point

Inspect the actual local repository before editing:

```bash
git status --short
git rev-parse HEAD
git log --oneline --decorate -10
```

Do not discard uncommitted user changes. Never use:

```text
git reset --hard
git clean -fd
git checkout -- .
history rewriting
force push
```

Do not push.

The public repository was last observed at:

```text
863e3e5d64f7cff488534962c6cb7f8e2f0fc7ce
```

The local checkout is authoritative if newer.

Read these files first:

```text
README.md
MIGRATION_STATUS.md
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

The observed current implementation has:

- canonical standalone model IDs:
  - `slip_biped`
  - `slip_quadruped`
  - `slip_quad_load`;
- a registry, schemas/charts, `RunContext`, artifacts, built-in JSON examples,
  simulation service, and a programmatic GUI;
- three self-contained analytic `demo_stride` simulations;
- a tested GUI construction and simulation workflow;
- no scientific legacy evaluator migrated into the active model problems;
- no native `SolutionBranch`;
- only a minimal `Solution` value object;
- no `SolveService`;
- no nonlinear solver implementation in the current active tree;
- no continuation implementation in the current active tree;
- no optimization implementation in the current active tree;
- Branch, Solution, Solve, Continuation, and Optimization GUI tabs that display
  only “not implemented” labels.

The previous MATLAB execution record shows:

```text
MATLAB R2025b Update 5
Optimization Toolbox available
Parallel Computing Toolbox available
27 tests run, 0 failed, 0 incomplete
```

Therefore the old blocker “requires numerical baseline” is no longer valid.
Capture baselines and implement the workflows in this round.

---

## 2. Non-negotiable outcomes

This round is complete only when all of the following are true.

### 2.1 Branch

The Branch tab can:

- load native branch artifacts;
- import supported legacy branches;
- load built-in scientific branch examples;
- display one or more branches;
- select named X, Y, and optional Z coordinates;
- plot 2-D or 3-D branch views;
- show hover information;
- select a point by clicking;
- synchronize the selected point with all other tabs;
- remove, hide, rename, and recolor plotted datasets;
- export a branch plot;
- save a native branch artifact;
- export a compatible legacy branch when an adapter supports it.

### 2.2 Solution

The Solution tab can inspect and edit a selected solution using schemas:

- decision variables;
- event variables;
- model parameters;
- observables;
- residual blocks;
- residual norms;
- feasibility/admissibility;
- gait classification;
- solver diagnostics;
- source branch/index;
- provenance and lineage.

Editing creates a working copy; it must not silently mutate the source branch.

The user can:

- restore source values;
- validate values;
- simulate the edited candidate;
- send it to Solve, Continuation, or Optimization;
- save it as a native solution artifact.

### 2.3 Solve

The Solve tab performs real nonlinear solving through generic services.

Minimum supported scientific problems:

```text
slip_biped / periodic_apex
slip_quadruped / periodic_apex
```

The tab supports:

- seed from selected branch point;
- seed from edited Solution tab;
- seed from manual branch index;
- reproducible perturbation/noise;
- explicit seed/event projection;
- solver options;
- solve;
- cancel;
- progress/logging;
- residual and feasibility report;
- source-versus-solved comparison;
- simulation of solved result;
- save solution;
- add solved result to a branch/dataset.

No GUI callback may call `fsolve` directly.

### 2.4 Continuation

The Continuation tab performs real generic pseudo-arclength continuation.

Minimum supported scientific problems:

```text
slip_biped / periodic_apex
slip_quadruped / periodic_apex
```

It supports:

- first-seed selection;
- second-seed construction at a requested chart/metric radius;
- validation of a manually supplied seed pair;
- bidirectional branch tracing;
- accepted/rejected point callbacks;
- live branch plot;
- pause;
- resume;
- controlled stop;
- cancellation;
- atomic checkpointing;
- checkpoint resume;
- adaptive step size;
- correction backtracking;
- duplicate rejection;
- loop/closure detection;
- termination-reason reporting;
- saving the branch;
- parameter homotopy;
- branch-family scan.

Do not label a branch-family scan as two-dimensional continuation.

### 2.5 Optimization

The Optimization tab performs real optimization through generic services.

Minimum supported problems:

```text
slip_biped / trajectory_fit
slip_quad_load / multi_stride_fit
```

It supports:

- seed/initial vector selection;
- editable objective-term weights;
- bounds and solver settings;
- run;
- cancel;
- progress/logging;
- objective history;
- per-term objective contributions;
- constraints/feasibility diagnostics;
- initial-versus-optimized comparison;
- simulation and visualization of the optimized result;
- save optimization-run and solution artifacts.

No GUI callback may call `fmincon` or `fminsearch` directly.

---

## 3. Architectural rules

Preserve this dependency direction:

```text
GUI
  -> application services
  -> generic numerical algorithms
  -> problem contracts
  -> model / model-specific compatibility evaluator
```

Presentation consumes structured data:

```text
BranchPlot       <- SolutionBranch
SolutionView     <- Solution
SimulationView   <- SimulationResult
OptimizationView <- OptimizationResult
```

Rules:

1. Do not use `global`.
2. Do not use `restoredefaultpath`.
3. Do not use `addpath(genpath(...))`.
4. Do not use `eval`, `evalin`, or `assignin`.
5. Generic packages must not contain model-specific raw indices.
6. Positional indexing is allowed only in named model-specific layouts,
   adapters, or compatibility evaluators.
7. Native residual evaluation must be deterministic and must not invoke
   another solver internally.
8. Event-time repair is an explicit projector/service.
9. Parameter clipping, `abs`, and transforms are explicit and diagnosed.
10. Randomized methods accept and record a seed or `RandStream`.
11. Long algorithms use `RunContext` for progress, logging, pause,
    cancellation, and checkpoints.
12. Persist plain structs as the public artifact format.
13. Normal runtime and tests must remain independent of sibling research
    repositories.
14. Do not claim numerical equivalence without executed evidence.
15. Update README and status documents after each coherent implementation gate.

---

## 4. Gate 0 — Capture the scientific baselines now

The immutable local source repositories are expected to be available during
migration:

```text
SLIP_Model_Zoo
2022_A_Template_Model_Explains_Jerboa_Gait_Transitions
2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights
```

Locate and verify them by Git remote. Do not modify them.

Use MATLAB R2025b and the available Optimization Toolbox to run isolated
baseline-capture scripts. These scripts may temporarily add only the exact
required source subdirectories and must restore the MATLAB path with
`onCleanup`.

Create:

```text
tools/maintainers/capture_slip_biped_baselines.m
tools/maintainers/capture_slip_quadruped_baselines.m
tools/maintainers/capture_slip_quad_load_baselines.m
```

Store small plain baseline artifacts under:

```text
tests/fixtures/baselines/slip_biped/
tests/fixtures/baselines/slip_quadruped/
tests/fixtures/baselines/slip_quad_load/
```

Each baseline records:

- source repository URL;
- source commit SHA;
- source file;
- source fixture hash;
- selected branch column or dataset;
- MATLAB version;
- solver options where relevant;
- input decision/parameters;
- residual vector;
- residual norm;
- time;
- state trajectory;
- event states;
- forces/observables;
- classification;
- objective terms where relevant.

Capture at least:

### `slip_biped`

- one walk point;
- one run point when available;
- one adjacent seed pair;
- residual;
- trajectory;
- event states;
- gait classification;
- one solved point;
- trajectory-fit objective components.

### `slip_quadruped`

- several roadmap points;
- one adjacent same-gait seed pair;
- deterministic `skipSolve` residual;
- explicit event-time projection separately;
- trajectory;
- event states;
- GRFs;
- gait classification;
- one solved point.

### `slip_quad_load`

- one single-stride case;
- one multi-stride case if available;
- decoded packed layout;
- trajectory;
- quadruped/load states;
- event states;
- GRFs;
- tugline force;
- stride-duration mismatch;
- footfall-timing mismatch;
- loading-force mismatch;
- total objective and R-squared metrics.

After capture, normal tests must read only the stored baseline artifacts and
must not require the source repositories.

Update `docs/TEST_STATUS.md` with the exact commands and measured tolerances.

---

## 5. Gate 1 — Complete the core problem and data contracts

The active tree needs real numerical problem and branch contracts.

Implement or complete:

```text
src/+lmz/+api/BaseProblem.m
src/+lmz/+api/NonlinearEquationProblem.m
src/+lmz/+api/OptimizationProblem.m
src/+lmz/+data/ResidualBlock.m
src/+lmz/+data/ProblemEvaluation.m
src/+lmz/+data/Solution.m
src/+lmz/+data/SolutionPair.m
src/+lmz/+data/SolutionBranch.m
src/+lmz/+data/BranchDataset.m
src/+lmz/+data/SolveResult.m
src/+lmz/+data/OptimizationResult.m
src/+lmz/+data/ContinuationSnapshot.m
src/+lmz/+data/ContinuationResult.m
src/+lmz/+data/Selection.m
```

### 5.1 `BaseProblem`

Required methods:

```text
getDescriptor
getDecisionSchema
getParameterSchema
canonicalize
difference
retract
scale
decodeDecision
toSimulationRequest
validateDecision
validateSolution
listObservables
evaluateObservables
makeSolution
```

### 5.2 `NonlinearEquationProblem`

Required methods:

```text
evaluate
residual
unknownDimension
residualDimension
expectedLocalDimension
optionalJacobian
projectSeed
```

`evaluate` returns `ProblemEvaluation` containing:

- ordered residual blocks;
- scaled and unscaled residuals;
- residual norms;
- optional simulation;
- feasibility;
- physical validity;
- warnings;
- diagnostics.

### 5.3 `OptimizationProblem`

Required methods:

```text
evaluateObjective
objectiveTerms
nonlinearConstraints
bounds
optionalLinearConstraints
makeSolution
```

### 5.4 `Solution`

Replace the current permissive property bag with a validated value contract.

Required fields:

```text
Id
ModelId
ModelVersion
ProblemId
ProblemVersion
DecisionSchema
ParameterSchema
DecisionValues
ParameterValues
Observables
ResidualBlocks
Diagnostics
Classification
Feasibility
Lineage
Provenance
CreatedAt
```

Required behavior:

```text
validate
decision(name)
parameter(name)
withDecisionValues
withParameterValues
toStruct
fromStruct
toArtifact
fromArtifact
```

### 5.5 `SolutionBranch`

Use an efficient schema-based representation. It may store matrices internally,
but public access is named and point-oriented.

Required fields/invariants:

```text
Id
ModelId
ProblemId
DecisionSchema
ParameterSchema
DecisionValues       % nDecision-by-nPoint
ParameterValues      % nParameter-by-nPoint or constant-column policy
PointMetadata
Observables
Classifications
Arclength
Tangents
Lineage
Diagnostics
Provenance
```

Required behavior:

```text
pointCount
point(index)
append(solution, metadata)
replacePoint
subset
reverse
concatenate
observable(name)
decision(name)
parameter(name)
nearestPoint
validate
toStruct/fromStruct
toArtifact/fromArtifact
```

Define and test whether parameters are stored per point or broadcast from one
column. Do not leave this ambiguous.

### 5.6 `BranchDataset` and selection

`BranchDataset` wraps a branch plus GUI/display metadata:

```text
Name
Visible
DisplayStyle
SourcePath
ReadOnly
Branch
```

`Selection` records:

```text
DatasetId
PointIndex
SolutionId
Source
```

The same `Selection` object must synchronize Branch, Solution, Simulation,
Solve, Continuation, and Optimization workspaces.

---

## 6. Gate 2 — Migrate the actual scientific model problems

Do not implement solving against the analytic `demo_stride` problems.

Keep `demo_stride` only as an optional introductory demonstration. Add the
scientific problems below and migrate the exact compatibility evaluators into
the standalone repository.

### 6.1 `slip_biped`

Add catalog problems:

```text
periodic_apex
trajectory_fit
```

Implement under:

```text
models/+lmzmodels/+slip_biped/
```

At minimum:

```text
PeriodicDecisionSchema
OffsetParameterSchema
PhysicalStateSchema
PeriodicApexProblem
TrajectoryFitProblem
Results14Adapter
LegacyEvaluator
SeedProjector
GaitClassifier
Kinematics
ObjectiveTerms/
```

Migrate the transitive runtime dependencies of:

```text
ZeroFunc_BipedApex_offset.m
ZeroFunc_BipedApex_offset_optimization.m
Gaitidentify.m
required event/timing helpers
objective functions
constraint functions
resampling functions
required graphics-independent geometry helpers
```

Requirements:

- preserve the 12-entry periodic decision plus two offsets;
- treat offsets as named problem parameters unless a documented reason
  requires them in the decision vector;
- preserve compatibility residual structure, including redundant/zero blocks;
- expose deterministic residual evaluation;
- expose simulation through `SimulationResult`;
- expose trajectory-fit objective terms individually;
- support native branch import/export;
- ship built-in scientific solution/branch artifacts.

### 6.2 `slip_quadruped`

Add catalog problem:

```text
periodic_apex
```

Implement under:

```text
models/+lmzmodels/+slip_quadruped/
```

At minimum:

```text
PeriodicDecisionSchema
ParameterSchema
PhysicalStateSchema
PeriodicApexProblem
EventScheduleProjector
Results29Adapter
LegacyEvaluator
GaitClassifier
Kinematics
```

Migrate transitive runtime dependencies of:

```text
Quadrupedal_ZeroFun_v2.m
EventTimingRegulation.m
Gait_Identification.m
generated stance-leg functions
GRF helpers
required event and geometry helpers
```

Requirements:

- decision schema: 13 initial-state entries plus 9 event times;
- parameter schema: 7 parameters;
- deterministic residual calls the legacy-compatible evaluator with hidden
  event-time solving disabled;
- event-time repair is explicit;
- simulation returns event records, contacts, GRFs, and named states;
- `Results29Adapter` returns a native `SolutionBranch`;
- exact 29-row export remains available;
- ship a small built-in scientific roadmap branch.

### 6.3 `slip_quad_load`

Add catalog problems:

```text
single_stride_periodic
multi_stride_fit
```

Implement under:

```text
models/+lmzmodels/+slip_quad_load/
```

At minimum:

```text
SingleStrideDecisionSchema
MultiStrideDecisionSchema
QuadrupedParameterSchema
LoadParameterSchema
SingleStrideProblem
MultiStrideFitProblem
XAccumAdapter
LegacyEvaluator
MultiStrideSimulator
Kinematics
ObjectiveTerms/
```

Migrate transitive runtime dependencies of:

```text
Quad_Load_ZeroFun_Transition_v2.m
SimulateQuadLoadStrides.m
fms_NStridesObjectiveFcn_Quad_Load_v2.m
required event/timing helpers
generated dynamics helpers
resampling and metric helpers
```

Centralize the confirmed packed layout:

```text
44 + 13*(N-1)
```

Do not duplicate packing logic in the simulator and objective.

Objective terms:

```text
StrideDurationMismatch
FootfallTimingMismatch
LoadingForceMismatch
CompositeObjective
R2Metrics
```

Ship built-in scientific single- and multi-stride artifacts.

### 6.4 Compatibility tests

For each scientific problem, compare against Gate 0 baselines:

- residual values;
- event records;
- trajectories on a common interpolation grid;
- forces/observables;
- classifications;
- objective terms.

Measure and document tolerances. Do not use arbitrary tolerances.

Only after these tests pass may the corresponding scientific capability be
set to true.

---

## 7. Gate 3 — Branch and Solution services

Implement:

```text
src/+lmz/+services/BranchService.m
src/+lmz/+services/SolutionService.m
```

### 7.1 `BranchService`

Required operations:

```text
loadNativeBranch
saveNativeBranch
importLegacyBranch
exportLegacyBranch
loadBuiltInBranch
addDataset
removeDataset
setVisibility
setDisplayStyle
coordinateValues
nearestPoint
selectPoint
```

Supported legacy imports:

```text
slip_biped Results14
slip_quadruped Results29
slip_quad_load X_accum/dataset formats where branch semantics are defined
```

### 7.2 `SolutionService`

Required operations:

```text
solutionFromSelection
workingCopy
validate
simulate
save
addToBranch
compare
```

Comparison returns named differences using the problem chart, not raw
subtraction for cyclic event times.

---

## 8. Gate 4 — Implement generic nonlinear solving

Implement:

```text
src/+lmz/+solvers/RootSolver.m
src/+lmz/+solvers/FsolveSolver.m
src/+lmz/+solvers/MultiStartSolver.m
src/+lmz/+solvers/SolverOptions.m
src/+lmz/+services/SolveService.m
src/+lmz/+services/SeedService.m
```

### 8.1 `FsolveSolver`

Requirements:

- consumes only `NonlinearEquationProblem`;
- supports square and overdetermined residuals;
- uses problem-supplied scaling;
- validates Optimization Toolbox availability;
- integrates `RunContext`;
- preserves any existing solver output callback;
- records options, exit flag, output, iterations, function count, residuals,
  feasibility, and provenance;
- never directly references a concrete model evaluator;
- never silently changes algorithms.

### 8.2 Seed projection

`SeedService.project` invokes the problem's explicit seed projector. Projection
diagnostics must record:

```text
input seed
output seed
changed variables
projector version
projection residual
solver diagnostics if a projector solves a subproblem
```

Residual evaluation itself must not invoke projection.

### 8.3 Reproducible perturbation and multistart

Provide named scaling-aware noise:

```text
absolute
relative
schema-scaled
```

Use `RandStream` or a recorded seed.

`MultiStartSolver` returns:

- every attempt;
- seed;
- exit flag;
- residual norm;
- cluster assignment;
- selected result.

### 8.4 Solve tests

Add:

- analytic square root problem;
- analytic overdetermined problem;
- cancellation/output callback test;
- reproducible multistart test;
- `slip_biped` seed refinement;
- `slip_quadruped` seed refinement;
- baseline residual verification after solve.

---

## 9. Gate 5 — Implement generic second-seed and continuation

Implement:

```text
src/+lmz/+continuation/ContinuationOptions.m
src/+lmz/+continuation/SecantPredictor.m
src/+lmz/+continuation/PseudoArclengthCorrector.m
src/+lmz/+continuation/StepSizeController.m
src/+lmz/+continuation/CurvatureController.m
src/+lmz/+continuation/BacktrackingController.m
src/+lmz/+continuation/DuplicateDetector.m
src/+lmz/+continuation/LoopClosureDetector.m
src/+lmz/+continuation/ContinuationAcceptancePolicy.m
src/+lmz/+continuation/PseudoArclengthContinuation.m
src/+lmz/+continuation/ParameterHomotopy.m
src/+lmz/+continuation/BranchCatalog.m
src/+lmz/+continuation/BranchFamilyScan.m
src/+lmz/+continuation/CheckpointStore.m
src/+lmz/+services/ContinuationService.m
```

### 9.1 Mathematical contract

For:

\[
F:\mathbb{R}^{n}\rightarrow\mathbb{R}^{m},
\]

do not require \(m=n-1\).

A regular one-dimensional local solution set has:

\[
n-\operatorname{rank}J_F(u)=1.
\]

A problem declares `expectedLocalDimension = 1`. Estimate and report numerical
rank/nullity when a Jacobian is available or can be estimated.

Use:

\[
\delta_k=\operatorname{difference}(u_k,u_{k-1}),
\qquad
\tau_k=\frac{\delta_k}{\|W\delta_k\|_2},
\]

\[
u_{\mathrm{pred}}=\operatorname{retract}(u_k,h_k\tau_k),
\]

and the augmented corrector:

\[
G(u)=
\begin{bmatrix}
S_F F(u)\\
(W\tau_k)^\mathsf{T}
W\,\operatorname{difference}(u,u_{\mathrm{pred}})
\end{bmatrix}.
\]

Use the same chart and metric for every geometric operation.

### 9.2 Second seed

Implement `SeedService.makeSecondSeed` or a dedicated `SecondSeedSolver`.

It solves:

- the base nonlinear equations;
- a chart/metric distance equation from the first seed.

It must:

- achieve the requested radius within tolerance;
- preserve/verify gait or topology when policy requires;
- report residual and distance error;
- use reproducible fallback directions;
- return `SolutionPair`.

### 9.3 Continuation behavior

Required:

- bidirectional branch tracing;
- lifted cyclic timing coordinates;
- predictor/corrector;
- correction backtracking;
- adaptive numerical step;
- curvature limitation;
- duplicate rejection;
- stagnation detection;
- historical segment loop closure;
- accepted/rejected progress events;
- pause/resume;
- stop/cancel;
- atomic checkpoint per accepted point or configured interval;
- resume;
- explicit termination reasons;
- partial branch preservation.

No plotting, GUI prompts, filenames, gait labels, speed thresholds, or
model-specific indices belong in the engine.

### 9.4 Parameter homotopy

Transport one solution or seed pair across a named parameter using adaptive
steps, solve correction, and feasibility checks.

### 9.5 Branch-family scan

Run 1-D continuation at requested parameter targets using:

- source branch metadata;
- lineage;
- resumable output;
- completed/skipped/failed/blocked reports.

Call it `BranchFamilyScan`, not 2-D continuation.

### 9.6 Continuation tests

Add analytic tests for:

- fold traversal:
  \[
  x^2-\lambda=0;
  \]
- closed curve and loop detection;
- cyclic variable;
- changing period;
- overdetermined rank-deficient residual;
- duplicate rejection;
- backtracking;
- pause/cancel;
- checkpoint/resume.

Add model tests:

- short `slip_biped` branch;
- short `slip_quadruped` branch;
- second-seed radius;
- parameter homotopy;
- small branch-family scan.

---

## 10. Gate 6 — Implement generic optimization

Implement:

```text
src/+lmz/+optimization/ObjectiveTerm.m
src/+lmz/+optimization/CompositeObjective.m
src/+lmz/+optimization/FminconSolver.m
src/+lmz/+optimization/FminsearchSolver.m
src/+lmz/+optimization/OptimizationOptions.m
src/+lmz/+services/OptimizationService.m
```

Requirements:

- consume only `OptimizationProblem`;
- expose named term values at every accepted iteration where practical;
- support bounds and nonlinear constraints;
- integrate `RunContext`;
- record objective history;
- preserve solver output callbacks;
- record complete options/provenance;
- do not silently use `fminsearch` when `fmincon` was requested;
- provide deterministic initial perturbation where requested.

Minimum scientific workflows:

### `slip_biped / trajectory_fit`

Fit selected trajectory quantities using named objective terms and constraints.

### `slip_quad_load / multi_stride_fit`

Fit:

- stride duration;
- footfall timing;
- tugline/loading force.

Tests must verify individual term equivalence to baselines and a short
optimization that decreases the objective from its initial value.

---

## 11. Gate 7 — Replace the five GUI placeholder tabs

Refactor the GUI into reviewable components. The existing single app class may
coordinate layout, but tab logic belongs in components/controllers.

Suggested structure:

```text
src/+lmz/+gui/LeggedModelZooApp.m
src/+lmz/+gui/AppState.m
src/+lmz/+gui/AppController.m
src/+lmz/+gui/+tabs/BranchTab.m
src/+lmz/+gui/+tabs/SolutionTab.m
src/+lmz/+gui/+tabs/SimulationTab.m
src/+lmz/+gui/+tabs/SolveTab.m
src/+lmz/+gui/+tabs/ContinuationTab.m
src/+lmz/+gui/+tabs/OptimizationTab.m
src/+lmz/+gui/+components/
```

Remove `addUnavailableTab`.

### 11.1 Expand `AppState`

At minimum:

```text
ModelId
ProblemId
ExampleId
Datasets
ActiveDatasetId
Selection
WorkingSolution
Simulation
SolveResult
SeedPair
ContinuationResult
OptimizationResult
CurrentRun
StatusMessages
```

State transitions must be explicit and testable.

### 11.2 Expand `AppController`

Add methods such as:

```text
loadBranch
loadArtifact
loadBuiltInBranch
saveActiveBranch
setActiveDataset
selectBranchPoint
workingSolution
updateWorkingDecision
updateWorkingParameter
validateWorkingSolution
simulateWorkingSolution
solveWorkingSolution
applySeedNoise
makeSecondSeed
runContinuation
pauseCurrentRun
resumeCurrentRun
stopCurrentRun
resumeContinuationCheckpoint
runParameterHomotopy
runBranchFamilyScan
runOptimization
saveSolution
saveContinuation
saveOptimization
```

The controller calls services, never MATLAB optimizers directly.

### 11.3 Branch tab

Implement:

- dataset list;
- visibility controls;
- named coordinate dropdowns;
- 2-D/3-D axes;
- hover and click selection;
- selected-point marker;
- synchronized selection;
- export;
- save/import actions.

Use `WindowButtonMotionFcn` or data tips carefully and test the controller
selection independently of UI events.

### 11.4 Solution tab

Implement schema-generated tables:

- group;
- name;
- label;
- value;
- unit;
- bounds;
- source/edited status.

Provide residual block table, observables, classification, and provenance.

### 11.5 Solve tab

Implement:

- seed source;
- noise controls and seed;
- projector controls;
- solver settings;
- solve/cancel;
- progress;
- residual diagnostics;
- compare and save.

### 11.6 Continuation tab

Implement:

- first seed source;
- second seed/radius;
- seed-pair diagnostics;
- continuation options;
- live branch preview;
- run/pause/resume/stop;
- checkpoint path;
- homotopy controls;
- branch-family scan controls;
- termination report.

### 11.7 Optimization tab

Implement:

- problem selector where multiple optimization tasks exist;
- variable/parameter seed;
- objective-term table and weights;
- solver settings;
- run/cancel;
- objective-history plot;
- term-contribution table;
- result comparison;
- save/export.

### 11.8 Run execution

A synchronous cooperative runner must always work.

Optional background execution may use `parfeval`, but:

- it is never required;
- the same controller/service APIs are used;
- cancellation and cleanup are correct;
- GUI controls disable/enable consistently.

### 11.9 GUI tests

Add headless controller tests for every workflow and desktop construction
tests when available:

```text
TestBranchController
TestSolutionController
TestSolveController
TestContinuationController
TestOptimizationController
TestAppConstruction
TestAppSelectionSynchronization
TestAppCapabilityEnablement
TestAppRunCancellation
```

Perform at least one manual interactive desktop inspection and record it in
`docs/TEST_STATUS.md`:

- launch;
- resize;
- load branch;
- click point;
- solve;
- start/pause/resume/stop continuation;
- run optimization;
- close while idle;
- close during a controlled run.

---

## 12. Gate 8 — Persistence and standalone built-in scientific data

Extend `ArtifactStore` and builders for:

```text
solution
branch
simulation
solve-run
continuation-run
optimization-run
checkpoint
branch-family-report
```

Validate artifact-type-specific fields, dimensions, schemas, finite values,
lineage, options, termination reasons, random seeds, and source commits.

Every GUI save action writes a native artifact atomically.

Ship scientific built-in assets under:

```text
examples/data/slip_biped/
examples/data/slip_quadruped/
examples/data/slip_quad_load/
```

At minimum:

- biped solution and branch;
- quadruped roadmap branch;
- quadruped-load fitting dataset.

Normal runtime and all ordinary tests must work in an isolated copy with no
sibling source repositories.

Retain the isolation test and expand it to cover:

- branch loading;
- solution inspection;
- one short solve;
- one short continuation;
- one short optimization;
- GUI construction.

---

## 13. Gate 9 — Capabilities, manifests, and README

Update model manifests only when implementations are executable and tested.

Expected release capabilities:

### `slip_biped`

```text
simulate = true
visualize = true
animate = true
solve = true
continue = true
optimize = true
```

### `slip_quadruped`

```text
simulate = true
visualize = true
animate = true
solve = true
continue = true
parameterHomotopy = true
branchFamilyScan = true
```

### `slip_quad_load`

```text
simulate = true
visualize = true
animate = true
optimize = true
```

Do not claim solve/continuation for `slip_quad_load` unless a corresponding
scientific nonlinear-equation problem is implemented.

Update README after every coherent gate. The final README must include
executable sections for:

- loading a branch;
- selecting a solution;
- solving;
- second-seed generation;
- continuation;
- checkpoint resume;
- parameter homotopy;
- branch-family scan;
- optimization;
- the corresponding GUI tabs.

Remove statements that these workflows are unimplemented once they pass.

Run after each gate:

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(),'tools'));
cleanup = onCleanup(@() rmpath(fullfile(lmz.util.ProjectPaths.root(),'tools')));
update_readme_status;
check_readme_contract;
```

---

## 14. Required public examples

Create and execute:

```text
examples/demo_branch_explorer.m
examples/demo_solution_inspector.m
examples/demo_slip_biped_solve.m
examples/demo_slip_biped_continuation.m
examples/demo_slip_biped_fit.m
examples/demo_slip_quadruped_solve.m
examples/demo_slip_quadruped_continuation.m
examples/demo_parameter_homotopy.m
examples/demo_branch_family_scan.m
examples/demo_slip_quad_load_fit.m
examples/demo_full_gui_workflow.m
```

Each example:

- uses public APIs only;
- uses repository-contained scientific data;
- does not add sibling repositories to the path;
- returns structured results;
- is safe to run repeatedly;
- is referenced accurately in README.

---

## 15. Required tests

Use `matlab.unittest`.

At minimum add:

```text
TestSolutionValidation
TestSolutionStructRoundTrip
TestSolutionArtifactRoundTrip
TestSolutionBranchAppend
TestSolutionBranchSubset
TestSolutionBranchArtifactRoundTrip
TestBranchDataset
TestSelectionSynchronization
TestSlipBipedScientificImport
TestSlipBipedResidualEquivalence
TestSlipBipedSimulationEquivalence
TestSlipBipedSolve
TestSlipBipedTrajectoryFitTerms
TestSlipQuadrupedNativeBranchImport
TestSlipQuadrupedResidualEquivalence
TestSlipQuadrupedSimulationEquivalence
TestSlipQuadrupedGaitClassification
TestSlipQuadrupedSolve
TestSlipQuadLoadXAccumImport
TestSlipQuadLoadPacking
TestSlipQuadLoadSimulationEquivalence
TestSlipQuadLoadObjectiveTerms
TestFsolveSolver
TestMultiStartReproducibility
TestSeedProjectionExplicitness
TestSecondSeedSolver
TestAnalyticFoldContinuation
TestOverdeterminedContinuation
TestCyclicContinuation
TestContinuationBacktracking
TestContinuationCancellation
TestContinuationCheckpointResume
TestContinuationLoopClosure
TestParameterHomotopy
TestBranchFamilyScan
TestFminconSolver
TestOptimizationObjectiveDecrease
TestBranchController
TestSolutionController
TestSolveController
TestContinuationController
TestOptimizationController
TestAppSelectionSynchronization
TestStandaloneAdvancedWorkflows
TestReadmeContract
TestArchitectureRules
```

Run the complete suite:

```bash
/Applications/MATLAB_R2025b.app/bin/matlab -batch \
"cd('<TARGET>'); results=run_tests; assert(~any([results.Failed]));"
```

Also execute every public example in a clean batch process.

Do not weaken existing tests merely to make the suite pass.

---

## 16. Static architecture enforcement

Extend static checks to reject:

```text
global
restoredefaultpath
addpath(genpath
eval / evalin / assignin
direct fsolve/fmincon/fminsearch calls from GUI
direct legacy evaluator calls from GUI
direct legacy evaluator calls from generic services
model-specific indices in generic packages
placeholder “not implemented” tabs
status='not-implemented' problem objects
new artifacts with deprecated model IDs
runtime dependencies on sibling repositories
```

Allow MATLAB optimizer calls only inside their dedicated solver adapter
classes.

Allow compatibility evaluator calls only inside model-specific problem or
evaluator packages.

---

## 17. Documentation and provenance

Complete or update:

```text
README.md
MIGRATION_STATUS.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/architecture.md
docs/data-format.md
docs/continuation.md
docs/gui-design.md
docs/model-author-guide.md
docs/provenance.md
THIRD_PARTY_NOTICES.md
CHANGELOG.md
```

Record every migrated legacy file, source path, commit, license/header, and
modification.

`MIGRATION_STATUS.md` may use only:

```text
Not started
Partial
Implemented, untested
Tested
Blocked
```

A `Tested` status must cite exact execution evidence in `docs/TEST_STATUS.md`.

---

## 18. Definition of done

Do not finish this round unless:

1. `SolutionBranch` exists and is used by native and legacy branch workflows.
2. Branch and Solution GUI tabs contain functional controls and synchronized
   selection.
3. `slip_biped/periodic_apex` and
   `slip_quadruped/periodic_apex` are scientific nonlinear-equation problems,
   not analytic demo problems.
4. both periodic problems solve through generic `SolveService`;
5. both periodic problems trace short branches through generic
   `ContinuationService`;
6. second-seed generation, checkpoints, pause/resume/stop, homotopy, and
   family scans are executable;
7. `slip_biped/trajectory_fit` and
   `slip_quad_load/multi_stride_fit` optimize through generic
   `OptimizationService`;
8. Optimization shows named objective contributions;
9. the five GUI tabs no longer display “not implemented” placeholders;
10. native artifacts round-trip for solution, branch, solve, continuation,
    optimization, and checkpoint types;
11. normal runtime remains standalone;
12. README documents and accurately demonstrates all workflows;
13. the complete MATLAB suite and public examples execute with exact recorded
    results;
14. an isolated-copy advanced-workflow test executes without sibling
    repositories;
15. the three source repositories remain unchanged.

If an individual model operation is genuinely blocked by a source defect,
complete every independent generic and GUI component, document the exact
source-level blocker with a failing regression test, and do not mark that
capability true.

---

## 19. Final report

Report:

1. target path and final Git status;
2. final HEAD;
3. scientific problems implemented;
4. branch/solution data classes implemented;
5. solver, continuation, and optimization classes implemented;
6. GUI tabs and workflows manually exercised;
7. migrated source files and provenance;
8. exact commands executed;
9. exact test totals;
10. baseline differences and tolerances;
11. standalone isolation result;
12. README contract result;
13. remaining blocked items, if any.

Do not report “implemented” for a tab that only constructs, “tested” for a test
that was not run, or “scientific model” for an analytic demonstration.

Begin with Gate 0 baseline capture, then implement the branch/solution data
contracts, then the `slip_quadruped` scientific solve/continuation vertical
slice. Next implement `slip_biped`, then `slip_quad_load` optimization, and
finally replace all five GUI placeholder tabs. Continue without asking for
confirmation.
