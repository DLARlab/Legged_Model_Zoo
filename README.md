# Legged Model Zoo

## Project overview

Legged Model Zoo is a standalone MATLAB framework and non-technical GUI for exploring legged-model simulation, solving, continuation, fitting, and visualization through common registry, service, schema, and artifact boundaries. The repository contains three validated scientific workflows: the nine-branch SLIP quadruped RoadMap, the six-branch jerboa biped GaitMap and trajectory fit, and single-/multi-stride quadruped-with-load simulation and fitting. Each model also keeps a clearly labeled `demo_stride` tutorial; tutorial results are never presented as scientific validation.

## Features

- One-command programmatic GUI launch
- Declarative discovery of three canonical models
- Standalone built-in simulation for every model
- Named state schemas and validated simulation results
- A multi-dataset RoadMap explorer with named decision, timing, parameter, and observable axes
- Locked/hover branch selection synchronized with solution, simulation, solve, continuation, and oscillator state
- Scientific quadruped animation, torso/leg trajectories, GRFs, oscillator plots, and recording/export services
- Cooperative progress, pause, and cancellation context
- Versioned plain-struct artifact validation and atomic MAT persistence
- Deprecated import aliases for older model identifiers
- Native schema-based solutions and multi-point branches
- Generic `fsolve`, adaptive pseudo-arclength continuation, file-backed checkpoints, homotopy, branch-family scans, and `fmincon`
- Exact legacy Results29, Results14, and `X_accum` import/export with manifest hashes and native artifact caching
- Source-equivalent biped 12-decision/15-residual solving, continuation, gait classification, and 16-variable trajectory fitting
- Source-equivalent load-pulling `44 + 13*(N-1)` simulation, event/GRF/tugline outputs, objective terms, guarded R-squared metrics, and reduced-variable optimization
- Per-problem tutorial/validated maturity and tested/source-equivalent validation badges derived from catalog descriptors
- Deterministic continuation edge-case coverage for forced rejection, minimum step, curvature, stagnation, historical loop closure, controlled stop, and checkpoint resume

Scientific claims are per problem, not per model name. `slip_biped/periodic_apex`, `slip_biped/trajectory_fit`, `slip_quad_load/single_stride`, `slip_quad_load/multi_stride_fit`, and `slip_quadruped/periodic_apex` are compared with repository-contained source baselines. Every `demo_stride` problem is a tested analytic tutorial.

## Requirements

- MATLAB R2019b or newer
- No toolbox is required to load built-in branches/datasets, inspect schemas/artifacts, or run deterministic scientific simulation
- Optimization Toolbox is required for `fsolve`, continuation correction, fitting, and the optional quadruped ground-contact event projection. Default cyclic-time wrapping is toolbox-free.
- Parallel Computing Toolbox is optional

The Round 6 release gate is executed with MATLAB R2025b Update 5. Optimization Toolbox is licensed; Parallel Computing Toolbox is licensed but not required. `usejava('desktop')` is false in the verification process, so programmatic `uifigure` construction and callbacks are automated but the human desktop walkthrough remains explicitly blocked. R2019b is the compatibility target; no R2019b installation is present, so only the recorded static audit—not runtime verification—is claimed.

## Standalone installation

Clone or download `Legged_Model_Zoo`, start MATLAB in the repository root, and run:

```matlab
legged_model_zoo
```

Normal installation and usage require only this repository. `startup.m` adds only the repository's `src` and `models` roots.

## Launch the GUI

Launch directly:

```matlab
app = legged_model_zoo;
```

Or initialize explicitly:

```matlab
startup;
app = lmz.gui.LeggedModelZooApp();
```

## GUI walkthrough

The application opens on the SLIP quadruped RoadMap. The header provides canonical model, problem, and demonstration selectors. Every problem label includes its maturity and validation badge—for example, `validated • source-equivalent` versus `tutorial • tested`. **Run demo** always executes the separate analytic tutorial. Scientific work starts by selecting the appropriate RoadMap, GaitMap, or load dataset and locking a stored point.

The branch tab supports built-in selection, folder/file import, one/all dataset visibility, removal/reload, native and legacy export, named X/Y/Z coordinates, 2-D/3-D views, explicit view/limit/aspect controls, index and percentage navigation, independent hover data tips, keyboard navigation, click-to-lock selection, and model-specific styling. The Solution Inspector groups the exact schema into initial state, event timing, physical/load parameters, later-stride additions, observables, residuals/objective terms, diagnostics, and provenance; inactive parameters are shown but disabled for transport, and edits affect an isolated working copy. Physical Simulation dispatches to the selected model’s renderer and plot provider. Solve and Continuation are enabled only on problems that advertise them; Optimization is enabled for the biped trajectory fit and multi-stride load fit.

## SLIP Quadruped RoadMap Tutorial

1. Launch with `app = legged_model_zoo;`. The GUI defaults to `slip_quadruped/periodic_apex` and loads the built-in `PK_20_2` RoadMap branch at interior seed index 267.
2. In **RoadMap Branches**, use the **Built-in RoadMap** selector and press **Load selected**, or press **Load all** for all nine branches. **Open folder…** and **Open MAT/artifact…** add user data; source branches remain read-only references.
3. Choose named X, Y, and optional Z axes. The documented RoadMap preset is X=`dx`, Y=`dphi`, Z=`y`, top view, with X `[0,10]`, Y `[-0.05,0.15]`, and Z `[0.6,1.2]`. This comes from the source GUI and copied reference figures; MAT data remains authoritative where an old FIG curve differs.
4. Move the pointer near a visible branch to preview its nearest point and a dataset/index/coordinate/parameter/gait/residual data tip. Hover never changes the locked point. Click a curve, use arrow keys, enter an index, or move the percentage control to lock a point across every tab.
5. Open **Solution Inspector** to review the 13 initial-state values, nine event timings, seven physical parameters, derived observables, residual blocks, diagnostics, and source provenance. Edit the Value column, validate it, save it, or add it as a writable dataset. **Restore locked point** discards working edits; source RoadMap matrices are never mutated.
6. Press **Simulate candidate** or **Simulate point**. The migrated evaluator runs with hidden timing repair disabled. Use the slider or numeric normalized time, FPS/speed/loop controls, Play/Pause/Stop/Reset, force toggle, and Complete/Progressive selector to inspect physical animation, torso and leg trajectories, GRF magnitude/x/y components, and oscillator phases.
7. Use **Project event schedule** only when intentional. **Wrap cyclic times** is deterministic and toolbox-free; **Project ground contact** explicitly invokes the compatibility timing solve. Neither mode is hidden inside residual evaluation.
8. In **Solve / Seeds**, evaluate and press **Solve/refine**. A RoadMap point already below tolerance is accepted unchanged; otherwise the generic service refines it and reports algorithm, exit flag, iterations, residual, gait, and chart-aware change. Optional schema-scaled noise records its random seed.
9. Select next/previous and press **Adjacent pair**, or enter two manual indices. Endpoint selection moves inward. The service checks branch identity, parameter compatibility, finite values, residuals, gait policy, and chart-aware separation; the pair and predictor are overlaid on the RoadMap.
10. **Generated second seed** uses the generic second-seed solver at the numeric requested radius and reports achieved radius and residual. The edited or last-solved working candidate can be sent directly to this path.
11. In **Continuation**, choose a total point count and run. Prediction, accepted, and rejected callbacks update a live source-RoadMap overlay with residual, step, direction, and gait status.
12. Pause, resume, or request a controlled stop; accepted points remain available. Enter or choose a checkpoint path for atomic updates, then use **Resume file**. The same operations are available through `ContinuationService.resumeCheckpoint` and `AppController.resumeCheckpoint`.
13. The Continuation tab exposes homotopy/family scans only for active parameters. Use nearby `k_leg` targets for a dynamics-changing workflow; `phi_neutral` is visible as an inactive Results29 compatibility field and is disabled for transport. A family scan repeats one-dimensional continuation at targets; it is not two-dimensional continuation.
14. Use **Save native…**, **Export legacy…**, **Save solution…**, or **Save result…** as appropriate. An unchanged imported branch reconstructs the source 29-row `results` matrix exactly. The Physical Simulation tab exposes GIF, MP4 where supported, PNG/PDF keyframes, five plot exports, and oscillator GIF; exports are temporary-file based, cancellation-aware, and restore the displayed animation frame.

The complete command-line equivalent is [examples/demo_slip_quadruped_roadmap_workflow.m](examples/demo_slip_quadruped_roadmap_workflow.m).

## SLIP Biped GaitMap Tutorial

1. Launch the app and select **SLIP Biped**. The scientific selector loads `W1.mat` at its recommended walking seed; **Load all** adds `W1`, `R1`, `HP1`, `SK1`, `SK2`, and `AR1` (2,967 total points). The problem badge for `periodic_apex` reads `validated • source-equivalent`; `demo_stride` remains `tutorial • tested`.
2. Use X=`dx`, Y=`alphaL`, and Z=`y` to explore the GaitMap. Hover previews without changing the lock; click, arrows, index, or percentage locks a point. Branch metadata retains the original filename, column, SHA-256, gait, and offsets.
3. In **Solution**, inspect the exact 12 decisions: `dx`, `y`, `dy`, `alphaL`, `dalphaL`, `alphaR`, `dalphaR`, `tL_TD`, `tL_LO`, `tR_TD`, `tR_LO`, `tAPEX`. Rows 13–14 of Results14 are named parameters `offset_left` and `offset_right`. The physical state is the separate eight-entry `x`, `dx`, `y`, `dy`, `alphaL`, `dalphaL`, `alphaR`, `dalphaR` schema.
4. Press **Evaluate** or **Simulate candidate**. The nine named residual blocks contain exactly 15 entries; entry 12 is the intentionally reserved zero. Simulation exposes five event records, contact modes, six force channels, energy, body/leg trajectories, and gait classification without a hidden timing solve.
5. Use the physical controls to scrub or play the biped animation and inspect trajectories, GRFs, and normalized footfalls. GIF/keyframe/plot recording uses the same generic export service as the quadruped.
6. Press **Solve/refine**. A published point already under tolerance is accepted without movement. Create an adjacent pair from neighboring GaitMap columns, or generate a small second seed (the regression workflow uses radius `0.002`).
7. Run continuation with a bounded point count. Pause/resume/stop and checkpoint/resume use the same controls and artifact format as the RoadMap. Adjacent published points are the recommended scientific continuation seeds.
8. Open **Optimization** and press **Run fit** to fit the built-in 101-sample observed trajectory. The 16 fit decisions are the 12 periodic variables plus `k_leg`, `omega_swing`, `offset_left`, and `offset_right`; named terms report body position/height, left/right leg angle, periodic residual, and event-time mismatch.
9. The GUI uses the source-Main penalized fit mode for a short responsive run. Programmatic users can select `EnforceConstraints=true` to expose the alternate 15-entry equality-constrained formulation.
10. Save a solution, branch, continuation result, or optimization result as a native `.lmz.mat` artifact. Exporting an unchanged GaitMap branch through `Results14Adapter` reconstructs the original 14-row matrix exactly.

Command-line branch, simulation, solve, and continuation:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
problem = model.createProblem('periodic_apex', struct());
catalog = lmzmodels.slip_biped.GaitMapCatalog.default();
branch = catalog.loadBranch(catalog.defaultBranchPath(), problem, true);
index = catalog.recommendedSeedIndex(catalog.defaultBranchPath());
seed = branch.point(index);
context = lmz.api.RunContext.synchronous(21);
evaluation = problem.evaluate(seed.DecisionValues, ...
    seed.ParameterValues, context, true);
solveResult = lmz.services.SolveService().solve( ...
    problem, seed, struct(), context);
pair = lmz.services.SeedService().adjacentBranchPair( ...
    problem, branch, index, +1, struct(), context);
continuationResult = lmz.services.ContinuationService().run( ...
    problem, pair, struct('MaximumPoints', 8, ...
    'BothDirections', false, 'InitialStep', pair.AchievedRadius), context);
```

Command-line trajectory fitting:

```matlab
fit = model.createProblem('trajectory_fit', ...
    struct('EnforceConstraints', false));
u0 = fit.sourceSeed();
u0(1) = u0(1) + 0.05;
u0(4) = u0(4) + 0.01;
fitSeed = fit.makeSolution(u0, fit.getParameterSchema().defaults(), []);
fitOptions = struct('Algorithm', 'sqp', 'MaxIterations', 3, ...
    'MaxFunctionEvaluations', 150, 'ConstraintTolerance', 0.2, ...
    'OptimalityTolerance', 1e-3, 'StepTolerance', 1e-3);
fitResult = lmz.services.OptimizationService().run( ...
    fit, fitSeed, fitOptions, context);
```

See [examples/demo_slip_biped_gaitmap_workflow.m](examples/demo_slip_biped_gaitmap_workflow.m), [examples/demo_slip_biped_solve.m](examples/demo_slip_biped_solve.m), [examples/demo_slip_biped_continuation.m](examples/demo_slip_biped_continuation.m), and [examples/demo_slip_biped_trajectory_fit.m](examples/demo_slip_biped_trajectory_fit.m). A lower-level schema/reference guide is in [models/+lmzmodels/+slip_biped/README.md](models/+lmzmodels/+slip_biped/README.md).

## SLIP Quadruped-with-Load Fitting Tutorial

1. Launch the app and select **SLIP Quadruped with Load**. The built-in selector offers a 44-entry single-stride dataset and a 57-entry two-stride transition dataset. No file dialog or external checkout is required.
2. The first-stride layout is exact: 13 quadruped initial states, nine event times, 14 quadruped parameters, two load states, and six load parameters. Each later stride adds exactly nine event times and four post-contact swing stiffnesses, giving `44 + 13*(N-1)` decisions.
3. In **Solution**, inspect named first- and later-stride groups rather than an opaque tail vector. Edit a working value and restore it without mutating the source dataset. Legacy `X_accum` import/export remains exact.
4. Press **Simulate candidate**. The 18 physical states contain the 14-state quadruped followed by load `x`, `dx`, `y`, `dy`. The renderer draws torso, four legs, load, ground, and tugline; plots expose footfalls, body/leg/load trajectories, all GRF channels, tugline force, sensitivity data where present, and R-squared diagnostics.
5. Select `multi_stride_fit` (`validated • source-equivalent`) and evaluate the working decision. Named objective terms reproduce source stride-duration mismatch, footfall-timing mismatch, and normalized loading-force mismatch. Guarded R-squared output records constant/degenerate-series handling rather than returning an unexplained non-finite value.
6. Press **Run fit**. The public decision remains the complete 57-entry scientific vector, while the generic optimizer automatically reduces this dataset to its four free later-stride swing-stiffness variables. **Cancel fit** requests a controlled solver stop. The bounded GUI run is intended for responsive evidence, not a claim of global optimality.
7. Compare the initial/final composite and per-term values, simulate the fitted decision, then save the optimization artifact. Export legacy writes an `X_accum` MAT; native artifacts retain dataset ID, source commit, exact schemas, objective terms, R-squared diagnostics, solver options, and free/fixed decision indices.

Command-line single- and multi-stride simulation:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quad_load');
catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
context = lmz.api.RunContext.synchronous(31);

singleData = catalog.load(catalog.Manifest.defaultSingleStride);
single = model.createProblem('single_stride', ...
    struct('DatasetPath', catalog.defaultSinglePath()));
singleSimulation = single.simulateDecision(singleData.XAccum, context);

multiData = catalog.load(catalog.Manifest.defaultMultiStride);
multi = model.createProblem('multi_stride_fit', ...
    struct('DatasetPath', catalog.defaultMultiPath()));
multiSimulation = multi.simulateDecision(multiData.XAccum, context);
[sourceObjective, sourceTerms, sourceDiagnostics] = ...
    multi.evaluateObjective(multiData.XAccum, ...
    multi.getParameterSchema().defaults(), context);
```

Command-line bounded fit:

```matlab
u0 = multi.getDecisionSchema().defaults();
fitSeed = multi.makeSolution(u0, multi.getParameterSchema().defaults(), []);
fitOptions = struct('Algorithm', 'sqp', 'MaxIterations', 1, ...
    'MaxFunctionEvaluations', 30, 'OptimalityTolerance', 1e-5, ...
    'StepTolerance', 1e-5);
fitResult = lmz.services.OptimizationService().run( ...
    multi, fitSeed, fitOptions, context);
assert(fitResult.Objective < ...
    multi.evaluateObjective(u0, fitSeed.ParameterValues, context));
```

See [examples/demo_slip_quad_load_single_stride.m](examples/demo_slip_quad_load_single_stride.m), [examples/demo_slip_quad_load_multi_stride.m](examples/demo_slip_quad_load_multi_stride.m), [examples/demo_slip_quad_load_fit.m](examples/demo_slip_quad_load_fit.m), and [examples/demo_all_scientific_models.m](examples/demo_all_scientific_models.m). The detailed API/schema guide is [models/+lmzmodels/+slip_quad_load/README.md](models/+lmzmodels/+slip_quad_load/README.md); dataset layout/provenance details are in [examples/data/slip_quad_load/Scientific/README.md](examples/data/slip_quad_load/Scientific/README.md).

## Available models

<!-- LMZ:MODEL_TABLE:BEGIN -->
| Model ID | Label | Simulation | Visualization | Solve | Continuation | Optimization |
|---|---|---:|---:|---:|---:|---:|
| `slip_biped` | SLIP Biped | Yes | Yes | Yes | Yes | Yes |
| `slip_quad_load` | SLIP Quadruped with Load | Yes | Yes | No | No | Yes |
| `slip_quadruped` | SLIP Quadruped | Yes | Yes | Yes | Yes | No |
<!-- LMZ:MODEL_TABLE:END -->

Model-level availability is the union of implemented problem capabilities. Scientific maturity is deliberately recorded per problem:

<!-- LMZ:PROBLEM_TABLE:BEGIN -->
| Problem | Kind | Maturity | Validation | Capabilities |
|---|---|---|---|---|
| `slip_biped/periodic_apex` | nonlinear_equation | validated | source-equivalent | simulate, visualize, animate, solve, continue |
| `slip_biped/trajectory_fit` | optimization | validated | source-equivalent | simulate, visualize, animate, optimize |
| `slip_biped/demo_stride` | simulation | tutorial | tested | simulate, visualize, animate |
| `slip_quad_load/demo_stride` | simulation | tutorial | tested | simulate, visualize, animate |
| `slip_quad_load/single_stride` | simulation | validated | source-equivalent | simulate, visualize, animate |
| `slip_quad_load/multi_stride_fit` | optimization | validated | source-equivalent | simulate, visualize, animate, optimize |
| `slip_quadruped/periodic_apex` | nonlinear_equation | validated | source-equivalent | simulate, visualize, animate, solve, continue, homotopy, family scan |
| `slip_quadruped/demo_stride` | simulation | tutorial | tested | simulate, visualize, animate |
<!-- LMZ:PROBLEM_TABLE:END -->

`validated` means a problem has numerical regression evidence; `source-equivalent` means that evidence is tied to an immutable captured source baseline. `tutorial • tested` means the analytic demonstration works as designed, not that it reproduces a publication model.

## Built-in examples

Every model exposes `default_stride` as an analytic tutorial through the application controller. Scientific data is separate: quadruped RoadMap branches, biped GaitMap/trajectory-fit files, and load-pulling `X_accum` datasets live under `examples/data/<model-id>/` with manifests, hashes, source paths, commits, exact dimensions, and redistribution status. Catalogs validate them before use; ordinary runtime never inspects sibling research repositories.

The Round 6 end-to-end examples are:

- `demo_slip_biped_gaitmap_workflow.m`, `demo_slip_biped_solve.m`, `demo_slip_biped_continuation.m`, and `demo_slip_biped_trajectory_fit.m`
- `demo_slip_quad_load_single_stride.m`, `demo_slip_quad_load_multi_stride.m`, and `demo_slip_quad_load_fit.m`
- `demo_slip_quadruped_roadmap_workflow.m`, `demo_all_scientific_models.m`, and `demo_full_desktop_workflow.m`

Each is safe to rerun, uses public APIs and repository-contained data, leaves a structured `output`, and prints an exact success marker.

## Command-line quick start

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
modelIds = registry.listModels()
```

The deterministic result is:

```text
slip_biped
slip_quad_load
slip_quadruped
```

## Simulating each model

The analytic tutorials use the same public simulation service:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
problem = model.createProblem('demo_stride', struct());
context = lmz.api.RunContext.synchronous(42);
simulation = lmz.services.SimulationService().simulate( ...
    problem, struct(), struct(), context);
plot(simulation.state('x'), simulation.state('y'));
```

For scientific solutions, load through the model catalog and call `problem.evaluate(...,true)` or `problem.simulateDecision(...)` as shown in the tutorials. Biped/quadruped body states are named `x` and `y`; the load model uses `quad_x`, `quad_y`, `load_x`, and `load_y`.

Executable examples:

- `examples/demo_slip_biped.m`
- `examples/demo_slip_quadruped.m`
- `examples/demo_slip_quad_load.m`

## Loading and saving data

Load the default repository-contained RoadMap branch and select its documented seed:

```matlab
model = registry.createModel('slip_quadruped');
problem = model.createProblem('periodic_apex', struct());
catalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
branch = lmz.services.BranchService().loadRoadMapBranch( ...
    problem, catalog.defaultBranchPath());
solution = branch.point(catalog.recommendedSeedIndex( ...
    catalog.defaultBranchPath()));
forwardSpeed = branch.decision('dx');
```

See `examples/demo_branch_explorer.m` and `examples/demo_solution_inspector.m`.

The analogous repository-contained scientific loaders are:

```matlab
bipedCatalog = lmzmodels.slip_biped.GaitMapCatalog.default();
bipedBranch = bipedCatalog.loadBranch( ...
    bipedCatalog.defaultBranchPath(), bipedProblem, true);

loadCatalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
loadDataset = loadCatalog.load(loadCatalog.Manifest.defaultMultiStride);
```

Native artifacts contain exactly one top-level plain struct named `artifact`:

```matlab
lmz.io.ArtifactStore.save('result.lmz.mat', artifact);
restored = lmz.io.ArtifactStore.load('result.lmz.mat');
```

The store validates schema identity, dimensions, finite values, per-problem maturity/validation metadata, lineage, random seed, source commits, and version metadata before an atomic rename.

## Solving periodic solutions

Both periodic problems are scientific migrations. `slip_biped/periodic_apex` has 12 decisions, two offset parameters, and 15 residuals. `slip_quadruped/periodic_apex` has 22 decisions, seven parameters, and 22 residuals (eight ground-contact equations, one apex equation, and 13 periodicity equations). Their `demo_stride` siblings remain separate tutorials. Quadruped solve example:

```matlab
model = registry.createModel('slip_quadruped');
problem = model.createProblem('periodic_apex', struct());
catalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
branch = lmz.services.BranchService().loadRoadMapBranch( ...
    problem, catalog.defaultBranchPath());
seed = branch.point(catalog.recommendedSeedIndex( ...
    catalog.defaultBranchPath()));
solveResult = lmz.services.SolveService().solve( ...
    problem, seed, struct(), lmz.api.RunContext.synchronous(11));
```

Evaluation always uses the solver-free compatibility path. `SolveService` first evaluates the stored point and accepts it unchanged when it already meets tolerance.

For the biped, use the same `SolveService` call with a GaitMap solution from the biped tutorial. Both workflows preserve source event times during evaluation and never hide an event-time `fsolve` inside the residual.

## Numerical continuation

The RoadMap supports direct adjacent pairs as well as generated second seeds:

```matlab
seedPair = lmz.services.SeedService().adjacentBranchPair( ...
    problem, branch, 267, +1, struct(), context);
continuationResult = lmz.services.ContinuationService().run( ...
    problem, seedPair, struct('MaximumPoints', 12, ...
    'CheckpointPath', 'quadruped-checkpoint.lmz.mat'), context);
```

The engine supports bidirectional tracing, prediction/accepted/rejected callbacks, adaptive growth and backtracking, curvature response, duplicate/stagnation/historical-loop detection, gait/feasibility policy hooks, cooperative pause/resume/stop, partial-branch preservation, atomic file checkpoints, and checkpoint resume.

## Parameter homotopy and branch-family scans

`slip_quadruped` supports parameter homotopy and repeated branch-family scans over parameters marked active in the schema. `phi_neutral` is retained for Results29 compatibility but unused by the migrated equations, so transport rejects it explicitly. A meaningful nearby `k_leg` example is:

```matlab
homotopyResult = lmz.services.ContinuationService().parameterHomotopy( ...
    problem, solveResult.Solution, 'k_leg', [10 10.001], ...
    struct(), context);
familyReport = lmz.services.ContinuationService().branchFamilyScan( ...
    problem, solveResult.Solution, 'k_leg', [10 10.001], ...
    struct(), context);
```

See `examples/demo_parameter_homotopy.m` and `examples/demo_branch_family_scan.m`. The family scan repeats one-dimensional branches; it is not two-dimensional continuation.

## Optimization and data fitting

`slip_biped/trajectory_fit` and `slip_quad_load/multi_stride_fit` expose source-equivalent named objective contributions and run through `OptimizationService` and `FminconSolver`. The load problem keeps its full public vector but fixes all source-prescribed entries through equal lower/upper bounds; the solver detects those bounds and optimizes only the free entries:

```matlab
model = registry.createModel('slip_quad_load');
problem = model.createProblem('multi_stride_fit', struct());
seed = problem.makeSolution(problem.getDecisionSchema().defaults(), [], []);
options = struct('Algorithm','sqp','MaxIterations',1, ...
    'MaxFunctionEvaluations',30,'OptimalityTolerance',1e-5, ...
    'StepTolerance',1e-5);
optimizationResult = lmz.services.OptimizationService().run( ...
    problem, seed, options, lmz.api.RunContext.synchronous(12));
```

The load objective reports stride-duration, footfall-timing, and loading-force terms plus guarded R-squared diagnostics, all matched to repository-contained source baselines. The biped objective preserves the source event-timing implicit-expansion behavior and supports both the active penalized Main path and the alternate equality-constrained path. A short bounded run demonstrates objective decrease; it is not presented as global convergence.

Additional compatibility examples remain available (`demo_slip_biped_fit.m`, `demo_slip_quadruped_solve.m`, `demo_slip_quadruped_continuation.m`, and `demo_full_gui_workflow.m`), while the Round 6 scientific examples listed above are the recommended entry points.

## Visualization, animation, and recording

Model-specific renderers consume the same named `SimulationResult` boundary. The quadruped draws torso/attachments/four legs, contacts, forces, and oscillators; the biped draws its point mass, two legs/feet, contacts, and forces; the load renderer adds the load body and tugline to the quadruped. `AnimationController` provides normalized-time scrubbing, FPS/speed/loop playback, and Play/Pause/Stop/Reset. Plot providers expose body/leg/load trajectories, footfalls, all available GRF channels, energy/oscillator/tugline histories, sensitivity data, and R-squared diagnostics. `RecorderService` exports GIF, MP4 where `VideoWriter` supports it, animation keyframes, plot PNG/PDF, and animated axes through atomic temporary files; it restores the source frame and closes video/file resources on success, cancellation, or error.

## Artifact format

Supported artifact types include `solution`, `branch`, `simulation`, `solve-run`, `continuation-run`, `optimization-run`, `checkpoint`, and `branch-family-report`. New artifacts must use schema version `1.0.0` and one of the canonical model IDs. Live handle objects are never the public serialization format.

## Legacy MAT import/export

Three model-specific adapters isolate all legacy indexing:

- `Results29Adapter` maps quadruped 29-row `results` matrices to 22 decisions plus seven parameters.
- `Results14Adapter` maps biped 14-row `results` matrices to 12 decisions plus two offsets.
- `XAccumAdapter` maps load decisions with exact length `44 + 13*(N-1)` and explicit first-/later-stride groups.

Each native point retains file/column/hash provenance, schema metadata, classification/observables, and problem maturity. Native artifacts are preferred when their recorded source digest is current; maintainers can explicitly reimport legacy MAT. Encoding unchanged data reconstructs Results29, Results14, or `X_accum` without numerical change. Deprecated model IDs remain read-only import aliases; new artifacts use canonical IDs.

## Adding a new model

Add a package below `models/+lmzmodels`, implement `lmz.api.LeggedModel`, and add a catalog directory containing `manifest.json`, problem descriptors, and a scene when visualization is enabled. Bindings are restricted to `lmzmodels.*`, JSON remains declarative, and advertised capabilities must match implemented problems.

## Testing

Run all tests:

```matlab
results = run_tests;
```

Batch form:

```bash
matlab -batch "cd('/path/to/Legged_Model_Zoo'); results=run_tests; assert(~any([results.Failed]));"
```

Run the documentation contract during development:

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(), 'tools'));
check_readme_contract;
```

Regenerate the registry-derived tables and execute every public example:

```matlab
generate_readme_tables(true);
exampleReport = run_public_examples;
```

Round 6 retains every quadruped RoadMap regression and adds biped/load manifest and exact-layout tests, residual/trajectory/event/GRF/tugline/objective/R-squared equivalence, solve/continuation/checkpoint and objective-decrease workflows, cross-model GUI tests, maturity/capability/artifact contracts, active/inactive homotopy rules, forced continuation terminations, R2019b static compatibility, README generation/contract checks, and all-model isolation. See [docs/TEST_STATUS.md](docs/TEST_STATUS.md) for the executed commands, exact totals, numerical tolerances, success markers, and remaining display/release blockers.

## Troubleshooting

- **Undefined `lmz` package:** run `startup` from the repository root.
- **GUI cannot construct:** verify MATLAB R2019b or newer and desktop graphics availability.
- **Solver controls fail:** verify Optimization Toolbox is licensed and the selected model advertises the requested capability.
- **Artifact uses an old model ID:** load it to migrate the ID, then save a new canonical artifact.
- **Cyclic time rejected:** its named period must be finite and positive.
- **Homotopy parameter disabled:** the parameter is marked inactive because the migrated equations do not use it; choose an active field such as quadruped `k_leg`.
- **Bounded fit returns exit flag 0:** inspect objective decrease and solver diagnostics; the documented one-iteration load fit is intentionally budget-limited.
- **Preparing a public package:** stop and resolve every pending row in `docs/REDISTRIBUTION_STATUS.md`; local migration authorization is not a redistribution license.

## Project structure

```text
src/+lmz/                 Generic APIs, services, data, GUI, and utilities
models/+lmzmodels/        Canonically named standalone model packages
catalog/                  Model, problem, and scene descriptors
examples/                 Public API examples and built-in demonstrations
tests/                    Unit, GUI, documentation, and architecture tests
tools/                    README validation and maintainer utilities
docs/                     Architecture, provenance, and evidence records
```

## License and provenance

Scientific inputs are pinned to three immutable commits: quadruped `SLIP_Model_Zoo` commit `2c106101383ecee1b2a9d695efe09fbd72d5718a`, biped `2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` commit `4595146c5881a5313bc8fe92de85099193ef9be9`, and load-pulling `2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` commit `19f3133073c988cc0c3424a647b4adbb60a90b99`. Normal runtime and tests require only this repository.

Public release packaging is blocked pending explicit owner decisions. The quadruped checkout has no license/notice; the biped readme states CC BY-NC 4.0 but does not include a standalone file clarifying its exact code/data scope; the load readme claims BSD 3-Clause but its linked license file is absent at the audited commit. User authorization to perform this migration is recorded but is not treated as a public redistribution grant. See [docs/REDISTRIBUTION_STATUS.md](docs/REDISTRIBUTION_STATUS.md), [docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md](docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and [docs/provenance.md](docs/provenance.md).

Scientific attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse Quadrupedal Gaits,” *IEEE Robotics and Automation Letters* 9(5), 4782–4789 (2024), DOI `10.1109/LRA.2024.3384908`.

## Current verified status

Under MATLAB R2025b Update 5, all three scientific data catalogs and native artifacts verify: quadruped 9 branches/3,443 points, biped 6 branches/2,967 points, and load 2 datasets (one and two strides). Source-equivalent residual/trajectory/event/force/objective regressions, biped/quadruped solve and continuation, load and biped objective decrease, continuation edge cases, cross-model GUI/controller workflows, recording, artifact round-trips, static architecture/R2019b audits, generated README contracts, and a clean-copy child-process isolation workflow are green. The canonical suite reports `117 run, 0 failed, 0 incomplete`; all 24 top-level public examples pass. Exact commands, tolerances, hashes, markers, isolated-process evidence, and the remaining human-desktop/R2019b/redistribution limitations are recorded in [docs/TEST_STATUS.md](docs/TEST_STATUS.md).
