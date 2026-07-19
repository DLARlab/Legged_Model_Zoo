# Codex Round 6 — Complete Scientific Biped and Load-Pulling Models, Then Harden the Release

You are the senior MATLAB numerical-software engineer completing the existing
`DLARlab/Legged_Model_Zoo` repository.

Work directly in the current local clone. This is not a new architecture
exercise. Preserve the completed SLIP quadruped RoadMap vertical slice and use
it as a non-regression gate while migrating the remaining two research models:

```text
slip_biped
slip_quad_load
```

The round is complete only when the biped and load-pulling implementations are
source-equivalent scientific migrations rather than compact native
demonstrations, and the complete application is release-hardened.

Do not stop after copying files, creating schemas, adding manifests, or
constructing GUI tabs. Execute the scientific workflows and record evidence.

---

## 1. Verify the actual starting point

Before editing:

```bash
git status --short
git rev-parse HEAD
git log --oneline --decorate -10
```

Do not discard uncommitted user work. Never use:

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
a9581d5fd973bda9799f7d06dca8d0d8a7eda219
```

The local checkout is authoritative if newer.

Read:

```text
README.md
MIGRATION_STATUS.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/architecture.md
docs/continuation.md
docs/data-format.md
docs/gui-design.md
docs/provenance.md
THIRD_PARTY_NOTICES.md
CHANGELOG.md
```

Inspect the current implementations under:

```text
models/+lmzmodels/+slip_biped/
models/+lmzmodels/+slip_quad_load/
src/+lmz/+optimization/
src/+lmz/+continuation/
src/+lmz/+services/
src/+lmz/+gui/
```

The verified starting point is:

- the complete `slip_quadruped` RoadMap vertical slice is repository-contained;
- nine MAT branches, two reference FIG files, and 3,443 RoadMap points are
  present;
- the scientific quadruped evaluator, Results29 native conversion, physical
  simulation, animation, trajectories, GRFs, oscillator, solve, continuation,
  homotopy, family scan, recording, artifacts, GUI, and isolation workflow
  execute;
- the full R2025b suite reports 55 tests, zero failures, zero incomplete;
- `slip_biped` remains a two-variable stride-closure demonstration;
- `slip_biped/trajectory_fit` remains a two-term target-value demonstration;
- `slip_quad_load/multi_stride_fit` remains a three-variable target-value
  demonstration;
- biped Results14 scientific import/equivalence is missing;
- load `X_accum`, 44+13(N-1) scientific simulation, and objective equivalence
  are missing;
- human desktop inspection, R2019b execution, some forced continuation
  termination cases, and redistribution review remain incomplete.

Do not weaken or remove the quadruped RoadMap tests to make later changes pass.

---

## 2. Non-negotiable outcomes

### 2.1 `slip_biped` becomes a scientific migration

At completion, `slip_biped` must provide:

```text
published 12-decision periodic problem
two named swing-offset parameters
15-entry compatibility residual
Results14 branch import/export
walk/run/hop/skip/asymmetric built-in branches
physical event-driven simulation
gait classification
animation and trajectories
generic solve
generic continuation
source-equivalent trajectory fitting
native artifacts
GUI workflows
```

The existing two-variable `speed*period=stride_length` problem may remain only
as a separately named tutorial problem such as `demo_stride_closure`. It must
not be the default `periodic_apex` problem and must not be described as the
research biped model.

### 2.2 `slip_quad_load` becomes a scientific migration

At completion, `slip_quad_load` must provide:

```text
source-equivalent single-stride simulation
source-equivalent multi-stride simulation
unambiguous 44+13(N-1) decision packing
X_accum and dataset import
quadruped and load states
events and contact modes
GRFs
tugline force
stride-duration objective
footfall-timing objective
loading-force objective
R-squared metrics
generic optimization
physical visualization and analysis plots
native artifacts
GUI workflows
```

The existing three-variable target-value objective may remain only as an
explicit tutorial problem. It must not be the default scientific
`multi_stride_fit`.

### 2.3 Quadruped RoadMap remains green

All existing RoadMap assets, hashes, regression baselines, scientific solve,
continuation, GUI, recording, and isolation tests must continue to pass.

### 2.4 Problem maturity is explicit

Do not let model-wide capability flags imply that every declared problem is
scientifically validated.

Every problem descriptor must contain:

```text
maturity
provenance
validationStatus
capabilities
```

Allowed maturity values:

```text
tutorial
compatibility
validated
experimental
```

The GUI and README must visibly distinguish tutorial tasks from
source-equivalent validated tasks.

New artifacts must record the selected problem's maturity and validation
status.

### 2.5 Release hardening is performed

Complete:

```text
manual desktop workflow inspection
continuation edge-case tests
meaningful active-parameter homotopy
R2019b compatibility review/execution where available
redistribution decision record
complete user documentation
```

---

## 3. Immutable migration sources

Locate and verify these local repositories by Git origin and commit:

```text
2022_A_Template_Model_Explains_Jerboa_Gait_Transitions
2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights
SLIP_Model_Zoo
```

Treat all three as immutable:

- do not edit them;
- do not commit inside them;
- do not reformat them;
- verify clean working trees at the end.

The finished runtime and ordinary tests must not require these repositories.

Source repositories may be used only by maintainer capture/import scripts.
All runtime code, generated functions, built-in data, and regression baselines
must be copied into `Legged_Model_Zoo` with provenance.

Preserve source headers and document every copied or adapted file in:

```text
docs/provenance.md
THIRD_PARTY_NOTICES.md
```

Do not infer an open-source license when none is present.

---

# PART A — Scientific `slip_biped`

## 4. Capture biped source baselines before changing behavior

Create:

```text
tools/maintainers/capture_slip_biped_source_baselines.m
tools/maintainers/import_slip_biped_gaitmap.m
tools/maintainers/verify_slip_biped_gaitmap.m
```

Use the immutable biped repository at its recorded source commit.

Inspect and migrate the complete transitive runtime of:

```text
Main.m
Section3_optimization/Optimization.m
Stored_Functions/ZeroFunc_BipedApex_offset.m
Stored_Functions/ZeroFunc_BipedApex_offset_optimization.m
Stored_Functions/NumericalContinuation1D.m
Stored_Functions/ContinuationEqn.m
Stored_Functions/Gaitidentify.m
Stored_Functions/ShowTrajectory_BipedalDemo.m
all objective functions
all nonlinear constraint functions
all resampling helpers
all event/timing helpers
all required graphics-independent geometry helpers
```

Capture source baselines for representative available branches:

```text
walking
running
hopping
skipping
asymmetric running
```

At minimum capture:

- source file and branch column;
- 12-entry decision;
- 2 offsets;
- 15-entry residual;
- residual norm;
- raw time and state trajectory;
- event states;
- parameter/output vector;
- energy/output value when returned;
- gait classification;
- one source `fsolve` result;
- trajectory-fit objective components;
- nonlinear constraints;
- resampled simulated trajectories.

Store ordinary regression fixtures under:

```text
tests/fixtures/baselines/slip_biped/
```

Ordinary tests must not access the source repository.

Measure and document tolerances rather than choosing them arbitrarily.

---

## 5. Copy and catalog the biped gait branches

Copy the redistributable branch MAT assets required for the built-in gait map
from the source `Section2_solution_examples` area into:

```text
examples/data/slip_biped/GaitMap/
```

Preserve source filenames.

Create:

```text
examples/data/slip_biped/GaitMap/gaitmap_manifest.json
examples/data/slip_biped/GaitMap/README.md
examples/data/slip_biped/GaitMap/native/
```

The manifest records:

```text
schemaVersion
datasetId = slip_biped_gaitmap
modelId = slip_biped
problemId = periodic_apex
sourceRepository
sourceCommit
sourcePath
files[]
```

For every MAT file record:

```text
name
sha256
rowCount
pointCount
gait label
source variable
recommended default index
native artifact path
```

Validate all files and generate native branch artifacts.

Do not require the source repository at runtime.

---

## 6. Exact biped schemas and layout

Implement under:

```text
models/+lmzmodels/+slip_biped/
```

Required files/classes:

```text
PeriodicDecisionSchema
OffsetParameterSchema
PhysicalStateSchema
Results14Layout
Results14Adapter
LegacyBipedEvaluator
PeriodicApexProblem
TrajectoryFitProblem
GaitClassifier
KinematicsProvider
ObservableProvider
FeasibilityPolicy
ContinuationPolicy
BipedRenderer
BipedPlotProvider
GaitMapCatalog
```

### 6.1 Periodic decision schema: 12 entries

Use exact source ordering:

```text
dx
y
dy
alphaL
dalphaL
alphaR
dalphaR
tL_TD
tL_LO
tR_TD
tR_LO
tAPEX
```

The first four event times are cyclic with `tAPEX` as period source.

### 6.2 Parameter schema

The legacy branch stores:

```text
offsetL
offsetR
```

as rows 13 and 14.

Expose them as named problem parameters:

```text
offset_left
offset_right
```

The source model also fixes:

```text
k_leg = 20
omega_swing = 6.5
```

Represent those fixed values in versioned model/problem configuration and
diagnostics. Do not silently promote them to free decision variables.

### 6.3 Physical state schema: 8 entries

Use exact integrated state ordering:

```text
x
dx
y
dy
alphaL
dalphaL
alphaR
dalphaR
```

---

## 7. Preserve the source biped residual contract

The compatibility evaluator must preserve the source behavior.

The source residual has 15 entries. Preserve and name the blocks, including
the structurally unused/reserved entry if it remains zero in source behavior.

Suggested named grouping:

```text
periodicity
left_touchdown_ground
right_touchdown_ground
left_liftoff_ground
right_liftoff_ground
legacy_reserved_zero
symmetry_left_touchdown_right_liftoff
symmetry_right_touchdown_left_liftoff
apex_vertical_velocity
```

Do not delete a residual merely to make the system square.

Support overdetermined `fsolve` through the existing generic solver.

`PeriodicApexProblem.evaluate` must be deterministic and return:

```text
ProblemEvaluation
SimulationResult
EventRecord array
classification
diagnostics
```

No hidden timing solve is allowed inside ordinary residual evaluation.

---

## 8. Biped branch, simulation, solve, continuation, and GUI

`Results14Adapter` must return `lmz.data.SolutionBranch`, preserving:

```text
12 decisions
2 offsets
source file
source column
source hash
gait
residual/evaluation metadata
provenance
```

Exact unchanged 14-row export must pass.

The built-in GaitMap becomes the default `slip_biped/periodic_apex` dataset.

Required GUI behavior:

### Branch

- load one/all biped gait branches;
- named X/Y/Z coordinates;
- gait-based styling;
- hover/click selection;
- source index navigation.

### Solution

- initial-state and event tables;
- offset parameter table;
- residual blocks;
- gait;
- provenance;
- editable working copy.

### Simulation

- body point mass;
- left and right legs/feet;
- ground and contact states;
- normalized-time animation;
- state/leg trajectories;
- footfall/event phase plot;
- energy/output panel.

### Solve

- branch point/edit/solved seed sources;
- explicit cyclic timing wrap;
- reproducible noise;
- overdetermined `fsolve`;
- result comparison and save.

### Continuation

- adjacent branch pair;
- generated second seed;
- bidirectional scientific continuation;
- live overlay;
- checkpoint/pause/resume/stop;
- branch save/export.

### Trajectory fit

- experimental/observed data selector;
- objective-term table;
- bounds and solver settings;
- fit;
- initial/optimized trajectory comparison;
- objective contributions;
- native artifact save.

---

## 9. Source-equivalent biped trajectory fitting

Replace the two-variable target-value demonstration with the migrated
trajectory-fit formulation.

The fit must use source-equivalent:

```text
simulation/optimization evaluator
resampling policy
position trajectory mismatch
height trajectory mismatch
left leg-angle mismatch
right leg-angle mismatch
periodic/physical nonlinear constraints
bounds
```

Preserve source defaults where valid, but expose weights and normalization
explicitly.

Record each objective contribution and constraint residual.

Add a short regression optimization that:

- starts from a stored source seed;
- evaluates source-equivalent initial terms;
- decreases the composite objective;
- preserves constraints within documented tolerance;
- produces a simulation and native optimization artifact.

---

# PART B — Scientific `slip_quad_load`

## 10. Capture load-pulling baselines

Create:

```text
tools/maintainers/capture_slip_quad_load_source_baselines.m
tools/maintainers/import_slip_quad_load_datasets.m
tools/maintainers/verify_slip_quad_load_datasets.m
```

Inspect and migrate the complete transitive runtime of:

```text
Section2_Single_Stride_Replication/Section2_Single_Stride_Replication.m
Section3_Gait_Transition_Replication/Section3_Gait_Transition_Replication.m
Stored_Functions/Dynamics/Quad_Load_ZeroFun_Transition_v2.m
Stored_Functions/SimulateQuadLoadStrides.m
Stored_Functions/fms_NStridesObjectiveFcn_Quad_Load_v2.m
Stored_Functions/EventTimingRegulation.m
all generated dynamics helpers
all resampling helpers
all objective/metric helpers
required files under Stored_Functions/Graphics
```

Capture representative baselines for:

```text
single periodic stride
multi-stride sequence
gait transition dataset
```

At minimum capture:

- source `X_accum`;
- supporting experimental structures;
- term weights;
- sensitivity data when present;
- decoded first-stride fields;
- decoded later-stride fields;
- residual;
- time;
- quadruped and load states;
- event states;
- 12-channel GRFs when available;
- leash/tugline force;
- parameter matrix;
- stride count;
- stride-duration mismatch;
- footfall-timing mismatch;
- loading-force mismatch;
- composite objective;
- all R-squared values.

Store ordinary fixtures under:

```text
tests/fixtures/baselines/slip_quad_load/
```

---

## 11. Copy and catalog built-in load datasets

Copy a minimal, representative, redistributable subset of source datasets
sufficient for:

```text
single-stride replication
multi-stride fitting
gait-transition visualization
```

Place them under:

```text
examples/data/slip_quad_load/Scientific/
```

Create:

```text
examples/data/slip_quad_load/Scientific/dataset_manifest.json
examples/data/slip_quad_load/Scientific/README.md
examples/data/slip_quad_load/Scientific/native/
```

Record hashes, source paths, fields, stride counts, and native artifact paths.

The GUI must load a built-in scientific dataset without asking the user for
the source repository.

---

## 12. Exact load-pulling layouts

Implement under:

```text
models/+lmzmodels/+slip_quad_load/
```

Required classes/files:

```text
FirstStrideLayout
LaterStrideLayout
MultiStrideDecisionSchema
QuadrupedStateSchema
LoadStateSchema
QuadrupedParameterSchema
LoadParameterSchema
XAccumAdapter
LegacyQuadLoadEvaluator
SingleStrideProblem
MultiStrideFitProblem
MultiStrideSimulator
KinematicsProvider
ObservableProvider
QuadLoadRenderer
QuadLoadPlotProvider
ObjectiveTerms/
ScientificDatasetCatalog
```

### 12.1 First-stride vector

Resolve and document the 44-entry source contract exactly:

```text
X_quad        13
E_quad         9
Para_quad     14
X_load         2
Para_load      6
total         44
```

Use stable names for every entry.

### 12.2 Later-stride additions

Resolve and document the 13-entry per-later-stride contract exactly from the
source transition code.

Do not leave it as an unnamed `extra13` block.

The total decision dimension is:

\[
44 + 13(N-1).
\]

One centralized layout implementation must be used by:

```text
adapter
simulator
objective
GUI editor
artifact serializer
tests
```

Do not duplicate packing logic.

### 12.3 State and outputs

Public simulation must expose named:

```text
quadruped state
load state
contact modes
event records
GRF
tugline force
stride boundaries
per-stride parameters
diagnostics
```

---

## 13. Source-equivalent load objective

Replace the current three-variable target-value demonstration.

Implement objective terms:

```text
StrideDurationMismatch
FootfallTimingMismatch
LoadingForceMismatch
CompositeObjective
R2Metrics
```

Each term owns:

```text
name
weight
normalization
resampling policy
source/target data
value
diagnostics
```

Preserve source resampling behavior and document any corrections required for
edge cases.

The source R-squared calculations must be reproduced and tested, including
zero-variance safeguards.

A short scientific optimization must:

- load a repository-contained source dataset;
- decode `X_accum`;
- evaluate all initial terms;
- run through generic `OptimizationService`;
- reduce the objective;
- report term contributions and constraints;
- simulate the optimized result;
- save a native optimization artifact.

---

## 14. Load-pulling GUI workflow

For `slip_quad_load`, implement model-specific analysis plugins integrated
through generic GUI/service boundaries.

Required views:

### Dataset and Solution

- dataset metadata;
- stride count;
- packed-layout table grouped by first/later stride;
- quadruped/load parameters;
- term weights;
- provenance.

### Simulation

- quadruped torso and four legs;
- load/sled;
- rope/tugline;
- ground;
- contact states;
- force vectors;
- normalized multi-stride timeline.

### Analysis plots

- footfall sequence;
- body and leg trajectories;
- load trajectory;
- GRFs;
- tugline force;
- observed-versus-simulated traces;
- sensitivity plots when the dataset contains sensitivity data;
- R-squared summary.

### Optimization

- initial seed/source;
- editable term weights;
- bounds/settings;
- progress/cancel;
- objective history;
- term contributions;
- initial-versus-optimized comparison;
- simulation of optimized result;
- artifact export.

---

# PART C — Cross-cutting release hardening

## 15. Per-problem maturity and capability metadata

Upgrade problem descriptors and registry validation.

Each problem descriptor must contain:

```json
{
  "maturity": "tutorial|compatibility|validated|experimental",
  "validationStatus": "untested|tested|source-equivalent",
  "capabilities": {
    "simulate": true,
    "solve": false,
    "continue": false,
    "optimize": false,
    "visualize": true,
    "animate": true
  }
}
```

Model capability summaries are derived from problem descriptors rather than
manually duplicating ambiguous booleans.

The GUI problem selector must display badges/labels such as:

```text
Tutorial
Validated
Source-equivalent
Experimental
```

README tables must separate model availability from problem maturity.

Do not present tutorial solve/fit tasks as scientific migrations.

---

## 16. Quadruped RoadMap hardening

Preserve all existing behavior and add the missing edge-case tests.

### 16.1 Active parameter metadata

The quadruped `phi_neutral` parameter is unused by the migrated source
dynamics.

Mark every parameter as:

```text
active
inactive
derived
```

Do not use an inactive parameter as the default homotopy demonstration.

Run meaningful quadruped homotopy/family tests over an active parameter such
as:

```text
k_leg
k_swing
J_pitch
l_leg
l_b
k_r_leg
```

Choose targets close enough for a stable test and record the source branch and
seed.

The GUI must explain why inactive parameters are disabled for transport.

### 16.2 Forced continuation cases

Add deterministic tests for:

```text
corrector rejection and backtracking
minimum-step termination
curvature-threshold response
stagnation termination
history duplicate rejection
historical-segment loop closure
controlled stop during correction
resume after checkpoint
partial branch preservation
```

Use analytic problems where necessary; also include at least one scientific
quadruped controlled-stop/resume test.

### 16.3 Continuation diagnostics

Every accepted/rejected snapshot records:

```text
predictor
corrected decision
residual norm
step
curvature
corrector iterations
backtracking count
feasibility/gait result
termination candidate
checkpoint path
```

Expose these diagnostics in the GUI and artifacts.

---

## 17. GUI refactoring and manual desktop QA

The RoadMap GUI is functionally implemented but the main app class is large.
Refactor without changing behavior into reviewable components:

```text
src/+lmz/+gui/+tabs/RoadMapBranchTab.m
src/+lmz/+gui/+tabs/SolutionTab.m
src/+lmz/+gui/+tabs/SimulationTab.m
src/+lmz/+gui/+tabs/SolveTab.m
src/+lmz/+gui/+tabs/ContinuationTab.m
src/+lmz/+gui/+tabs/OptimizationTab.m
src/+lmz/+gui/+components/
```

Keep controller/service boundaries intact.

Perform a human MATLAB desktop walkthrough for all three models:

### Quadruped

- load all RoadMap branches;
- hover and lock;
- edit/restore solution;
- play/pause/stop;
- record/export;
- solve;
- adjacent/generated seeds;
- continuation pause/resume/stop/checkpoint;
- homotopy/family scan.

### Biped

- load gait map;
- select each gait;
- simulate/animate;
- solve;
- continue;
- fit an observed trajectory.

### Load

- load scientific dataset;
- simulate multi-stride motion;
- inspect footfall/tugline/R2 plots;
- run/cancel optimization;
- inspect/save result.

Record:

```text
MATLAB release
operating system
screen resolution
steps performed
observed problems
screenshots
```

Store screenshots under model-specific folders in:

```text
docs/screenshots/
```

Do not call automated batch screenshots manual evidence.

---

## 18. MATLAB compatibility

The project targets R2019b.

Search for and eliminate or guard APIs introduced after R2019b.

Create:

```text
tools/check_matlab_compatibility.m
tests/architecture/TestR2019bCompatibility.m
```

Check at minimum:

```text
language syntax
uifigure/uigridlayout usage
optimoptions names
datetime/string usage
exportgraphics
VideoWriter profiles
JSON functions
table APIs
recursive dir syntax
matlab.unittest options
```

If an R2019b installation exists, run the complete core suite and at least one
scientific workflow for each model.

If it does not exist:

- perform the static compatibility audit;
- document exactly what remains unexecuted;
- do not claim R2019b runtime verification.

---

## 19. Redistribution and release decision

The copied quadruped source repository has no explicit license.

Do not infer rights.

Create:

```text
docs/REDISTRIBUTION_STATUS.md
docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md
```

Record separately for:

```text
quadruped source code
quadruped RoadMap data
biped source code/data
load source code/data
```

For each, state:

```text
source owner
source repository
existing license/notice
user authorization recorded
public redistribution status
release action required
```

Do not remove scientifically necessary assets merely because review is
pending. Mark packaging/release as blocked until the owner supplies an
explicit decision.

Ensure `THIRD_PARTY_NOTICES.md` is complete.

---

## 20. Built-in examples

Create and execute:

```text
examples/demo_slip_biped_gaitmap_workflow.m
examples/demo_slip_biped_solve.m
examples/demo_slip_biped_continuation.m
examples/demo_slip_biped_trajectory_fit.m
examples/demo_slip_quad_load_single_stride.m
examples/demo_slip_quad_load_multi_stride.m
examples/demo_slip_quad_load_fit.m
examples/demo_all_scientific_models.m
examples/demo_full_desktop_workflow.m
```

Each example:

- uses public APIs only;
- uses repository-contained scientific data;
- is safe to rerun;
- returns structured outputs;
- never accesses sibling repositories;
- prints an exact success marker.

---

## 21. Required tests

Retain all existing tests and add at least:

### Biped data and equivalence

```text
TestBipedGaitMapManifest
TestBipedAllBranchesImport
TestResults14ExactRoundTrip
TestBipedPointMetadata
TestBipedResidualEquivalence
TestBipedTrajectoryEquivalence
TestBipedEventEquivalence
TestBipedGaitClassification
TestBipedSolve
TestBipedSecondSeed
TestBipedContinuation
TestBipedContinuationCheckpointResume
TestBipedTrajectoryFitTerms
TestBipedTrajectoryFitObjectiveDecrease
TestBipedGUIWorkflow
```

### Load data and equivalence

```text
TestQuadLoadDatasetManifest
TestXAccumFirstStrideLayout
TestXAccumLaterStrideLayout
TestXAccumRoundTrip
TestMultiStrideDecisionDimension
TestQuadLoadSingleStrideEquivalence
TestQuadLoadMultiStrideEquivalence
TestQuadLoadEventRecords
TestQuadLoadGRFEquivalence
TestQuadLoadTuglineForceEquivalence
TestStrideDurationTermEquivalence
TestFootfallTimingTermEquivalence
TestLoadingForceTermEquivalence
TestQuadLoadR2Equivalence
TestQuadLoadOptimizationObjectiveDecrease
TestQuadLoadGUIWorkflow
```

### Cross-cutting

```text
TestProblemMaturityMetadata
TestCapabilitiesDerivedFromProblems
TestArtifactProblemMaturity
TestInactiveParameterHomotopyRejection
TestActiveQuadrupedHomotopy
TestContinuationForcedRejection
TestContinuationMinimumStep
TestContinuationCurvatureController
TestContinuationStagnation
TestContinuationHistoricalLoopClosure
TestScientificCheckpointResume
TestR2019bCompatibility
TestStandaloneAllScientificModels
TestReadmeScientificModelContract
```

Numerical tests must use repository-contained baselines and measured
tolerances.

---

## 22. Standalone isolation test

Copy the repository to a temporary parent containing no research source
repositories.

In a clean MATLAB process:

1. run `startup`;
2. discover all three canonical models;
3. load quadruped RoadMap;
4. load biped gait map;
5. load load-pulling scientific dataset;
6. evaluate/simulate one scientific solution for each model;
7. solve and continue biped;
8. solve and continue quadruped;
9. run load multi-stride optimization;
10. construct the complete GUI;
11. save/reload branch, solution, continuation, and optimization artifacts.

Print an exact marker:

```text
ISOLATED_ALL_SCIENTIFIC_MODELS_OK
```

Ordinary runtime and tests must not inspect sibling repositories.

---

## 23. README and documentation

Update README after every coherent implementation gate.

The final README must include detailed tutorials:

```text
SLIP Quadruped RoadMap Tutorial
SLIP Biped GaitMap Tutorial
SLIP Quadruped-with-Load Fitting Tutorial
```

Document:

- scientific versus tutorial problems;
- problem maturity badges;
- built-in data;
- branch selection;
- simulation and animation;
- solve/continuation;
- fitting/optimization;
- save/export;
- requirements and toolboxes;
- exact tested MATLAB releases;
- redistribution status.

Update:

```text
MIGRATION_STATUS.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/architecture.md
docs/continuation.md
docs/data-format.md
docs/gui-design.md
docs/provenance.md
THIRD_PARTY_NOTICES.md
CHANGELOG.md
```

README capability/maturity tables must be generated and contract-tested.

---

## 24. Definition of done

Do not finish this round until all applicable conditions hold:

1. Existing quadruped RoadMap tests remain green.
2. `slip_biped/periodic_apex` is the source-equivalent 12-decision problem.
3. Results14 branches import to native `SolutionBranch` and exact export.
4. Biped source residual, trajectory, events, and gait regression tests pass.
5. Biped solve and scientific continuation execute.
6. Biped trajectory fitting uses source-equivalent objective/constraints.
7. `slip_quad_load` decodes the exact 44+13(N-1) scientific layout.
8. X_accum import/export and all named layout tests pass.
9. Load single/multi-stride simulation matches source baselines.
10. Load objective terms and R-squared values match source baselines.
11. Load optimization decreases the source-equivalent objective.
12. Both remaining models have physical visualization and GUI workflows.
13. Per-problem maturity and capabilities are accurate.
14. Quadruped homotopy uses an active parameter.
15. Forced continuation termination/control cases are tested.
16. A human desktop walkthrough is recorded or explicitly blocked by display
    availability.
17. R2019b execution is recorded, or the static compatibility audit and exact
    blocker are documented.
18. Standalone all-scientific-model isolation passes.
19. Full MATLAB suite and all public examples pass.
20. README and status documents match executed evidence.
21. Source repositories remain unchanged.
22. Redistribution status is explicitly documented.

Do not call a model scientific if its active problem is a target-value toy.
Do not call a capability validated if only a tutorial problem implements it.
Do not report desktop usability based only on batch screenshots.

---

## 25. Final report

Report:

1. target path and final Git status;
2. final HEAD;
3. source commits used;
4. scientific files/data copied and hashes;
5. biped branch names and total point counts;
6. load datasets and stride counts;
7. residual/trajectory/objective tolerances and results;
8. biped solve/continuation diagnostics;
9. load optimization diagnostics;
10. quadruped non-regression result;
11. continuation edge-case results;
12. manual desktop evidence;
13. R2019b status;
14. isolated all-model result;
15. exact test totals and example markers;
16. README contract result;
17. redistribution blocker/decision;
18. any remaining technical blocker.

Begin by capturing biped and load source baselines. Migrate and validate
`slip_biped` first, then `slip_quad_load`. Preserve the quadruped RoadMap at
every step. Finish with cross-model GUI, continuation, compatibility, desktop,
and isolation validation. Continue without asking for confirmation.
