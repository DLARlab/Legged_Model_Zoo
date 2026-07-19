# Codex Round 5 — Real SLIP Quadruped RoadMap, Visualization, and Continuation Workflow

You are the senior MATLAB numerical-software engineer completing the existing
`DLARlab/Legged_Model_Zoo` repository.

Work directly in the current local clone. Preserve valid Round 4 framework
code and tests, but replace the synthetic quadruped demonstration workflow with
a real, repository-contained scientific RoadMap workflow.

This round is deliberately focused. Do not spend the round creating more
abstract scaffolding or polishing unrelated models. Complete the
`slip_quadruped` RoadMap vertical slice first:

```text
RoadMap data
  -> native branches
  -> branch explorer
  -> selected solution
  -> physical simulation
  -> animation and trajectories
  -> solve/refine
  -> seed pair
  -> numerical continuation
  -> live/saveable branch result
```

The final application must demonstrate the same core user workflow as the
published SLIP quadruped GUI, while retaining the new framework's model,
problem, service, data, and presentation separation.

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
4cac5fe5e53b82875c6bbe486d1a0ddedaa95ec3
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
```

Inspect the current implementations of:

```text
lmz.data.Solution
lmz.data.SolutionBranch
lmz.services.BranchService
lmz.services.SolutionService
lmz.services.SolveService
lmz.services.SeedService
lmz.services.ContinuationService
lmz.continuation.PseudoArclengthContinuation
lmz.gui.AppState
lmz.gui.AppController
lmz.gui.LeggedModelZooApp
lmzmodels.slip_quadruped.Model
lmzmodels.slip_quadruped.PeriodicApexProblem
lmzmodels.slip_quadruped.Results29Adapter
```

The observed Round 4 implementation has real generic solver/continuation
plumbing, but the active quadruped workflow is not the research model:

- the built-in branch is generated from seven speeds;
- the current periodic problem has only `speed` and `stride_period`;
- its residual is the demonstration relation `speed*stride_period -
  stride_length`;
- `Results29Adapter` returns a raw legacy struct rather than a native branch;
- the GUI branch plot uses only the first two decision variables;
- there is no published quadruped dynamics evaluator;
- there is no RoadMap dataset in the repository;
- selected branch points do not drive real quadruped animation, leg
  trajectories, GRFs, oscillator plots, or scientific continuation;
- file-backed checkpoint resume, complete pause/resume control, loop
  detection, curvature control, and recording remain incomplete.

Do not report this round complete while any of those statements remains true.

---

## 2. Immutable migration source and standalone target

Locate the local repository:

```text
SLIP_Model_Zoo
```

Verify that its Git origin is:

```text
https://github.com/DLARlab/SLIP_Model_Zoo.git
```

Record its current commit SHA. Treat it as immutable:

- do not edit it;
- do not commit inside it;
- do not reformat it;
- verify its working tree is unchanged at the end.

Use these source locations:

```text
SLIP_Model_Zoo/
  SLIP_Quadruped/
    P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/
      1_Roadmap/
    1_Dynamic_Frameworks/v2/
    2_Graphic_ToolBox/SLIP_Quadrupedal_Graphics/
    3_Numerical_Continuation/1_Continuation_Algorithm/
    4_Solution_Management/
    SLIP_Quadruped_GUI.m
    README.md
```

The source directory name contains the historical spelling
`Qudrupedal`; preserve it only in provenance, not in new public APIs.

The user has authorized copying the RoadMap assets into the new standalone
project. Preserve source filenames and record hashes and provenance.

After this migration, normal usage must require only `Legged_Model_Zoo`.
Runtime code must not search for or add `SLIP_Model_Zoo` to the MATLAB path.

If a separately named `SLIP_Model_ZooGUI` repository is locally available,
inspect it as an additional behavioral reference. If it is not available, use
`SLIP_Quadruped_GUI.m` and its README as the authoritative GUI behavior
reference. Do not block implementation on the separate URL.

---

## 3. Copy and catalog the complete RoadMap

Copy the complete source folder:

```text
SLIP_Quadruped/
  P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/
    1_Roadmap/
```

into:

```text
examples/data/slip_quadruped/RoadMap/
```

Preserve all source `.mat` and `.fig` filenames. The `.mat` files are runtime
scientific branch data. The `.fig` files are visual references only and must
not be required at runtime.

Do not copy `.DS_Store`.

Create:

```text
examples/data/slip_quadruped/RoadMap/roadmap_manifest.json
examples/data/slip_quadruped/RoadMap/README.md
tools/maintainers/import_slip_quadruped_roadmap.m
tools/maintainers/verify_slip_quadruped_roadmap.m
```

### 3.1 RoadMap manifest

The manifest must record:

```text
schemaVersion
datasetId = slip_quadruped_roadmap
modelId = slip_quadruped
problemId = periodic_apex
sourceRepository
sourceCommit
sourcePath
copiedAt
license/redistribution statement
files[]
```

For each file record:

```text
name
relativePath
sha256
kind                 % legacy-results-branch or reference-figure
pointCount
rowCount
legacyVariable
parameterSummary
inferredGaitSummary
nativeArtifactPath
```

Do not hard-code the file list in runtime code. Generate and validate it.

### 3.2 Data validation

For every `.mat` branch:

- require a numeric variable named `results`;
- require exactly 29 rows;
- require at least two columns;
- require finite numeric values;
- validate the nine event-time entries and positive period;
- validate the seven parameter entries;
- retain original column order;
- compute the SHA-256 hash;
- classify representative points without modifying the source matrix.

At minimum, verify the copied `PK_20_2.mat` branch and its complete point
count. Fail loudly if the copied data differs from the recorded source hash.

### 3.3 Native artifacts

Generate native branch artifacts under:

```text
examples/data/slip_quadruped/RoadMap/native/
```

Do not delete or replace the source MAT files.

Runtime behavior:

- load native artifacts by default for speed and metadata;
- retain one-click reimport from the source MAT file;
- verify exact legacy round-trip export;
- detect stale native artifacts when the source hash changes.

---

## 4. Replace the synthetic quadruped problem with the scientific problem

Keep `demo_stride` only as an optional introductory example. It must not be
used for RoadMap branches, solve, or continuation.

Implement the actual research-model problem under:

```text
models/+lmzmodels/+slip_quadruped/
```

Required classes/functions:

```text
PeriodicDecisionSchema
ParameterSchema
PhysicalStateSchema
Results29Layout
Results29Adapter
LegacyQuadrupedEvaluator
PeriodicApexProblem
EventScheduleProjector
GaitClassifier
KinematicsProvider
ObservableProvider
FeasibilityPolicy
ContinuationPolicy
```

Migrate the minimum complete transitive runtime implementation of:

```text
Quadrupedal_ZeroFun_v2.m
EventTimingRegulation.m
Gait_Identification.m
Func_alphaB_VA_v2.m
Func_alphaF_VA_v2.m
required stance/swing helpers
GRF computation
required event and geometry helpers
```

Place copied/adapted code in a collision-safe namespace such as:

```text
models/+lmzmodels/+slip_quadruped/+legacy/
```

Preserve source headers. Record every copied file, source path, source commit,
and modification in:

```text
docs/provenance.md
THIRD_PARTY_NOTICES.md
```

Do not use the source repository at runtime.

---

## 5. Exact quadruped schemas

### 5.1 Periodic decision schema: 22 entries

Initial condition entries:

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

Event entries:

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

The first eight event times use cyclic-time topology with `tAPEX` as the
period source. `tAPEX` is positive.

Do not automatically wrap the continuous state/angle entries unless the
legacy equations and regression tests establish that behavior. Use
Euclidean local coordinates for those entries by default.

### 5.2 Parameter schema: 7 entries

```text
k_leg
k_swing
J_pitch
l_leg
phi_neutral
l_b
k_r_leg
```

Preserve the source ordering exactly inside `Results29Layout`.

### 5.3 Physical integrated state schema: 14 entries

Map the evaluator's integrated state explicitly:

```text
x
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

Do not conflate the 13-entry periodic initial condition with the 14-entry
integrated physical state.

---

## 6. Deterministic scientific evaluation

`PeriodicApexProblem.evaluate` must call the migrated compatibility evaluator
with hidden event-time repair disabled.

Conceptual public behavior:

```matlab
evaluation = problem.evaluate(decision, parameters, context, true);
```

It returns:

```text
ProblemEvaluation
  ResidualBlocks
  ScaledResidual
  UnscaledResidual
  ScaledResidualNorm
  Simulation
  Feasibility
  PhysicalValidity
  Diagnostics
```

`SimulationResult` must contain:

```text
Time
StateSchema
States
Contact/mode histories
EventRecord array
GRF magnitudes
GRF x/y components when available
Parameters
Observables
Diagnostics
Provenance
```

Required named observables include:

```text
forward_speed
stride_period
stride_length
duty_factors
event_phases
minimum_event_gap
gait_name
gait_abbreviation
vertical_grf
horizontal_grf
```

### 6.1 Explicit event schedule projection

Do not invoke an inner timing solve during every residual evaluation.

Implement:

```text
EventScheduleProjector.project(solution, options, context)
```

It returns a new candidate plus projection diagnostics. It is invoked
explicitly by the Solve/Seed workflow.

The residual function remains deterministic.

### 6.2 Baseline and equivalence

Use several RoadMap points to compare the migrated evaluator against the
source repository:

- residual vector;
- time;
- trajectory;
- event states;
- GRFs;
- gait classification.

Capture baselines once using isolated maintainer scripts, then run ordinary
regression tests from repository-contained baselines only.

Document measured absolute and relative tolerances.

---

## 7. Convert Results29 directly to native SolutionBranch

Upgrade:

```text
lmzmodels.slip_quadruped.Results29Adapter
```

Required APIs:

```matlab
branch = adapter.loadBranch(path, problem);
branch = adapter.decode(results, problem, provenance);
results = adapter.encode(branch);
artifact = adapter.toNativeArtifact(path, problem);
```

The returned object must be `lmz.data.SolutionBranch`, not a raw struct.

Each point must preserve:

```text
22 decision values
7 parameter values
source file
source column index
source hash
gait classification
residual norm when evaluated
observables when evaluated
```

Exact legacy export must reconstruct the 29-row matrix without numerical
change unless the user explicitly exports an edited/continued branch.

`SolutionBranch.point(index)` must return a complete `Solution`, including
stored point classification and metadata rather than discarding them.

Fix current branch contracts where necessary:

- preserve observables per point;
- preserve classifications per point;
- preserve residual/feasibility metadata;
- use chart-aware arclength;
- use chart-aware nearest-point distance;
- validate parameter compatibility;
- support concatenation and provenance lineage.

---

## 8. RoadMapCatalog and BranchService

Implement:

```text
lmzmodels.slip_quadruped.RoadMapCatalog
lmz.services.BranchService
```

Required RoadMap operations:

```text
listRoadMapBranches
loadRoadMapBranch
loadAllRoadMapBranches
reloadLegacySource
filterByFixedParameters
identifyVaryingParameter
selectActiveDataset
```

Remove the current synthetic seven-speed built-in branch for the scientific
RoadMap workflow.

The RoadMap is the default `slip_quadruped/periodic_apex` dataset in the GUI.

Support multiple simultaneous branch datasets with:

```text
name
source filename
visible
active
display color/style
point count
parameter summary
gait summary
read-only/source status
```

---

## 9. Full Branch tab for the RoadMap

Replace the current three-button Branch tab with a functional branch explorer.

### 9.1 Data controls

Provide:

```text
Built-in RoadMap selector
Open folder
Open MAT/artifact
Plot selected
Plot all
Remove selected
Clear plot
Reload
Save native artifact
Export legacy MAT
```

The built-in RoadMap must work without file browsing.

### 9.2 Axis controls

Named coordinate choices must include:

- all 13 initial-state entries;
- all 9 event entries;
- all 7 parameters;
- available observables.

Provide:

```text
X selector
Y selector
optional Z selector
2-D/3-D view
azimuth/elevation
axis limits
aspect ratio
RoadMap view preset
```

Inspect the source GUI and source `.fig` files to reproduce sensible default
RoadMap axes and view. Do not guess silently; document the selected default.

### 9.3 Dataset presentation

Provide:

```text
dataset list
visibility
active dataset
color/style
point count
parameter signature
gait label
```

Use gait classification for consistent default branch styling.

### 9.4 Hover and click

Implement:

- pointer hover preview;
- nearest-point resolution in displayed scaled coordinates;
- data tip with dataset, index, coordinates, parameters, gait, and residual;
- click to lock a point;
- selected-point marker;
- keyboard or index navigation;
- percentage-of-branch navigation.

Hover must not alter the locked selection.

The locked `Selection` object synchronizes:

```text
Branch
Solution
Simulation
Solve
Continuation
Oscillator
```

---

## 10. Full Solution inspector

For the selected RoadMap point, show separate schema-generated tables:

```text
Initial State
Event Timing
Parameters
Observables
Residual Blocks
Diagnostics
Provenance
```

Tables include:

```text
name
label
value
unit
bounds
scale
edited status
```

Support:

```text
working-copy editing
validate
restore selected point
simulate candidate
project event schedule
save solution
add candidate to a dataset
send candidate to Solve
send candidate to Continuation
```

Never mutate the source RoadMap branch.

---

## 11. Physical visualization, animation, and trajectories

A selected RoadMap point must drive the actual migrated quadruped evaluator,
not `demo_stride`.

Implement a quadruped visualization plugin using named state/kinematic data.

Required views:

### 11.1 Animation

Draw:

```text
body/torso
center of mass
back and front attachment points
four legs
four feet
ground
current contact states
optional force vectors
phase/event indicator
```

Controls:

```text
normalized stride slider
numeric normalized time
play
pause
stop
speed/FPS
loop
reset
```

### 11.2 Trajectories

Plot:

```text
torso: dx, y, dy, phi, dphi
back legs: alphaBL, dalphaBL, alphaBR, dalphaBR
front legs: alphaFL, dalphaFL, alphaFR, dalphaFR
GRF magnitude and components
```

Provide complete/static and frame-progressive modes.

### 11.3 Oscillator/phase plot

Plot touchdown and liftoff phases for all four legs. Synchronize the branch
point index with every other tab.

### 11.4 Recording/export

Implement:

```text
GIF
MP4 when supported
animation keyframes PDF/PNG
trajectory/GRF figure export
oscillator GIF
```

Recording must not corrupt direct time controls or leave files open after
cancel/close.

Use `AnimationController` and recorder services; do not place recording loops
inside generic model code.

---

## 12. RoadMap point as solve and continuation candidate

The selected RoadMap point is a first-class seed source.

### 12.1 Seed source choices

Support:

```text
Locked branch point
Branch index
Branch percentage
Edited Solution candidate
Last solved solution
Adjacent RoadMap pair
```

### 12.2 Solve workflow

For a selected point:

1. evaluate and display its current residual;
2. optionally project event timing;
3. optionally add reproducible noise;
4. solve with generic `SolveService`;
5. display residual, exit flag, iterations, and gait;
6. compare original and solved solution;
7. simulate solved solution;
8. save or add it to a dataset.

A RoadMap point that already satisfies tolerance remains valid as a solved
seed; do not perturb it unnecessarily.

### 12.3 Direct adjacent seed pair

Allow continuation to use two adjacent points from the same RoadMap branch:

```text
selected index and next
selected index and previous
manual index pair
```

Validate:

- same branch;
- distinct columns;
- compatible parameter vectors;
- finite values;
- acceptable residuals;
- compatible gait/topology policy;
- chart-aware separation.

At an endpoint, choose the inward neighbor or report a clear error.

### 12.4 Generated second seed

Allow:

```text
first seed = selected RoadMap or solved solution
second seed = SecondSeedSolver at requested radius
```

Report achieved chart/metric radius and residual.

### 12.5 Seed-pair visualization

Overlay first seed, second seed, and predictor direction on the RoadMap
coordinates and provide a simulation comparison.

---

## 13. Scientific continuation from RoadMap seeds

Run the generic continuation engine against the 22-variable scientific
`PeriodicApexProblem`.

Required improvements to the current engine:

```text
chart-aware timing lift across branch history
problem-provided scaling
accepted and rejected callbacks
adaptive numerical step
curvature controller
backtracking
duplicate detection against history
stagnation detection
historical segment loop closure
feasibility/gait policy
pause/resume
controlled stop
cancellation
file-backed atomic checkpoint
checkpoint resume
partial branch preservation
explicit termination reason
```

Do not hard-code:

```text
quadruped indices
gait names
speed thresholds
RoadMap filenames
plot handles
GUI prompts
```

### 13.1 Live RoadMap overlay

During continuation:

- show predicted point separately;
- append accepted points live;
- show current residual, step size, direction, and gait;
- permit pause/resume/stop;
- retain accepted points after controlled stop;
- optionally compare the new branch with the source RoadMap branch.

### 13.2 Parameter homotopy and branch family

Use named parameters from the seven-parameter schema.

Parameter homotopy transports a selected seed or seed pair.

Branch-family scan repeats one-dimensional continuation at target parameter
values and reports:

```text
completed
skipped
failed
blocked
output artifact
source lineage
```

Do not call this two-dimensional continuation.

---

## 14. GUI application state and controller

Expand state to include:

```text
RoadMapCatalog
Datasets
ActiveDatasetId
HoverSelection
LockedSelection
WorkingSolution
CandidateSimulation
SolvedSolution
SeedPair
ContinuationPreview
ContinuationResult
OscillatorIndex
CurrentRun
RecordingState
StatusMessages
```

Expand controller APIs:

```text
loadRoadMap
loadAllRoadMapBranches
plotDataset
setActiveDataset
setAxisVariables
hoverNearestPoint
lockBranchPoint
selectByIndex
selectByPercentage
workingSolution
editWorkingValue
restoreWorkingSolution
evaluateWorkingSolution
simulateWorkingSolution
projectWorkingSolution
solveWorkingSolution
makeAdjacentSeedPair
makeSecondSeed
runContinuation
pauseCurrentRun
resumeCurrentRun
stopCurrentRun
resumeCheckpoint
runParameterHomotopy
runBranchFamilyScan
saveBranch
exportLegacyBranch
recordAnimation
```

The GUI invokes services only. It must not call `fsolve`, the legacy
evaluator, or the continuation engine directly.

---

## 15. Required command-line example

Create:

```text
examples/demo_slip_quadruped_roadmap_workflow.m
```

It must execute this complete public workflow:

```matlab
startup;

registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quadruped');
problem = model.createProblem('periodic_apex', struct());

roadmap = lmzmodels.slip_quadruped.RoadMapCatalog.default();
files = roadmap.listBranches();

branch = lmz.services.BranchService().loadRoadMapBranch( ...
    problem, files{1});

index = roadmap.recommendedSeedIndex(files{1});
seed = branch.point(index);

evaluation = problem.evaluate( ...
    seed.DecisionValues, ...
    seed.ParameterValues, ...
    lmz.api.RunContext.synchronous(100), ...
    true);

simulation = evaluation.Simulation;

solveResult = lmz.services.SolveService().solve( ...
    problem, seed, struct(), ...
    lmz.api.RunContext.synchronous(101));

seedPair = lmz.services.SeedService().adjacentBranchPair( ...
    problem, branch, index, +1, struct());

continuationResult = lmz.services.ContinuationService().run( ...
    problem, seedPair, ...
    struct('MaximumPoints', 20, 'BothDirections', true), ...
    lmz.api.RunContext.synchronous(102));

lmz.io.ArtifactStore.save( ...
    'roadmap_continuation.lmz.mat', ...
    continuationResult.Branch.toArtifact());
```

The example also creates:

```text
branch plot
animation/selected-frame figure
trajectory figure
GRF figure
oscillator figure
continuation overlay
```

It must use only repository-contained data and public APIs.

---

## 16. Tests

Use `matlab.unittest`.

Add at least:

```text
TestRoadMapManifest
TestRoadMapSourceHashes
TestRoadMapAllBranchesImport
TestRoadMapPKPointCount
TestResults29NativeBranchConversion
TestResults29ExactRoundTrip
TestRoadMapPointMetadata
TestRoadMapGaitClassification
TestQuadrupedScientificResidualEquivalence
TestQuadrupedScientificSimulationEquivalence
TestQuadrupedGRFEquivalence
TestQuadrupedEventRecords
TestRoadMapSelectionSynchronization
TestRoadMapHoverDoesNotLock
TestRoadMapClickSelection
TestRoadMapAxisCoordinates
TestRoadMapMultipleDatasets
TestSelectedPointSimulation
TestQuadrupedAnimationFrames
TestQuadrupedTrajectoryPlots
TestQuadrupedOscillatorPlot
TestRoadMapSeedSolve
TestAdjacentRoadMapSeedPair
TestGeneratedSecondSeedFromRoadMap
TestScientificQuadrupedContinuation
TestContinuationLiveCallbacks
TestContinuationPauseResumeStop
TestContinuationCheckpointResume
TestContinuationLoopClosurePolicy
TestQuadrupedParameterHomotopy
TestQuadrupedBranchFamilyScan
TestRoadMapGUIConstruction
TestRoadMapControllerWorkflow
TestRoadMapRecordingSmoke
TestStandaloneRoadMapWorkflow
TestReadmeRoadMapContract
```

### 16.1 Numerical regression

Use repository-contained baseline files. Compare:

- residuals directly;
- event states separately;
- trajectories on a common time grid;
- GRF values/components;
- gait classification.

Document measured tolerances.

### 16.2 Standalone isolation

Copy `Legged_Model_Zoo` to a temporary parent containing no source
repositories. In a clean MATLAB process:

1. run `startup`;
2. discover `slip_quadruped`;
3. load all built-in RoadMap branches;
4. select a point;
5. evaluate/simulate it;
6. construct the GUI;
7. run animation frame updates;
8. solve a selected point;
9. create an adjacent seed pair;
10. run a short continuation;
11. save/load the result artifact.

Record an exact success marker.

### 16.3 Manual desktop test

Run MATLAB with desktop graphics and record evidence for:

- launch GUI;
- load/plot all RoadMap branches;
- hover a branch;
- click and lock a point;
- inspect Solution;
- play and stop animation;
- inspect trajectories and GRFs;
- view oscillator plot;
- solve selected point;
- create/plot seed pair;
- start, pause, resume, and stop continuation;
- export plot and GIF/MP4 where supported;
- close cleanly.

Save screenshots under:

```text
docs/screenshots/
```

At minimum:

```text
roadmap_branch_explorer.png
roadmap_selected_solution.png
roadmap_animation.png
roadmap_trajectories_grf.png
roadmap_continuation_overlay.png
```

---

## 17. README and documentation

Update README immediately after each coherent gate.

The final README must contain a dedicated section:

```text
SLIP Quadruped RoadMap Tutorial
```

Document:

1. launching the GUI;
2. loading the built-in RoadMap;
3. plotting one/all branches;
4. choosing X/Y/Z axes;
5. hovering and locking a point;
6. viewing solution metadata;
7. running animation;
8. viewing trajectories, GRFs, and oscillator plots;
9. using the point as a solve seed;
10. using an adjacent branch pair;
11. generating a second seed;
12. running continuation;
13. pause/resume/stop/checkpoint;
14. saving native and legacy results.

Update:

```text
MIGRATION_STATUS.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/gui-design.md
docs/continuation.md
docs/data-format.md
docs/provenance.md
THIRD_PARTY_NOTICES.md
CHANGELOG.md
```

The capability table may advertise scientific quadruped solve/continuation
only after the RoadMap/evaluator tests pass.

Do not say that the RoadMap is a numerical solution manifold if the runtime
still plots a generated two-variable demonstration branch.

---

## 18. Static checks

Extend static validation to reject:

```text
synthetic seven-speed branch as RoadMap
speed*stride_period residual in slip_quadruped/periodic_apex
raw Results29 struct returned by the public adapter
runtime references to the source repository
direct legacy evaluator calls from GUI
direct optimizer calls from GUI
hard-coded RoadMap filename lists in generic services
model-specific indices in generic packages
unclosed recording resources
placeholder branch/animation/trajectory controls
```

Allow raw 29-row indexing only in:

```text
Results29Layout
Results29Adapter
legacy compatibility evaluator
```

---

## 19. Definition of done

Do not finish this round until all applicable conditions hold:

1. The complete source RoadMap folder is repository-contained with hashes and
   provenance.
2. Every RoadMap MAT branch imports to `SolutionBranch`.
3. Exact legacy 29-row round-trip passes.
4. `slip_quadruped/periodic_apex` is the migrated 22-decision, 7-parameter
   scientific problem.
5. Selected RoadMap points evaluate and simulate through the migrated model.
6. The Branch tab plots multiple RoadMap branches with named axes, hover, and
   click selection.
7. Selection synchronizes Solution, Simulation, Solve, Continuation, and
   Oscillator views.
8. Animation uses the physical quadruped states.
9. Torso, leg, GRF, and oscillator plots work.
10. A selected RoadMap point can be refined by the solver.
11. An adjacent RoadMap pair can seed continuation directly.
12. A solved point can generate a second seed at a requested radius.
13. Scientific pseudo-arclength continuation runs with live updates and
    saveable output.
14. Pause/resume/stop and checkpoint resume are executable.
15. Parameter homotopy and branch-family scan use named quadruped parameters.
16. GIF/MP4/keyframe and plot exports work where supported.
17. The command-line RoadMap workflow example passes.
18. The standalone isolation RoadMap workflow passes.
19. The full MATLAB test suite passes.
20. Manual desktop GUI evidence is recorded.
21. The source repository remains unchanged.
22. README accurately documents the workflow.

If redistribution or license review blocks committing an individual asset,
do not substitute synthetic data. Record the exact blocker and, with the
user's authorization, resolve the notice/provenance requirement before
continuing.

---

## 20. Final report

Report:

1. target path and final Git status;
2. final HEAD;
3. copied RoadMap files and hashes;
4. scientific evaluator files migrated;
5. exact RoadMap branch/point counts;
6. selected default branch and default seed index;
7. numerical regression tolerances and results;
8. branch/animation/trajectory/GRF/oscillator GUI workflows exercised;
9. solve and continuation diagnostics;
10. pause/resume/checkpoint evidence;
11. exported screenshots/recordings;
12. exact test totals;
13. standalone isolation result;
14. README contract result;
15. any remaining blocker.

Do not report “RoadMap integrated” if only one MAT file is copied, “animation”
if only a static marker is shown, “continuation” if it runs the two-variable
demonstration problem, or “GUI parity” if hover/click/seed synchronization is
missing.

Begin by copying and cataloging the complete RoadMap, then implement native
Results29 conversion and the scientific evaluator. Next connect the selected
RoadMap point to simulation/animation/trajectories. Finally connect it to
solve and continuation and complete the GUI workflow. Continue without asking
for confirmation.
