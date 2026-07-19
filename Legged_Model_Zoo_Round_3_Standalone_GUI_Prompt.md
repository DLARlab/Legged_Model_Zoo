# Codex Round 3 — Standalone Models and Usable GUI Release

You are the senior MATLAB implementation engineer completing the existing
`DLARlab/Legged_Model_Zoo` project.

This is not a new-project or architecture-planning task. Work in the existing
local clone, preserve valid code, implement the missing runtime functionality,
run every available test, and leave a usable standalone release.

Do not stop after inventory, descriptors, schemas, test skeletons, migration
notes, or disabled capability flags.

---

## 1. Current repository state

Begin by reading:

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

Inspect the actual local HEAD and working tree:

```bash
git status --short
git rev-parse HEAD
git log --oneline --decorate -10
```

The public repository was last observed at:

```text
969b3485afedd0741e2334ab6af15ca6a110ec9f
```

The local checkout is authoritative when newer.

The observed public state has:

- a validated core scaffold;
- project paths, registry validation, schemas/charts, run controls, and
  artifact validation;
- a raw 29-row quadruped layout adapter;
- no migrated numerical evaluator for any model;
- no simulation, solving, continuation, optimization, visualization, or GUI;
- all three model capability sets disabled;
- MATLAB tests implemented but not executed;
- README instructions that still mention sibling source repositories for
  migration-fixture regeneration.

This round must replace that pre-MVP state with a standalone, usable release.

Do not discard user changes. Never run:

```text
git reset --hard
git clean -fd
git checkout -- .
force push
history rewriting
```

Do not push.

---

## 2. Non-negotiable release outcomes

The round is complete only when all four user-facing requirements below are
satisfied.

### Requirement 1 — A usable GUI exists

A user can launch the application from the repository root with:

```matlab
legged_model_zoo
```

or:

```matlab
startup;
app = lmz.gui.LeggedModelZooApp();
```

The GUI must be implemented, construct successfully, and expose working
model operations rather than disabled placeholder panels.

### Requirement 2 — The repository is standalone

Normal installation, examples, tests, GUI usage, simulation, solving,
continuation, optimization, visualization, and built-in demonstrations must
require only this repository plus documented MATLAB toolboxes.

The runtime must not require these repositories to exist:

```text
SLIP_Model_Zoo
2022_A_Template_Model_Explains_Jerboa_Gait_Transitions
2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights
```

Those repositories may be used once as immutable migration sources while
implementing this round. After migration:

- all required MATLAB model code is present inside `Legged_Model_Zoo`;
- all required built-in demonstration data is present inside
  `Legged_Model_Zoo`;
- no runtime code searches for sibling repositories;
- no runtime code adds a legacy repository to the MATLAB path;
- no normal test depends on a sibling repository;
- the README contains no sibling-repository installation layout;
- source repositories are mentioned only in provenance, licensing, and
  maintainer-only historical documentation.

A clean copy of `Legged_Model_Zoo` placed in an otherwise empty parent
directory must run its built-in model and GUI workflows.

### Requirement 3 — Canonical model names are exact

Rename the three models everywhere to these canonical IDs:

```text
slip_biped
slip_quadruped
slip_quad_load
```

Use these exact names for:

- manifest IDs;
- catalog directory names;
- MATLAB model package names;
- registry output;
- native artifact model IDs;
- GUI selector values;
- examples;
- tests;
- README headings and commands.

The target namespaces must be:

```text
lmzmodels.slip_biped
lmzmodels.slip_quadruped
lmzmodels.slip_quad_load
```

The target catalog directories must be:

```text
catalog/slip_biped
catalog/slip_quadruped
catalog/slip_quad_load
```

Human-readable labels may be:

```text
SLIP Biped
SLIP Quadruped
SLIP Quadruped with Load
```

but the canonical IDs must remain visible and exact.

Support these old identifiers only as deprecated import aliases:

```text
jerboa.biped.offset          -> slip_biped
slip.quadruped.planar.v2     -> slip_quadruped
slip.quadruped.load          -> slip_quad_load
```

Old aliases may be accepted when loading old manifests or artifacts, with a
clear deprecation diagnostic. New artifacts and all user-facing output must
use canonical IDs.

Do not leave duplicate active model packages or catalog entries under the old
names.

### Requirement 4 — README is detailed and continuously synchronized

`README.md` is a user manual and release contract, not a migration-status
placeholder.

After every coherent code modification or implementation gate:

1. immediately update the affected README sections;
2. update the model capability table;
3. update launch and usage examples;
4. update limitations and troubleshooting;
5. only then continue to the next code change.

Do not defer README work until the end.

Create:

```text
tools/update_readme_status.m
tools/check_readme_contract.m
tests/documentation/TestReadmeContract.m
```

Use machine-readable manifests and test-status data to keep the model table
and capability status synchronized. A generated section may use markers such
as:

```text
<!-- LMZ:MODEL_TABLE:BEGIN -->
<!-- LMZ:MODEL_TABLE:END -->
```

The final README must not claim an unexecuted test passed.

---

## 3. Implementation strategy for this round

Previous rounds blocked model migration behind unavailable numerical
baselines. Do not repeat that deadlock.

Use a compatibility-first strategy:

1. copy the minimum complete transitive legacy implementation into isolated
   model-specific namespaces;
2. preserve equations and behavior initially;
3. expose that implementation through the current model/problem contracts;
4. make the standalone workflows run;
5. add regression tests and measured baselines when MATLAB is available;
6. refactor equations only after equivalence is established.

A missing MATLAB executable may block execution evidence, but it must not
block copying, namespacing, wiring, GUI construction, examples, standalone
packaging, static validation, or test implementation.

Do not perform a broad native hybrid rewrite in this round unless all
standalone adapter workflows already work.

---

## 4. Source repositories during migration

Locate local immutable source repositories by Git remote and record their
commit SHAs. Do not clone or download replacements.

Treat them as read-only. At the end, verify:

```bash
git -C <source-repo> status --short
```

is unchanged for each.

Migrate required source into model-specific locations such as:

```text
models/+lmzmodels/+slip_biped/+legacy/
models/+lmzmodels/+slip_quadruped/+legacy/
models/+lmzmodels/+slip_quad_load/+legacy/
```

or another collision-safe structure.

Requirements:

- copy all transitive `.m` dependencies needed by built-in workflows;
- preserve source copyright and license headers;
- document every copied or adapted file in `THIRD_PARTY_NOTICES.md`;
- record source repository, source path, source commit, destination path, and
  modifications in `docs/provenance.md`;
- package or rename functions so the three models cannot collide;
- do not add the legacy source folders to the runtime path;
- do not use `genpath`;
- do not require users to regenerate code from source repositories.

If generated symbolic functions are required, include the generated `.m`
files in the standalone repository.

---

## 5. Repository naming migration

Perform the naming migration first with `git mv` where possible.

### 5.1 Catalogs

Rename:

```text
catalog/jerboa_biped       -> catalog/slip_biped
catalog/slip_quadruped     -> catalog/slip_quadruped
catalog/quadruped_load     -> catalog/slip_quad_load
```

The second line retains the folder spelling but must update the manifest ID.

### 5.2 MATLAB packages

Rename:

```text
models/+lmzmodels/+jerboabiped
    -> models/+lmzmodels/+slip_biped

models/+lmzmodels/+slipquadruped
    -> models/+lmzmodels/+slip_quadruped

models/+lmzmodels/+quadload
    -> models/+lmzmodels/+slip_quad_load
```

Update every class reference, manifest binding, test, example, artifact
builder, error ID, and documentation reference.

### 5.3 Registry aliases

Add a small explicit alias table to the registry or artifact migration layer.
It must:

- resolve old IDs to canonical IDs;
- emit a warning or diagnostic;
- never return an old ID from `listModels`;
- never save a new artifact with an old ID.

### 5.4 Naming tests

Add tests that verify:

```matlab
registry.listModels()
```

returns exactly these IDs, in a deterministic order:

```text
slip_biped
slip_quadruped
slip_quad_load
```

Also test old-ID alias resolution and canonical artifact output.

---

## 6. Standalone model 1: `slip_biped`

This model is the migrated biped/Jerboa SLIP model.

Implement under:

```text
models/+lmzmodels/+slip_biped/
catalog/slip_biped/
```

### 6.1 Required functionality

Implement:

```text
Model
PhysicalStateSchema
ParameterSchema
PeriodicDecisionSchema
PeriodicApexProblem
TrajectoryFitProblem
LegacyEvaluator
Results14Adapter
GaitClassifier
Kinematics
PlotDescriptors
scene.lmz.json
built-in examples
```

### 6.2 Legacy layout

Preserve the legacy branch contract:

```text
12 periodic decision entries
2 swing-offset entries
```

Expose named variables rather than raw positions outside the adapter/layout.

### 6.3 Numerical migration

Migrate the complete runtime dependencies of:

```text
ZeroFunc_BipedApex_offset.m
ZeroFunc_BipedApex_offset_optimization.m
Gaitidentify.m
ShowTrajectory_BipedalDemo.m
objective functions
constraint functions
resampling functions
required stance/swing/event helpers
```

Do not copy the old continuation algorithm as the primary engine. Use it only
as a regression reference. Route continuation through the generic framework
engine when that engine is available.

### 6.4 Built-in data

Include small self-contained examples representing available gait classes,
preferably:

```text
walk
run
hop
skip
asymmetric run
```

The GUI must be able to load at least one biped example without file browsing.

### 6.5 Capabilities

At release, advertise truthful implemented capabilities. Minimum required:

```text
simulate = true
solve = true
continue = true
optimize = true
visualize = true
animate = true
```

---

## 7. Standalone model 2: `slip_quadruped`

Implement under:

```text
models/+lmzmodels/+slip_quadruped/
catalog/slip_quadruped/
```

### 7.1 Required functionality

Implement:

```text
Model
PhysicalStateSchema
ParameterSchema
PeriodicDecisionSchema
PeriodicApexProblem
EventScheduleProjector
LegacyEvaluator
Results29Adapter
GaitClassifier
Kinematics
PlotDescriptors
scene.lmz.json
built-in roadmap branch
```

### 7.2 Legacy layout

The adapter must preserve:

```text
13 periodic initial-state entries
9 event-time entries
7 parameter entries
```

It must import a legacy `results` matrix into a native `SolutionBranch` with:

- named decision values;
- named parameter values;
- point order;
- source lineage;
- classifications/observables when available;
- exact legacy export.

### 7.3 Numerical migration

Migrate all runtime dependencies of:

```text
Quadrupedal_ZeroFun_v2.m
EventTimingRegulation.m
Gait_Identification.m
generated stance-leg functions
GRF calculations
required graphics/kinematics helpers
```

The deterministic problem residual must call the compatibility evaluator with
hidden event-time solving disabled. Event-time repair belongs in an explicit
`EventScheduleProjector`.

### 7.4 Generic operations

Minimum required capabilities:

```text
simulate = true
solve = true
continue = true
parameterHomotopy = true
branchFamilyScan = true
visualize = true
animate = true
```

Include a small built-in roadmap branch and a default solution so the GUI
starts with meaningful data.

---

## 8. Standalone model 3: `slip_quad_load`

Implement under:

```text
models/+lmzmodels/+slip_quad_load/
catalog/slip_quad_load/
```

### 8.1 Required functionality

Implement:

```text
Model
QuadrupedStateSchema
LoadStateSchema
QuadrupedParameterSchema
LoadParameterSchema
SingleStrideDecisionSchema
MultiStrideDecisionSchema
SingleStrideProblem
MultiStrideFitProblem
LegacyEvaluator
XAccumAdapter
MultiStrideSimulator
objective terms
Kinematics
PlotDescriptors
scene.lmz.json
built-in single- and multi-stride examples
```

### 8.2 Numerical migration

Migrate complete runtime dependencies of:

```text
Quad_Load_ZeroFun_Transition_v2.m
SimulateQuadLoadStrides.m
fms_NStridesObjectiveFcn_Quad_Load_v2.m
EventTimingRegulation.m
required generated dynamics helpers
required graphics helpers
resampling and metric helpers
```

Centralize the packed multi-stride layout. When confirmed by source and
fixtures, represent:

\[
44 + 13(N-1)
\]

without duplicating packing logic in simulator and objectives.

### 8.3 Objective decomposition

Implement independently testable objective terms:

```text
StrideDurationMismatch
FootfallTimingMismatch
LoadingForceMismatch
CompositeObjective
R2Metrics
```

Each term owns its weight, normalization, resampling policy, diagnostics, and
contribution.

### 8.4 Capabilities

Minimum required:

```text
simulate = true
optimize = true
visualize = true
animate = true
```

Expose `solve` or `continue` only for a mathematically implemented problem.

---

## 9. Complete generic runtime services

Retain the current core scaffold and implement the missing service layer.

Required services:

```text
lmz.services.RegistryService
lmz.services.DataService
lmz.services.SimulationService
lmz.services.SolveService
lmz.services.SeedService
lmz.services.ContinuationService
lmz.services.OptimizationService
lmz.services.VisualizationService
lmz.services.ArtifactService
```

The GUI calls only services.

Every service must:

- validate capabilities;
- accept `RunContext`;
- report progress and logs;
- support cooperative pause/cancel where meaningful;
- return structured result objects;
- record model/problem IDs and provenance;
- have a synchronous path that requires no Parallel Computing Toolbox.

Do not put a model-specific function call in a generic service.

---

## 10. Root solving and optimization

Implement readable, tested wrappers:

```text
lmz.solvers.FsolveSolver
lmz.solvers.MultiStartSolver
lmz.optimization.FminconSolver
lmz.optimization.FminsearchSolver
```

Requirements:

- consume problem contracts only;
- preserve named residual/objective blocks;
- store complete options, diagnostics, and random seed;
- support rectangular residuals accepted by `fsolve`;
- never silently switch algorithms;
- never hide seed repair inside residual evaluation;
- do not hard-code model variable indices.

The GUI must provide solver settings with safe defaults and an advanced
settings panel.

When Optimization Toolbox is unavailable:

- simulation and visualization remain usable;
- solve/optimization controls are visibly disabled;
- the GUI explains the missing toolbox;
- the application does not crash at startup.

---

## 11. Generic pseudo-arclength continuation

Implement or complete a model-independent continuation engine.

Do not require the residual row count to equal `n - 1`.

For:

\[
F:\mathbb{R}^{n}\rightarrow\mathbb{R}^{m},
\]

a regular one-dimensional solution set requires:

\[
n-\operatorname{rank}J_F(u)=1.
\]

Use the problem's chart and metric consistently for:

- lifted local difference;
- tangent;
- predictor;
- pseudo-arclength corrector;
- step length;
- curvature;
- duplicate detection;
- loop closure;
- stagnation.

Provide:

```text
ContinuationOptions
ContinuationSnapshot
ContinuationResult
SecantPredictor
PseudoArclengthCorrector
StepSizeController
BacktrackingController
DuplicateDetector
LoopClosureDetector
ContinuationAcceptancePolicy
PseudoArclengthContinuation
ParameterHomotopy
BranchCatalog
BranchFamilyScan
CheckpointStore
```

Preserve useful quadruped behavior:

- bidirectional search;
- timing lifting;
- adaptive radius;
- backtracking;
- checkpoints;
- pause/stop;
- logs;
- explicit termination reasons.

Remove from the generic engine:

- prompts;
- figures;
- filenames;
- gait names;
- velocity-specific termination;
- quadruped indices;
- parameter-key maps.

Add analytic tests for:

```text
fold traversal
closed curve
cyclic variable
changing period
overdetermined rank-deficient residual
cancellation
checkpoint/resume
```

---

## 12. Visualization and animation

Implement a safe scene and rendering layer.

Required generic classes:

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

Support:

```text
ground
polygon/body
point marker
line segment
spring
rope
force vector
trail
text
```

The model returns named frames/points and observables. Renderers must not index
raw model vectors.

Animation must support:

- normalized-time scrubbing;
- play;
- pause/stop;
- frame-rate control;
- current-time display;
- GIF export;
- MP4 export when supported;
- keyframe image/PDF export.

Include model-specific plots as plugins:

### `slip_biped`

```text
body and leg trajectories
footfall/event timing
gait information
```

### `slip_quadruped`

```text
body and leg trajectories
GRFs
oscillator/phase plot
gait information
```

### `slip_quad_load`

```text
footfall sequence
leg trajectories
GRFs
tugline force
load trajectory
sensitivity plot when data exists
```

---

## 13. Usable programmatic GUI

Implement:

```text
src/+lmz/+gui/LeggedModelZooApp.m
src/+lmz/+gui/AppState.m
src/+lmz/+gui/AppController.m
src/+lmz/+gui/+views/
src/+lmz/+gui/+components/
legged_model_zoo.m
```

Do not use one giant nested-function file and do not use `global`.

### 13.1 Launch behavior

`legged_model_zoo` must:

1. locate the project root;
2. call `startup`;
3. construct and return the app;
4. show an actionable error dialog when MATLAB requirements are missing.

The application must launch without external repositories and without asking
the user to locate source code.

### 13.2 Initial experience

On first launch:

- the model selector shows exactly:
  - `slip_biped`
  - `slip_quadruped`
  - `slip_quad_load`;
- a built-in example is available for each;
- selecting an example populates solution/parameter information;
- simulation and visualization can run immediately;
- unsupported toolbox-dependent actions are disabled with explanation.

### 13.3 Required GUI layout

Use a programmatic `uifigure` with a resizable `uigridlayout`.

Required areas:

#### Header

- application title;
- canonical model selector;
- problem selector;
- built-in example selector;
- open data/artifact button;
- save/export button.

#### Main workspace tabs

1. **Branch**
   - load one or more branches;
   - named X/Y/Z selectors;
   - 2-D/3-D view;
   - hover information;
   - clicked-point selection;
   - delete/visibility controls;
   - export plot.

2. **Solution**
   - schema-generated decision table;
   - schema-generated parameter table;
   - residual/objective diagnostics;
   - classification and provenance.

3. **Simulation**
   - model scene;
   - normalized-time slider/input;
   - play, pause, stop;
   - trajectory and model-specific observable plots;
   - GIF/MP4/keyframe export.

4. **Solve**
   - source seed selection;
   - editable values;
   - reproducible noise;
   - solver settings;
   - solve/refine;
   - compare seed and solution;
   - save result.

5. **Continuation**
   - first seed;
   - second-seed construction;
   - radius/step settings;
   - bidirectional run;
   - pause, resume, stop;
   - checkpoint selection;
   - parameter homotopy;
   - branch-family scan;
   - live accepted-point preview.

6. **Optimization**
   - shown when model/problem supports optimization;
   - objective-term weights;
   - bounds/settings;
   - run/pause/stop;
   - objective contribution table;
   - result comparison/export.

7. **Log**
   - timestamped status;
   - progress;
   - diagnostics;
   - warnings/errors;
   - output paths.

### 13.4 Responsiveness

All long operations use `RunContext`.

Provide a synchronous runner that always works. Optionally use `parfeval` when
available, but do not require Parallel Computing Toolbox.

The GUI must remain responsive through `drawnow` and cooperative callbacks.
Closing the app requests controlled cancellation and preserves checkpoints.

### 13.5 GUI testing

Add:

```text
TestAppConstruction
TestAppModelList
TestAppBuiltInExamples
TestAppCapabilityEnablement
TestAppControllerSimulation
TestAppControllerSolve
TestAppControllerContinuation
TestAppControllerOptimization
```

Run headless controller tests even without a desktop. Run construction and
visual smoke tests when `usejava('desktop')` and a display are available.

---

## 14. Built-in data and standalone packaging

Create a clear data layout such as:

```text
examples/data/slip_biped/
examples/data/slip_quadruped/
examples/data/slip_quad_load/
```

Include small, redistributable built-in data sufficient for:

- opening each model in the GUI;
- simulating at least one solution;
- demonstrating plots/animation;
- solving/continuing where supported;
- optimizing the load model in a short smoke test.

Every file must have:

- source/provenance metadata;
- model ID;
- problem ID;
- variable names;
- units where known;
- license/redistribution status.

Do not require users to run fixture-regeneration tools.

Move source-repository fixture regeneration to a clearly maintainer-only
location, for example:

```text
tools/maintainers/
```

Do not mention it in the README installation or quick-start sections.

---

## 15. README contract

Rewrite `README.md` as a detailed standalone user guide.

It must contain, in this order:

1. **Project overview**
2. **Features**
3. **Requirements**
4. **Standalone installation**
5. **Launch the GUI**
6. **GUI walkthrough**
7. **Available models**
   - `slip_biped`
   - `slip_quadruped`
   - `slip_quad_load`
8. **Built-in examples**
9. **Command-line quick start**
10. **Simulating each model**
11. **Loading and saving data**
12. **Solving periodic solutions**
13. **Numerical continuation**
14. **Parameter homotopy and branch-family scans**
15. **Optimization and data fitting**
16. **Visualization, animation, and recording**
17. **Artifact format**
18. **Legacy MAT import/export**
19. **Adding a new model**
20. **Testing**
21. **Troubleshooting**
22. **Project structure**
23. **License and provenance**
24. **Current verified status**

### 15.1 Installation wording

The installation section must say, in substance:

```text
Clone or download Legged_Model_Zoo, start MATLAB in the repository root,
and run legged_model_zoo.
```

It must not instruct users to clone, copy, place, or locate any source
research repository.

The following names are prohibited in README installation, setup, quick start,
and normal usage sections:

```text
SLIP_Model_Zoo
2022_A_Template_Model_Explains_Jerboa_Gait_Transitions
2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights
```

They may appear only in the final provenance/license section.

### 15.2 README commands

Every public command in the README must be copied into executable smoke tests
or examples.

At minimum document:

```matlab
legged_model_zoo
```

and:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
registry.listModels();
```

plus one command-line simulation for each canonical model.

### 15.3 Continuous updates

After each coherent implementation patch:

- update README immediately;
- run `tools/update_readme_status`;
- run `tools/check_readme_contract`;
- correct any stale capability, path, command, or model name before proceeding.

Add a test that fails when:

- the canonical model table differs from manifests;
- README contains the sibling-repository installation layout;
- a documented example file is missing;
- a documented launch command is absent;
- an implemented capability is reported incorrectly.

---

## 16. Static standalone enforcement

Extend architecture/static checks.

Runtime and README checks must reject:

```text
global
restoredefaultpath
addpath(genpath
eval
evalin
assignin
runtime references to sibling source repositories
old active model package names
old canonical model IDs
direct optimizer calls from GUI
direct legacy zero-function calls from GUI or generic services
raw model-specific indices in generic packages
```

Allow source-repository names only in:

```text
docs/provenance.md
THIRD_PARTY_NOTICES.md
tools/maintainers/
historical migration notes
```

Implement an isolation test:

1. copy the target repository to a temporary parent containing no sibling
   repositories;
2. launch a clean MATLAB process in that copy;
3. run `startup`;
4. discover all three models;
5. load each built-in example;
6. simulate each model;
7. construct the GUI;
8. run short solve/continuation/optimization smoke tests where supported.

This is the decisive standalone test.

---

## 17. Testing requirements

Use `matlab.unittest`.

Retain existing tests and add at least:

```text
TestCanonicalModelNames
TestLegacyModelIdAliases
TestStandaloneRegistry
TestStandaloneBuiltInData
TestNoExternalRepositoryDependency
TestReadmeContract
TestReadmeExamples
TestSlipBipedImport
TestSlipBipedSimulation
TestSlipBipedSolve
TestSlipBipedContinuation
TestSlipBipedTrajectoryFit
TestSlipQuadrupedNativeBranchImport
TestSlipQuadrupedSimulation
TestSlipQuadrupedSolve
TestSlipQuadrupedSecondSeed
TestSlipQuadrupedContinuation
TestParameterHomotopy
TestBranchFamilyScan
TestSlipQuadLoadXAccumImport
TestSlipQuadLoadSingleStrideSimulation
TestSlipQuadLoadMultiStridePacking
TestSlipQuadLoadObjectiveTerms
TestSlipQuadLoadOptimization
TestSceneValidation
TestRendererNamedFrames
TestAnimationController
TestAppConstruction
TestAppBuiltInExamples
TestAppControllerSimulation
TestArchitectureRules
```

For numerical regression:

- compare residuals directly;
- compare event records separately;
- interpolate continuous trajectories onto a common time grid;
- compare forces/observables with measured absolute and relative tolerances;
- record tolerances and baseline provenance;
- never say a numerical test passed unless MATLAB executed it.

---

## 18. Test execution

Search for MATLAB on `PATH` and in common installation locations.

When available, record:

```matlab
version
ver
license('test','Optimization_Toolbox')
license('test','Distrib_Computing_Toolbox')
usejava('desktop')
```

Run:

```bash
matlab -batch "cd('<TARGET>'); results=run_tests; assert(~any([results.Failed]));"
```

Run all public examples in a smoke-test harness.

Run the isolation/standalone test from a temporary copy.

Run GUI construction tests when a display is available and always run
headless controller tests.

If MATLAB is unavailable:

- continue implementing all runtime code, migrations, GUI, examples, tests,
  README, and static checks;
- run JSON, path, naming, dependency, license, and README checks;
- mark MATLAB execution as unverified;
- do not revert to a scaffold-only result;
- do not claim the release is numerically tested.

---

## 19. Documentation and licensing

Create or complete:

```text
README.md
LICENSE
THIRD_PARTY_NOTICES.md
CHANGELOG.md
MIGRATION_STATUS.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/architecture.md
docs/model-author-guide.md
docs/configuration-reference.md
docs/data-format.md
docs/continuation.md
docs/gui-design.md
docs/provenance.md
docs/legacy-data-contracts.md
```

`THIRD_PARTY_NOTICES.md` must list every copied legacy source/data item and its
license.

Do not remove original file headers.

`MIGRATION_STATUS.md` must no longer use “inventory only” for a model once its
runtime is migrated. Use only evidence-based statuses:

```text
Not started
Partial
Implemented, untested
Tested
Blocked
```

`docs/TEST_STATUS.md` must contain exact commands and exact results.

---

## 20. Required public examples

Create and keep synchronized with README:

```text
examples/demo_gui.m
examples/demo_registry.m
examples/demo_slip_biped.m
examples/demo_slip_biped_fit.m
examples/demo_slip_quadruped.m
examples/demo_slip_quadruped_solve.m
examples/demo_slip_quadruped_continuation.m
examples/demo_parameter_homotopy.m
examples/demo_branch_family_scan.m
examples/demo_slip_quad_load.m
examples/demo_slip_quad_load_fit.m
```

Each example must:

- call only public APIs;
- use built-in repository data;
- avoid external repository paths;
- return or save structured outputs;
- be safe to execute more than once.

---

## 21. Definition of done

Do not finish the round until all applicable conditions hold.

### Naming

- registry lists exactly:
  - `slip_biped`
  - `slip_quadruped`
  - `slip_quad_load`;
- GUI shows those names;
- new artifacts use those names;
- old IDs are aliases only.

### Standalone runtime

- all required model source is present in this repository;
- all built-in examples are present;
- no normal workflow depends on sibling repositories;
- isolation test passes or is implemented and honestly marked unexecuted.

### Model functionality

- `slip_biped` imports, simulates, solves, continues, fits, visualizes, and
  animates;
- `slip_quadruped` imports, simulates, solves, continues, scans, visualizes,
  and animates;
- `slip_quad_load` imports, simulates, optimizes, visualizes, and animates.

### GUI

- `legged_model_zoo` launches;
- all three models are selectable;
- each has a built-in example;
- simulation/visualization works for each;
- solve/continuation/optimization controls work according to capabilities;
- load/save/export/logging work;
- missing optional toolboxes are handled without startup failure.

### README

- detailed standalone usage guide exists;
- no sibling-repository installation instructions remain;
- all commands match actual APIs;
- capability table matches manifests;
- README was updated throughout implementation and passes its contract test.

### Quality

- architecture checks pass;
- source repositories remain unchanged;
- license/provenance notices are complete;
- no disabled placeholder capability is advertised;
- no model method returns a `status = not-implemented` placeholder;
- no model simulation method merely throws “not migrated” in the release
  path.

---

## 22. Final report

Report:

1. target path and final Git status;
2. final HEAD;
3. canonical model IDs returned by the registry;
4. GUI launch command and tested GUI workflows;
5. migrated model source/data files and provenance;
6. evidence that the repository runs without sibling repositories;
7. exact commands executed;
8. exact test totals;
9. MATLAB/toolbox/display availability;
10. numerical differences and tolerances;
11. README contract result;
12. any remaining blocked item with its exact external prerequisite.

Do not report “finished,” “standalone,” “GUI available,” or “tests pass”
without corresponding execution evidence.

Begin by performing the naming migration and README update, then migrate
`slip_quadruped` as the first standalone GUI vertical slice. Continue with
`slip_biped`, then `slip_quad_load`. Do not ask for confirmation between
these steps.
