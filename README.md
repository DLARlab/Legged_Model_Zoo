# Legged Model Zoo

## Project overview

Legged Model Zoo is a standalone MATLAB framework and non-technical GUI for exploring legged-model simulation, solving, continuation, fitting, and visualization through common registry, service, schema, and artifact boundaries. Version `1.0.0-rc.3` adds declaratively registered scientific workflows and an adaptive source-inspired workbench while retaining the three validated scientific routes: the nine-branch SLIP quadruped RoadMap, the six-branch jerboa biped GaitMap and trajectory fit, and single-/multi-stride quadruped-with-load simulation and fitting. It also contains `tutorial_hopper`, a small analytic hybrid model that demonstrates solving, continuation, event/reset records, generic scenes, multiple shooting, and model-zoo extensibility without making a scientific reproduction claim.

This is an internally testable release candidate, not a public binary release. The source tree is the supported way to evaluate it while redistribution authority remains unresolved. Problem badges and catalog metadata distinguish `validated • source-equivalent` scientific problems from `tutorial • tested` examples.

## Features

- One-command programmatic GUI launch and a source-only command-line workflow
- Declarative discovery of four canonical models: three scientific models and one analytic tutorial
- Semantic framework, artifact, catalog, model, and problem version contracts
- A classified public API with explicit deprecation and artifact-compatibility policies
- Standalone built-in simulation for every model
- Named state schemas and validated simulation results
- A multi-dataset RoadMap explorer with named decision, timing, parameter, and observable axes
- Locked/hover branch selection synchronized with solution, simulation, solve, continuation, and oscillator state
- Declaratively registered model-owned data sources, workbench contributions, and complete workflows, including the quadruped RoadMap root/seed/both-direction continuation reference
- Selectable `scientific_workbench` and `classic_tabs` layouts with a persistent branch canvas, scrollable task sidebar, adaptive sizing, and always-visible status/progress
- GUI-independent typed solve-iteration snapshots and shared seed/prediction/solution/continuation overlay layers
- Scientific quadruped animation, torso/leg trajectories, GRFs, oscillator plots, and recording/export services
- Cooperative progress, pause, and cancellation context
- Versioned plain-struct artifact validation and atomic MAT persistence
- Deprecated import aliases for older model identifiers
- Native schema-based solutions and multi-point branches
- Generic `fsolve`, adaptive pseudo-arclength continuation, file-backed checkpoints, homotopy, branch-family scans, and `fmincon`
- Rank-aware square/rectangular timing and multiple-shooting solves with explicit residual, Jacobian-rank, and physical-feasibility classifications
- Section-state nodes, independently integrated shooting segments, interface defects, and dimension-aware horizon continuation
- Registered quadruped/biped mixed-section transitions with model-owned codecs, direct integration, crossing checks, and explicit nonperiodic terminal targets
- Declared timing gauges/families, fixed-contact-row policies, and model-owned section-local scientific shooting adapters
- Heterogeneous stride plans with per-stride schedules, controls, physical parameters, and explicit energy/work policy
- Exact legacy Results29, Results14, and `X_accum` import/export with manifest hashes and native artifact caching
- Source-equivalent biped 12-decision/15-residual solving, continuation, gait classification, and 16-variable trajectory fitting
- Source-equivalent load-pulling `44 + 13*(N-1)` simulation, event/GRF/tugline outputs, objective terms, guarded R-squared metrics, and reduced-variable optimization
- Per-problem tutorial/validated maturity and tested/source-equivalent validation badges derived from catalog descriptors
- Deterministic continuation edge-case coverage for forced rejection, minimum step, curvature, stagnation, historical loop closure, controlled stop, and checkpoint resume
- Six self-contained GUI tab components synchronized by a transactional presentation event bus
- Versioned GUI preferences for window position, default/high-contrast palette, and recent user-selected data/output folders
- Timestamped, copyable status diagnostics and expandable error details
- Stable generic hybrid-system and declarative 2-D scene contracts exercised by `tutorial_hopper` and an isolated external plugin fixture
- Validated `research_legacy`, `clean_generic`, and `high_contrast` visualization profiles with compound source-derived quadruped, biped, and load/rope geometry, selectable analysis plots, stable live switching, and profile-aware recording
- An inactive model-template generator and explicitly trusted external-plugin discovery; no core registry edit is needed for a plugin
- Reproducible solve, continuation, and optimization artifacts with source/data hashes and a `reproduceRun` helper
- Bounded JSON/MAT validation, canonical path checks, malformed-input tests, code analysis, benchmarks, coverage tooling, and local/remote CI definitions
- Authorization-gated deterministic ZIP and MATLAB toolbox builders; technical-validation packages are temporary and marked `NOT_FOR_REDISTRIBUTION`

Scientific claims are per problem, not per model name. `slip_biped/periodic_apex`, `slip_biped/trajectory_fit`, `slip_quad_load/single_stride`, `slip_quad_load/multi_stride_fit`, and `slip_quadruped/periodic_apex` are compared with repository-contained source baselines. Every `demo_stride` problem is a tested analytic tutorial.

## Requirements

- Designed for MATLAB R2019b compatibility; runtime-verified locally on MATLAB R2025b Update 5
- No toolbox is required to load built-in branches/datasets, inspect schemas/artifacts, or run deterministic scientific simulation
- Optimization Toolbox is required for `fsolve`, continuation correction, fitting, and the optional quadruped ground-contact event projection. Default cyclic-time wrapping is toolbox-free.
- Parallel Computing Toolbox is optional
- A MATLAB desktop/display is required for a human GUI walkthrough; automated hidden-figure construction is available without `usejava('desktop')`
- MATLAB R2023a or newer is required only for the repository's programmatic `CoverageResult` report; CI can emit Cobertura evidence through the official MATLAB test action

The current local verification environment is MATLAB R2025b Update 5 on macOS/Apple silicon. Optimization Toolbox is licensed; Parallel Computing Toolbox is licensed but not required. `usejava('desktop')` is false in the verification process, so programmatic `uifigure` construction and callback tests are automated but the human desktop walkthrough remains explicitly unexecuted. No R2019b installation is present, so the repository claims only a static compatibility target—not R2019b runtime verification. See [the release matrix](docs/MATLAB_RELEASE_MATRIX.md) for the exact distinction.

## Standalone installation

Clone or download `Legged_Model_Zoo`. Keep the whole directory together; catalog JSON, built-in MAT data, model packages, and runtime code are resolved relative to the project root. Start MATLAB, change to that root, and initialize the current MATLAB session:

```matlab
cd('/absolute/path/to/Legged_Model_Zoo');
startup;
fprintf('Legged Model Zoo %s\n', lmz.util.Version.current());
```

Confirm discovery before beginning scientific work:

```matlab
registry = lmz.registry.ModelRegistry.discover();
disp(registry.listModels());
```

Normal source usage requires only this repository. `startup.m` adds only the repository's `src` and `models` roots for the current MATLAB session; it does not recursively add tests/tools or permanently rewrite the default MATLAB path. Run `startup` once after opening a new MATLAB session. A public ZIP or `.mltbx` is not currently available because the project has no root `LICENSE` or completed redistribution grant; do not treat a maintainer technical-validation package as an installable public release.

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

Keep the returned `app` variable while using the GUI. Close the figure normally or run `delete(app)` to release presentation listeners, timers, and path-independent GUI resources. For automated construction without showing a window:

```matlab
app = lmz.gui.LeggedModelZooApp('Visible', 'off');
cleanup = onCleanup(@() delete(app));
```

## GUI walkthrough

The application opens on the registered SLIP quadruped RoadMap workflow in the scientific workbench when that contribution is available. A reliable first session is:

1. Use the header to choose a model, problem, or complete registered **Workflow**. Read the badge before interpreting a result: `validated • source-equivalent` has immutable numerical evidence, while `tutorial • tested` is an explanatory analytic workflow. **Run demo** runs only the selected built-in demonstration.
2. Choose **Scientific workbench** or **Classic tabs** in **Layout**. The workbench keeps the branch/data canvas visible while task panels change; classic tabs retain the established six-tab shell. Both use the same controller and numerical services.
3. In the data/branch controls, load one registered RoadMap, GaitMap, or load dataset, or load all registered datasets. Click a curve or use the index/percentage controls to lock a point. Hover previews never replace the locked selection.
4. In **Info / Selection** (or **Solution** in classic tabs), inspect named state, event-time, parameter, observable, residual/objective, diagnostics, and provenance groups. Edits create an isolated working copy. **Restore locked point** discards those edits; a read-only built-in source branch is never modified in place.
5. In **Visualization** (or **Physical Simulation** in classic tabs), choose the visual profile, evaluate the working point, scrub normalized time, play/pause/stop, inspect model plots, and export supported frames, plots, GIF, or MP4. Validated scientific problems default to **Research legacy**; tutorial problems default to **Clean generic**. Export uses the selected renderer, writes profile metadata beside the output, uses a temporary file, and restores the displayed frame on success, cancellation, or error.
6. Use **Solve / Seeds** only when the problem advertises `solve`. Accept or refine the current point, form an adjacent/manual pair, or generate a reproducible nearby second seed. Live stages and typed iterations appear in the persistent status/progress dock; seed, prediction, and corrected-solution markers use the same branch axes.
7. Use **Continuation** only after a valid pair exists. Choose forward, backward, or both directions; the quadruped reference defaults to both. Prediction and rejected-point markers share the persistent canvas, while one accepted-continuation layer grows during the run and is replaced in place by the final or stopped partial branch. Pause/resume/controlled-stop retain accepted points; checkpoint paths support atomic save and later resume. Homotopy/family controls list active parameters only.
8. Use **Optimization** for `slip_biped/trajectory_fit` or `slip_quad_load/multi_stride_fit`. A bounded demonstration run is evidence that the pipeline and objective work, not proof of a global optimum.

The six primary components own their controls and callbacks and delegate numerical work to `AppController` and the service layer. The workbench and classic shells only place those components. Model/problem/workflow/selection changes propagate through one presentation event bus, so incompatible downstream state is invalidated consistently.

For accessibility and diagnostics, every non-obvious control has a tooltip, layouts resize to a minimum usable window size, busy operations disable incompatible controls while preserving the applicable cancel/stop action, and branch markers use shape as well as color. Choose **high-contrast** from the header palette control when needed. The status panel keeps bounded, timestamped, selectable history and has **Copy diagnostics**; errors show a short summary with expandable/copyable technical details when desktop dialogs are available.

Window position, palette, layout profile, sidebar/central-view selection, sidebar-width ratio, and user-selected recent data/output folders persist under the versioned MATLAB preference namespace `LeggedModelZoo_GUI_v1`. Built-in repository paths are not stored as recent folders. Use **Reset preferences** in the header, or call `app.resetPreferences()`, to return to defaults. Keyboard traversal, focus order, DPI scaling, clipboard behavior, and real dialog interaction still require the pending human desktop checklist in [docs/MANUAL_DESKTOP_QA.md](docs/MANUAL_DESKTOP_QA.md); automated GUI evidence is not a substitute for that walkthrough.

## Registered workflows and layout profiles

List and run registered workflows without knowing a model-specific catalog class:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
workflows = lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
disp(workflows.list('slip_quadruped'));

descriptor = workflows.get( ...
    'slip_quadruped', 'roadmap_root_continuation');
session = lmz.workflow.WorkflowRunner().initialize( ...
    descriptor, lmz.api.RunContext.synchronous(1401));
solved = session.solve(struct());
pair = session.makeAdjacentSeedPair(+1, struct());
continued = session.continueBranch(struct( ...
    'MaximumPoints', 20, ...
    'DirectionMode', 'both', ...
    'InitialStep', pair.AchievedRadius));
```

The quadruped descriptor binds `PK_20_2`, point 267, the `periodic_apex` problem, the source-style `roadmap_top` axes, `research_legacy` graphics, `scientific_workbench`, accepted-existing-seed solve options, adjacent/generated seed policies, checkpoints, and both-direction continuation labels. Run the public artifact round-trip example with:

```matlab
run('examples/demo_registered_slip_quadruped_workflow.m')
```

In the GUI, choose **RoadMap apex-root continuation** from **Workflow**. The locked branch point is one controller selection: it feeds Info / Selection, Visualization, Solve / Seeds, Continuation, and analysis. Typed `SolveIterationSnapshot` values update the always-visible progress/status dock. Continuation exposes **Forward**, **Backward**, and **Both directions**; registered defaults and labels are model-owned presentation data, while the generic continuation service owns the algorithm.

Choose a layout in the header or through the controller:

```matlab
controller = lmz.gui.AppController();
controller.setLayoutProfile('scientific_workbench');
controller.setLayoutProfile('classic_tabs');
```

A new branch-capable model contributes `data_sources.lmz.json`, a model-owned `DataSourceProvider`, optional legacy/catalog providers, `workbench.lmz.json`, and one or more workflow JSON files referenced by its manifest. External plugins use the same contracts inside an explicitly trusted plugin root. Generic GUI/services discover them through the registry; adding a model does not require a built-in model-ID case or edit to `src/+lmz`. A minimal model may omit all optional contributions and receives the clean classic-tabs fallback.

See [registered workflows](docs/registered-workflows.md), the [quadruped reference workflow](docs/quadruped-reference-workflow.md), the [scientific workbench layout](docs/scientific-workbench-layout.md), [layout profiles](docs/gui-layout-profiles.md), and the source [workflow](docs/quadruped-workflow-parity.md)/[layout](docs/quadruped-gui-layout-map.md) parity maps.

## SLIP Quadruped RoadMap Tutorial

1. Launch with `app = legged_model_zoo;`. Select **RoadMap apex-root continuation** in **Workflow** and **Scientific workbench** in **Layout**. The registered descriptor selects `slip_quadruped/periodic_apex` and loads `PK_20_2` at interior seed index 267.
2. In the **Built-in RoadMap** data controls, press **Load selected**, or **Load all** for all nine branches. **Open folder…** and **Open MAT/artifact…** add user data; source branches remain read-only references.
3. Choose named X, Y, and optional Z axes. The documented RoadMap preset is X=`dx`, Y=`dphi`, Z=`y`, top view, with X `[0,10]`, Y `[-0.05,0.15]`, and Z `[0.6,1.2]`. This comes from the source GUI and copied reference figures; MAT data remains authoritative where an old FIG curve differs.
4. Move the pointer near a visible branch to preview its nearest point and a dataset/index/coordinate/parameter/gait/residual data tip. Hover never changes the locked point. Click a curve, use arrow keys, enter an index, or move the percentage control to lock a point across every tab.
5. Open **Solution Inspector** to review the 13 initial-state values, nine event timings, seven physical parameters, derived observables, residual blocks, diagnostics, and source provenance. Edit the Value column, validate it, save it, or add it as a writable dataset. **Restore locked point** discards working edits; source RoadMap matrices are never mutated.
6. Press **Simulate candidate** or **Simulate point**. The migrated evaluator runs with hidden timing repair disabled. Use the slider or numeric normalized time, FPS/speed/loop controls, Play/Pause/Stop/Reset, force toggle, and Complete/Progressive selector to inspect physical animation, torso and leg trajectories, GRF magnitude/x/y components, and oscillator phases.
7. Use **Project event schedule** only when intentional. **Wrap cyclic times** is deterministic and toolbox-free; **Project ground contact** explicitly invokes the compatibility timing solve. Neither mode is hidden inside residual evaluation.
8. In **Solve / Seeds**, evaluate and press **Solve/refine**. A RoadMap point already below tolerance is accepted unchanged; otherwise the generic service refines it and reports algorithm, exit flag, iterations, residual, gait, and chart-aware change. Optional schema-scaled noise records its random seed.
9. Select next/previous and press **Adjacent pair**, or enter two manual indices. Endpoint selection moves inward. The service checks branch identity, parameter compatibility, finite values, residuals, gait policy, and chart-aware separation; the pair and predictor are overlaid on the RoadMap.
10. **Generated second seed** uses the generic second-seed solver at the numeric requested radius and reports achieved radius and residual. The edited or last-solved working candidate can be sent directly to this path.
11. In **Continuation**, choose forward, backward, or both directions and a total point count, then run. The registered quadruped default is both. Prediction, accepted, and rejected callbacks update the persistent source-RoadMap overlay with residual, step, direction, and gait status.
12. Pause, resume, or request a controlled stop; accepted points remain available. Enter or choose a checkpoint path for atomic updates, then use **Resume file**. The same operations are available through `ContinuationService.resumeCheckpoint` and `AppController.resumeCheckpoint`.
13. The Continuation tab exposes homotopy/family scans only for active parameters. Use nearby `k_leg` targets for a dynamics-changing workflow; `phi_neutral` is visible as an inactive Results29 compatibility field and is disabled for transport. A family scan repeats one-dimensional continuation at targets; it is not two-dimensional continuation.
14. Use **Save native…**, **Export legacy…**, **Save solution…**, or **Save result…** as appropriate. An unchanged imported branch reconstructs the source 29-row `results` matrix exactly. The Physical Simulation tab exposes GIF, MP4 where supported, PNG/PDF keyframes, five plot exports, and oscillator GIF; exports are temporary-file based, cancellation-aware, and restore the displayed animation frame.

The complete service-oriented command-line equivalent is
[examples/demo_slip_quadruped_roadmap_workflow.m](examples/demo_slip_quadruped_roadmap_workflow.m); the registered equivalent is
[examples/demo_registered_slip_quadruped_workflow.m](examples/demo_registered_slip_quadruped_workflow.m).
The model-level scientific and research-graphics guide is
[models/+lmzmodels/+slip_quadruped/README.md](models/+lmzmodels/+slip_quadruped/README.md).

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
| `slip_quad_load` | SLIP Quadruped with Load | Yes | Yes | Yes | Yes | Yes |
| `slip_quadruped` | SLIP Quadruped | Yes | Yes | Yes | Yes | No |
| `tutorial_hopper` | Analytic Hybrid Hopper Tutorial | Yes | Yes | Yes | Yes | No |
<!-- LMZ:MODEL_TABLE:END -->

Model-level availability is the union of implemented problem capabilities. Scientific maturity is deliberately recorded per problem:

<!-- LMZ:PROBLEM_TABLE:BEGIN -->
| Problem | Kind | Maturity | Validation | Capabilities |
|---|---|---|---|---|
| `slip_biped/periodic_apex` | nonlinear_equation | validated | source-equivalent | simulate, visualize, animate, solve, continue |
| `slip_biped/periodic_orbit` | nonlinear_equation | experimental | tested | simulate, visualize, animate, solve, continue |
| `slip_biped/trajectory_fit` | optimization | validated | source-equivalent | simulate, visualize, animate, optimize |
| `slip_biped/demo_stride` | simulation | tutorial | tested | simulate, visualize, animate |
| `slip_biped/section_return_timing` | nonlinear_equation | experimental | tested | simulate, visualize, animate, solve |
| `slip_biped/multiple_shooting` | nonlinear_equation | experimental | tested | solve, continue |
| `slip_biped/section_transition` | nonlinear_equation | experimental | tested | solve |
| `slip_biped/n_stride_simulation` | simulation | validated | tested | simulate, visualize, animate |
| `slip_quad_load/demo_stride` | simulation | tutorial | tested | simulate, visualize, animate |
| `slip_quad_load/single_stride` | simulation | validated | source-equivalent | simulate, visualize, animate |
| `slip_quad_load/multi_stride_fit` | optimization | validated | source-equivalent | simulate, visualize, animate, optimize |
| `slip_quad_load/section_return_timing` | nonlinear_equation | experimental | tested | simulate, visualize, animate, solve |
| `slip_quad_load/n_stride_simulation` | simulation | validated | tested | simulate, visualize, animate |
| `slip_quad_load/n_stride_fit` | optimization | experimental | tested | simulate, visualize, animate, optimize |
| `slip_quad_load/n_stride_periodic` | nonlinear_equation | experimental | tested | simulate, visualize, animate, solve |
| `slip_quad_load/multiple_shooting_horizon` | nonlinear_equation | experimental | tested | solve, continue |
| `slip_quadruped/periodic_apex` | nonlinear_equation | validated | source-equivalent | simulate, visualize, animate, solve, continue, homotopy, family scan |
| `slip_quadruped/periodic_orbit` | nonlinear_equation | experimental | tested | simulate, visualize, animate, solve, continue, homotopy, family scan |
| `slip_quadruped/demo_stride` | simulation | tutorial | tested | simulate, visualize, animate |
| `slip_quadruped/section_return_timing` | nonlinear_equation | experimental | tested | simulate, visualize, animate, solve |
| `slip_quadruped/multiple_shooting` | nonlinear_equation | experimental | tested | solve, continue |
| `slip_quadruped/section_transition` | nonlinear_equation | experimental | tested | solve |
| `slip_quadruped/n_stride_simulation` | simulation | validated | tested | simulate, visualize, animate |
| `tutorial_hopper/periodic_hop` | nonlinear_equation | tutorial | tested | simulate, visualize, animate, solve, continue |
| `tutorial_hopper/demo_hop` | simulation | tutorial | tested | simulate, visualize, animate |
| `tutorial_hopper/section_return_timing` | nonlinear_equation | tutorial | tested | simulate, visualize, animate, solve |
| `tutorial_hopper/periodic_orbit` | nonlinear_equation | tutorial | tested | simulate, visualize, animate, solve, continue |
| `tutorial_hopper/n_stride_simulation` | simulation | validated | tested | simulate, visualize, animate |
| `tutorial_hopper/contact_timing_sequence` | nonlinear_equation | tutorial | tested | solve |
| `tutorial_hopper/multiple_shooting` | nonlinear_equation | tutorial | tested | solve, continue |
<!-- LMZ:PROBLEM_TABLE:END -->

`validated` means a problem has numerical regression evidence; `source-equivalent` means that evidence is tied to an immutable captured source baseline. `tutorial • tested` means the analytic demonstration works as designed, not that it reproduces a publication model.

## Built-in examples

Each scientific model exposes `default_stride` as an analytic tutorial through the application controller. `tutorial_hopper` exposes `default_hop` and the `demo_hop`/`periodic_hop` problems as the compact reference for generic hybrid events, solve, continuation, and scene rendering. Scientific data is separate: quadruped RoadMap branches, biped GaitMap/trajectory-fit files, and load-pulling `X_accum` datasets live under `examples/data/<model-id>/` with manifests, hashes, source paths, commits, exact dimensions, and redistribution status. Catalogs validate them before use; ordinary runtime never inspects sibling research repositories.

Recommended end-to-end examples are:

- `demo_slip_biped_gaitmap_workflow.m`, `demo_slip_biped_solve.m`, `demo_slip_biped_continuation.m`, and `demo_slip_biped_trajectory_fit.m`
- `demo_slip_quad_load_single_stride.m`, `demo_slip_quad_load_multi_stride.m`, and `demo_slip_quad_load_fit.m`
- `demo_slip_quadruped_roadmap_workflow.m`, `demo_all_scientific_models.m`, and `demo_full_desktop_workflow.m`
- `demo_tutorial_hopper.m` for the complete built-in analytic hybrid/scene workflow
- the eleven Round 9 section, timing, periodic, N-stride, and model-building
  examples listed in the next section
- the Round 10 rectangular timing, timing-family, analytic multiple-shooting,
  heterogeneous-plan, scientific-section, and quad-load horizon examples
  introduced below and in the linked guides

Each is safe to rerun, uses public APIs and repository-contained data, leaves a structured `output`, and prints an exact success marker.

## Poincaré, timing-only, and N-stride workflows

Round 9 separates four operations that are easy to conflate: selecting a
Poincaré section, solving event timing with fixed physical data, enforcing
periodicity, and completing/simulating a stride plan. Start MATLAB in the
repository root and run `startup` once.

Inspect a catalog-driven return and rephase a solved hopper orbit:

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
problem = model.createProblem('periodic_hop',struct());
u = problem.getDecisionSchema().defaults();
p = problem.getParameterSchema().defaults();
context = lmz.api.RunContext.synchronous(901);
evaluation = problem.evaluate(u,p,context,true);
solution = problem.makeSolution(u,p,evaluation);

returned = lmz.services.PoincareReturnService().simulate( ...
    model,solution,struct('StopSectionId','height_descending'),context);
transferred = lmz.services.SectionTransferService().transfer( ...
    model,solution,'height_descending',context);
assert(returned.StopCrossing.Accepted);
assert(transferred.PhaseInvariantObservablesPreserved);
assert(transferred.DecisionCodecRephased);
```

For the built-in tutorial, quadruped, and biped periodic codecs, transfer
constructs a section-configured `periodic_orbit` solution and verifies that a
fresh target-problem evaluation reproduces the transferred trajectory before
setting `DecisionCodecRephased=true`. An external model with an unsupported
decision codec retains `false` and must supply its own rephasing adapter before
continuation. Composite catalog entries are also executable: each must provide
nonempty, safe declarative acceptance conditions in addition to its primary
section, and return/transfer services apply those conditions to every candidate
crossing.

Solve contact timing without changing the initial state or physical
parameters. This is not a periodic-orbit solve:

```matlab
timingProblem = model.createProblem('section_return_timing',struct());
fixedState = timingProblem.FixedInitialState;
fixedParameters = timingProblem.FixedPhysicalParameters;
timing = lmz.services.ContactTimingService().solve( ...
    timingProblem,timingProblem.InputSchedule, ...
    struct('MultistartCount',1,'Display','off'),context);
assert(isequaln(timing.FixedInitialState,fixedState));
assert(isequaln(timing.FixedPhysicalParameters,fixedParameters));
assert(timing.SolverDiagnostics.NoPeriodicityResidual);
```

The tutorial also supports a genuine selected-section timing solve from one
descending-height crossing to the next:

```matlab
descendingProblem = model.createProblem('section_return_timing',struct( ...
    'StartSectionId','height_descending', ...
    'StopSectionId','height_descending'));
descending = lmz.services.ContactTimingService().solve( ...
    descendingProblem,descendingProblem.InputSchedule, ...
    struct('MultistartCount',1,'Display','off'),context);
assert(strcmp(descending.SectionCrossing.SectionId,'height_descending'));
assert(descending.SectionCrossing.Accepted);
assert(descending.FixedInitialState(3) == 0.1);
assert(descending.FixedInitialState(4) < 0);
assert(norm([descending.ContactResiduals;descending.SectionResidual]) < 1e-9);
```

That Round 9 state-plane path is intentionally narrow. Round 10 adds direct,
model-owned section-local codecs/adapters for the scientific combinations each
catalog declares. It does not reinterpret the preserved apex compatibility
oracle as a non-apex solver. Unsupported section sides, occurrences, or
combinations still fail explicitly. Tutorial named-event timing endpoints and
an ambiguous apex-to-descending-height request likewise remain rejected. The
registered tutorial `contact_timing_sequence` problem provides the explicit
N-stride timing-sequence formulation when more than one return is needed.

The load adapter can demonstrate the exact five-stride
`44 + 13*(N-1)` layout by explicitly copying schedules. That is a synthetic
plan-layout demonstration, not a claim that the copied schedules return to the
requested section:

```matlab
loadModel = registry.createModel('slip_quad_load');
catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset = catalog.load(catalog.Manifest.defaultMultiStride);
layoutRequest = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5,'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','carry_forward', ...
    'EnergyNeutralOnly',true,'FailurePolicy','error');
layout = lmzmodels.slip_quad_load.QuadLoadStridePlanBuilder().build( ...
    layoutRequest,context);
xAccum5 = lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(layout.Plan);
assert(layout.CompletedStrideCount == 5);
assert(numel(xAccum5) == 96);
```

Request timing correction separately and retain its structured partial-failure
evidence. On the bundled two-stride seed, the stride-three prediction is
outside the validated correction trust region, so no five-stride simulation is
fabricated:

```matlab
correctedRequest = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5,'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','predictor_corrector', ...
    'EnergyNeutralOnly',true,'FailurePolicy','return_partial');
corrected = lmz.services.MultiStrideSimulationService().simulate( ...
    loadModel,correctedRequest,context);
assert(corrected.Partial && corrected.CompletedStrideCount == 2);
assert(strcmp(corrected.CompletionStatus,'failed'));
assert(isempty(corrected.Simulation));
assert(strcmp(corrected.Failure.Identifier, ...
    'lmz:MultiStride:TimingSeedOutsideTrustRegion'));
```

For optimization with a complete fixed schedule, use the experimental Round 9
`n_stride_fit` problem. Its default is a hash-bound, repository-captured
two-stride fixed-timing seed; objective evaluation performs no timing solve and
the 18 contact/section equations remain explicit constraints:

```matlab
two = loadModel.createProblem('n_stride_fit',struct());
[c2,ceq2] = two.nonlinearConstraints( ...
    two.getDecisionSchema().defaults(), ...
    two.getParameterSchema().defaults(),context);
assert(isempty(c2) && numel(ceq2) == 18);
```

Measurements bundled with the load dataset cover two strides. A repeated
third stride can demonstrate the 70-decision/27-constraint schema, but it is
not a validated timing seed or successful fit. It requires an explicit
synthetic reference policy and is not source-equivalent:

```matlab
threeDecision = [two.SourceDecision; two.SourceDecision(end-12:end)];
three = loadModel.createProblem('n_stride_fit',struct( ...
    'InitialDecision',threeDecision,'NumberOfStrides',3, ...
    'ReferenceExtensionPolicy','repeat_final_reference'));
[objective,terms,diagnostics] = three.evaluateObjective( ...
    three.getDecisionSchema().defaults(), ...
    three.getParameterSchema().defaults(),context);
[~,ceq3] = three.nonlinearConstraints( ...
    three.getDecisionSchema().defaults(), ...
    three.getParameterSchema().defaults(),context);
assert(isfinite(objective) && ~diagnostics.HiddenTimingSolve);
assert(~diagnostics.SourceEquivalent && numel(ceq3) == 27);
```

The source-equivalent `multi_stride_fit` compatibility problem is intentionally
separate: it preserves the exact legacy two-stride timing projection and
reports `HiddenTimingSolve=true`.

The registered `slip_quad_load/n_stride_periodic` problem exposes per-stride
contact blocks, explicit timing variables, and one final-section closure block.
The included public example evaluates that formulation, but does not claim a
converged periodic solution; current one-/two-stride seed experiments have no
convergence evidence suitable for such a claim.

Run the Round 9 examples directly:

```matlab
examplesRoot = fullfile(lmz.util.ProjectPaths.root(),'examples');
run(fullfile(examplesRoot,'demo_custom_poincare_section.m'));
run(fullfile(examplesRoot,'demo_section_transfer.m'));
run(fullfile(examplesRoot,'demo_contact_timing_only.m'));
run(fullfile(examplesRoot,'demo_tutorial_hopper_periodic_continuation.m'));
run(fullfile(examplesRoot,'demo_tutorial_hopper_five_strides.m'));
run(fullfile(examplesRoot,'demo_quadruped_contact_timing.m'));
run(fullfile(examplesRoot,'demo_biped_contact_timing.m'));
run(fullfile(examplesRoot,'demo_quad_load_extend_to_five_strides.m'));
run(fullfile(examplesRoot,'demo_quad_load_n_stride_fit.m'));
run(fullfile(examplesRoot,'demo_n_stride_periodic_orbit.m'));
run(fullfile(examplesRoot,'demo_build_model_end_to_end.m'));
```

Each script creates an isolated temporary output location, returns an `output`
struct, and prints a stable success marker. The full beginner path is in
[getting-started-build-a-model.md](docs/getting-started-build-a-model.md);
section selection, timing, multi-stride planning, and periodic continuation are
covered in [poincare-sections.md](docs/poincare-sections.md),
[contact-timing-solve.md](docs/contact-timing-solve.md),
[multi-stride-planning.md](docs/multi-stride-planning.md), and
[periodic-orbit-and-continuation-tutorial.md](docs/periodic-orbit-and-continuation-tutorial.md).

## Rank-aware timing and multiple shooting

Round 10 removes the old assumption that every timing or shooting problem must
have the same number of residual rows and free variables. It also separates a
long horizon into independently simulated section-to-section segments joined
by explicit interface defects. Start MATLAB in the repository root and run
`startup` before using these workflows.

### Use multiple shooting in the GUI

The GUI is the simplest way to inspect a shooting layout before committing to
a numerical solve. Launch it from the repository root and retain the returned
application object so that a result can later be saved:

```matlab
startup;
app = legged_model_zoo;
```

Use this sequence for a first run:

1. In the header, choose a model and then a registered shooting problem. Start
   with `tutorial_hopper/multiple_shooting`; the scientific choices are
   `slip_quadruped/multiple_shooting`, `slip_biped/multiple_shooting`, and
   `slip_quad_load/multiple_shooting_horizon`. The badge `experimental •
   tested` means that the implementation and its stated evidence are tested;
   it is not a claim that every configuration has a physical root.
2. Open **Solve / Seeds**. Choose **Multiple shooting** for the registered
   homogeneous shooting route, or **Horizon feasibility** when every active
   row is a feasibility condition rather than a periodic-closure claim. Changing
   the mode, section, horizon, mask, or initializer rebuilds the shooting
   problem and clears results that belonged to the previous contract.
3. Set **Start**, **Stop**, **Start side**, **Stop side**, **Direction**, and
   **Min time**. Read the full **Section combination** line before solving:
   `validated` means that this direct adapter/combination has focused test
   evidence, `experimental` means that the route exists without exact-pair
   numerical validation, and `unsupported` means that the requested problem
   must reject it. A validated line may still say `accepted-crossing candidate;
   no root`; pair support and root convergence are different claims. For a
   quadruped or biped mixed pair, select the registered `section_transition`
   problem in the header. For the load model, apex-to-stride-boundary is a
   validated **Contact timings only** route; `multiple_shooting_horizon` is
   homogeneous and requires apex-to-apex or stride-boundary-to-stride-boundary.
4. Set **Formulation**, **Solver**, **Horizon**, and **Tolerance**. **Auto**
   retains `fsolve` for an unbounded square system, selects bounded
   `lsqnonlin` for a square system with finite schema bounds, and selects
   `lsqnonlin` for an overdetermined one. Use explicit **fsolve** only for an
   unbounded square point problem, **lsqnonlin** for least-squares residuals,
   and **Constrained feasibility** when declared nonlinear constraints require
   `fmincon`. The horizon is the
   number of independently evaluated segments; the node count is normally
   `N+1`.
5. In **Event / return**, tick only the event times and final return time that
   may move. In **Interfaces** and **Controls**, enter `all`, `none`, or a
   comma- or space-separated binary mask such as `1,0,0,1`. A one-row mask is
   repeated across the applicable nodes or segments. For the load model, the
   apex section has exactly 14 interface coordinates:
   `quad_dx`, `quad_y`, `quad_phi`, `quad_dphi`, the eight leg angle/rate
   coordinates, `load_x`, and `load_dx`. The stride-boundary section has 15
   because `quad_dy` is also present. Therefore use 14 values for apex and 15
   for stride boundary; a flattened `(N+1)`-node mask is also accepted. Load
   controls have four post-swing stiffness entries per stride. A mask-length
   error is a configuration error, not numerical evidence about the model.
6. Choose an **Initializer**. Non-load models expose **Schema defaults**. The
   load choices map to real template/strategy IDs: **TR to RL source** =
   `individual_1_tr_to_rl`, **Identical TR to RL source** =
   `individual_1_identical_tr_to_rl`, **TR to TL source** =
   `individual_1_tr_to_tl`, **Single TR source** =
   `individual_1_tr_single`, and **Repeat previous compatible stride** =
   `phase_compatible_repeat`. A source template is loaded only after its
   repository manifest SHA-256 passes. The shooting artifact records the
   selected repository-relative template path/hash, any evidence path/hash
   declared by a replay configuration, the initializer lineage, and the
   problem-configuration hash; reproduction verifies them again. These hashes
   establish identity, not redistribution permission.
7. Choose **Energy** deliberately. **Diagnostic only** records the measured
   energy/work mismatch without adding an active row. **Energy neutral** adds
   a zero-change row. **Prescribed work** adds `delta-energy - declared-work`,
   while **Bounded work** adds only excess beyond the declared absolute bound.
   The GUI uses the problem's current declared-work value; set a nonzero value
   through the programmatic configuration when a study requires one.
8. Press **Evaluate** to inspect the current seed without correction, then
   **Solve/refine** to create a `ShootingResult`. The diagnostics table reports
   segments, nodes, unknown/residual dimensions, rank/nullity, condition,
   scaled residual, termination, smallest singular values, and contact,
   interface, section, and energy/work norms. The plot overlays contact,
   interface-defect, section, energy/work, named section-coordinate-defect,
   schedule, control, and solver-residual-history profiles; exact values remain
   in the table. A green `root_found` or `least_squares_feasible` requires the
   full residual and physical contract. A positive solver exit flag alone
   never establishes success.

**Simulate solved** is intentionally disabled in **Multiple shooting** and
**Horizon feasibility**. Their catalog capability is `simulate=false`: a run
may retain independently evaluated segment data, but it does not promise one
assembled public `SimulationResult`, and a failed or partial horizon is never
filled with a synthetic trajectory. Use a separate simulation-capable problem
only when its own input contract has been satisfied.

After a GUI solve, save and verify the exact hash-bound run programmatically:

```matlab
shooting = app.Controller.State.ShootingResult;
assert(~isempty(shooting));

artifactPath = [tempname '.lmz.mat'];
lmz.io.ArtifactStore.save(artifactPath, shooting.toArtifact());
[reproduced, verification] = lmz.services.reproduceRun(artifactPath);

assert(isa(reproduced, 'lmz.shooting.ShootingResult'));
assert(strcmp(verification.ArtifactType, 'multiple-shooting-run'));
```

Horizon growth is a separate programmatic operation because it changes the
decision schema. This complete tutorial creates a deliberately interrupted
adaptive step, then resumes its exact problem-and-anchor-bound checkpoint:

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
problemId = 'multiple_shooting';
targetConfiguration = struct('HorizonLength', 3);
problem = model.createProblem(problemId, targetConfiguration);
anchor = problem.getDecisionSchema().defaults();
names = problem.getDecisionSchema().names();
anchor(strcmp(names, 'node_2_y')) = 1.1;
context = lmz.api.RunContext.synchronous(2104);

homotopyOptions = struct( ...
    'ResidualTolerance', 1e-8, ...
    'HomotopyInitialStep', 0.4, ...
    'HomotopyMaximumStep', 0.5, ...
    'HomotopyMinimumStep', 0.01, ...
    'HomotopyMaximumAttempts', 1, ...
    'Display', 'off');
partial = lmz.shooting.HorizonContinuation().traceHomotopy( ...
    problem, anchor, homotopyOptions, context);
assert(~partial.Completed);
checkpoint = partial.Checkpoints{end};

homotopyOptions.HomotopyMaximumAttempts = 50;
resumed = lmz.services.HorizonContinuationService().resumeHomotopy( ...
    model, problemId, targetConfiguration, anchor, checkpoint, ...
    homotopyOptions, context);
assert(resumed.Completed && resumed.Lambda == 1);
```

Do not edit a checkpoint to make it fit a new run. `resumeHomotopy` rejects a
changed problem contract, anchor, decision dimension, incompatible framework,
or stale hash. Resume the original step first, then use the named
`embedDecision`/`HorizonContinuationService.run` path for a new horizon.

When a run does not succeed, interpret the classification before changing the
solver: `best_known_residual` is an evaluated local candidate above tolerance;
`local_infeasibility_evidence` summarizes a bounded local search and is not a
global certificate; `physical_validation_failure` failed a crossing, event,
finite-state, or energy/work check; and `numerical_failure` means solver
termination was not acceptable even when the retained candidate is finite or
passes separate physical checks. `unsupported`, invalid mask, and checkpoint-
hash errors instead describe an invalid or stale configuration and should be
corrected, not counted as failed root searches.

### Solve an overdetermined timing problem

This tutorial keeps one timing variable and includes both its free and fixed
contact rows, producing a two-row/one-unknown least-squares problem:

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
configuration = struct( ...
    'FixedEventMask',true, ...
    'FreeReturnTime',true, ...
    'FixedRowPolicy','include_fixed_rows_in_least_squares', ...
    'FixedRowTolerance',1e-9, ...
    'StartSectionId','apex','StopSectionId','apex');
problem = model.createProblem('section_return_timing',configuration);
context = lmz.api.RunContext.synchronous(1016);
timing = lmz.services.ContactTimingService().solve( ...
    problem,problem.InputSchedule,struct( ...
    'Solver','lsqnonlin','Display','off', ...
    'ResidualTolerance',1e-9),context);

rank = timing.SolverDiagnostics.RankDiagnostics;
assert(rank.M == 2 && rank.N == 1 && rank.Rank == 1);
assert(timing.SolverDiagnostics.Feasibility.FixedRowsValid);
```

`Solver='auto'` selects `fsolve` when `m == n` and the decision schema is
unbounded, bounded `lsqnonlin` when a square schema has finite bounds, and
`lsqnonlin` when `m > n`. An `m < n` point solve is rejected until independent gauges make it
well posed. If the intended object is a regular one-dimensional family, use a
`TimingFamilyProblem`, verify `n-rank(J)=1`, and trace it with
`TimingContinuationService`; do not add a hidden arbitrary equation merely to
make the system square. Fixed rows remain physical checks under
`validate_fixed_rows`, become active least-squares rows under
`include_fixed_rows_in_least_squares`, and are retained as explicitly
qualified diagnostics only under `diagnostic_only`.

For an ordinary square timing problem, rank is a uniqueness diagnostic rather
than an automatic existence veto. A physically valid, tolerance-satisfying
root may report `RankConditionRequired=false`, `UniquenessValidated=false`,
and `RankQualification='rank_deficient_root_not_a_unique_parameterization'`;
describe it as a root, not as a locally unique timing parameterization. A
declared timing family still must satisfy its expected nullity and gauge-
independence contract.

### Solve a two-segment periodic orbit

The built-in analytic hopper registers a complete multiple-shooting problem:

```matlab
problem = model.createProblem('multiple_shooting',struct( ...
    'HorizonLength',2,'Formulation','periodic', ...
    'ResidualTolerance',1e-8));
seed = problem.ShootingSchema.defaults();
shooting = lmz.services.MultipleShootingService().solve( ...
    problem,seed,struct('Solver','auto','Display','off', ...
    'ResidualTolerance',1e-8),context);

report = shooting.FeasibilityReport;
assert(report.Success);
assert(strcmp(report.Classification,'root_found'));
assert(shooting.Horizon.segmentCount() == 2);
assert(max(shooting.SolveResult.Evaluation.Diagnostics. ...
    InterfaceDefectNorms) <= 1e-8);
```

Each segment is simulated once per residual evaluation. Contact, selected-
section, interface-defect, energy/work, and final closure/target rows stay
separate in the diagnostics. Periodic closure appears only at the final
section; intermediate nodes are connected by interface defects rather than
independent periodicity equations.

The scientific quadruped and biped expose the same registered problem ID using
their direct touchdown-section adapters:

```matlab
scientific = registry.createModel('slip_quadruped');
problem = scientific.createProblem('multiple_shooting',struct( ...
    'HorizonLength',2,'InterfaceStateMask',false, ...
    'EventFreeMask',[false true], ...
    'ControlFreeMask',false,'EnergyWorkMode','diagnostic_only'));
```

For the default evidence configuration (fixed endpoint nodes and schedules,
free interior node), executed N=2 solves are rectangular
`least_squares_feasible`: quadruped `m=55`, `n=13`, rank 13, nullity 0,
maximum scaled residual `1.318856135412716e-11`; biped `m=29`, `n=7`, rank 7,
nullity 0, maximum scaled residual `3.979039320256561e-13`. Both evaluate two
direct segments with `ApexOracleUsed=false`; neither result is a repeated
one-stride simulation or a square-system `root_found` claim. A true
`ControlFreeMask` is rejected because these section adapters expose fixed
controls, not control decision coordinates. See
[docs/multiple-shooting.md](docs/multiple-shooting.md) for mask shapes,
classification, and reproduction details.

For different start and stop section IDs, use the separate registered
`section_transition` problem. It performs one direct section-aware segment and
compares the terminal node with an explicit target; it never labels the mixed
endpoints as periodic closure:

```matlab
transition = scientific.createProblem('section_transition',struct( ...
    'StartSectionId','back_left_touchdown', ...
    'StopSectionId','descending_y_0_9', ...
    'StartStateFreeMask',true, ...
    'TargetStateFreeMask',true, ...
    'EventFreeMask',false));
u0 = transition.getDecisionSchema().defaults();
p = transition.getParameterSchema().defaults();
evaluation = transition.evaluate(u0,p,context,false);
direct = transition.evaluateShooting(u0,p,context,false);

assert(strcmp(transition.Formulation,'transition'));
assert(~transition.Horizon.Target.PeriodicClosure);
assert(evaluation.PhysicalValidity);
assert(direct.SegmentResults{1}.Crossing.Accepted);
assert(~direct.SegmentResults{1}.Diagnostics.ApexOracleUsed);
```

The quadruped and biped catalogs cover named-event → named-event, named-event
→ descending state-plane, descending state-plane → named-event, and safe
composite targets. Some tested default seeds are accepted physical crossings
but retain nonzero contact residuals; those are reported as candidates, not
roots. See
[scientific-section-shooting.md](docs/scientific-section-shooting.md) for the
exact dimensions, residuals, target blocks, and supported pairs.

Always branch on `FeasibilityReport.Success`, not only on a solver exit flag.
The exact result vocabulary is `root_found`, `least_squares_feasible`,
`best_known_residual`, `local_infeasibility_evidence`, `numerical_failure`, and
`physical_validation_failure`. A bounded or multistart search with no accepted
candidate is local evidence; it does not prove global nonexistence. Report the
sections/sides, bounds, seeds, tolerances, residual blocks, event/crossing and
energy checks, rank/nullity, singular values, termination reason, and whether
any rigorous certificate exists.

### Continue horizons and run heterogeneous plans

`HorizonContinuationService` accepts an explicit configuration sequence and
maps retained decision values by name when growing from `N` to `N+1`. It
records added/removed variables, initializer history, every feasibility report,
and a resumable checkpoint; by default it stops at the first qualified failure
and preserves the strongest completed result. It never fills a failed physical
horizon with a synthetic trajectory. The existing quad-load continuation
example also uses `ContinuationService` on a fixed N=2 multiple-shooting chart:
an explicit 46-to-47 embedding frees only
`segment_2_post_swing_1`, then a rank-46/nullity-one seed pair traces three
physical points while all branch decisions remain 47-dimensional. The output
and artifact record the selected stiffness, configuration, parameter values,
chart hash, physical checks, and history. This diagnostic-only local N=2
transition family is not an N=2 periodic, energy-neutral, N=3, or N=5 claim.

Native `StridePlan` execution can also use different schedules and allowed
controls on each stride. The hopper accepts distinct impact/return schedules and
impulses. The quadruped and biped directly integrate explicit non-apex,
same-section returns, consume `StrideSpec.InitialSectionState` (or the previous
terminal state), and report applied schedules/controls, interface defects,
contact and section residuals, accepted crossings, and per-stride energy
diagnostics. Their physical parameters remain invariant; quadruped controls are
limited to `k_leg`, `k_swing`, and `k_r_leg`, while biped controls are limited
to `k_leg` and `omega_swing`. Mixed endpoints require transition multiple
shooting. Choose an energy policy explicitly: the biped measures its source
`total_energy`; changed quadruped controls require `allow_non_neutral` because
that source exposes no total-energy channel. The homogeneous
`Provenance.PeriodicDecision` fast path remains source-equivalent. See
[docs/multi-stride-planning.md](docs/multi-stride-planning.md) for the complete
two-stride construction and diagnostics contract.

Run the four generic Round 10 examples directly:

```matlab
examplesRoot = fullfile(lmz.util.ProjectPaths.root(),'examples');
run(fullfile(examplesRoot,'demo_rectangular_contact_timing.m'));
run(fullfile(examplesRoot,'demo_timing_family_continuation.m'));
run(fullfile(examplesRoot,'demo_multiple_shooting_tutorial.m'));
run(fullfile(examplesRoot,'demo_heterogeneous_stride_plan.m'));
```

Run the section-local and quad-load evidence examples separately:

```matlab
run(fullfile(examplesRoot,'demo_quadruped_touchdown_periodic_orbit.m'));
run(fullfile(examplesRoot,'demo_biped_touchdown_timing.m'));
run(fullfile(examplesRoot,'demo_scientific_state_plane_shooting.m'));
run(fullfile(examplesRoot,'demo_quad_load_template_library.m'));
run(fullfile(examplesRoot,'demo_quad_load_three_stride_feasibility.m'));
run(fullfile(examplesRoot,'demo_quad_load_five_stride_horizon.m'));
run(fullfile(examplesRoot,'demo_quad_load_horizon_continuation.m'));
run(fullfile(examplesRoot,'demo_quad_load_n2_periodic_solve.m'));
```

Each Round 10 example writes only beneath a temporary output directory, leaves
a structured `output`, and prints an exact script-success marker. For a
qualified horizon example, that marker means the expected evidence and
classification were reproduced; it does not turn `physical_validation_failure`
or `numerical_failure` into a root or a physical five-stride simulation.

The mathematical layout, service contracts, artifact/reproduction routes,
classification rules, and reporting checklist are in
[multiple-shooting.md](docs/multiple-shooting.md),
[horizon-feasibility.md](docs/horizon-feasibility.md),
[contact-timing-solve.md](docs/contact-timing-solve.md), and
[multi-stride-planning.md](docs/multi-stride-planning.md). The supported direct
scientific combinations, rank-deficient/non-unique quadruped timing
qualification, and unchanged apex oracles are in
[scientific-section-shooting.md](docs/scientific-section-shooting.md). The
template inventory, actual N=2/N=3 searches, failed N=3-to-N=5 growth, and exact
local qualifications are in
[quad-load-horizon-continuation.md](docs/quad-load-horizon-continuation.md).

## Command-line quick start

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
fprintf('Framework %s, artifact schema %s\n', ...
    lmz.util.Version.current(), lmz.util.Version.artifactSchemaVersion());
modelIds = registry.listModels()
```

The deterministic result is:

```text
slip_biped
slip_quad_load
slip_quadruped
tutorial_hopper
```

Create a model only from an ID returned by this registry. Query its catalog manifest and advertised capabilities before choosing a service:

```matlab
modelId = 'tutorial_hopper';
manifest = registry.getManifest(modelId);
capabilities = registry.getCapabilities(modelId);
model = registry.createModel(modelId);
problemIds = model.listProblems()
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

The analytic hybrid hopper uses the same services and returns named modes plus pre/post-reset event records:

```matlab
hopper = registry.createModel('tutorial_hopper');
hop = hopper.createProblem('demo_hop', struct());
context = lmz.api.RunContext.synchronous(17);
simulation = lmz.services.SimulationService().simulate( ...
    hop, struct(), struct(), context);
disp(simulation.EventRecords);
```

Executable examples:

- `examples/demo_slip_biped.m`
- `examples/demo_slip_quadruped.m`
- `examples/demo_slip_quad_load.m`
- `examples/demo_tutorial_hopper.m`

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

The store validates schema identity, dimensions, finite values, per-problem maturity/validation metadata, lineage, random seed, source commits, and version metadata before an atomic rename. Prefer a new output filename and keep the source artifact until the new file has loaded successfully.

Solve, continuation, and optimization results can be stored as reproducible run artifacts. The run record includes the exact options, source seed or pair, random seed, framework/model/problem versions, MATLAB/toolbox environment, termination data, warnings, and built-in source/data hashes:

```matlab
runPath = fullfile(tempdir, 'quadruped-solve-run.lmz.mat');
lmz.io.ArtifactStore.save(runPath, solveResult.toArtifact());
[reproduced, reproduction] = lmz.services.reproduceRun(runPath);
assert(reproduction.UnresolvedHashCount == 0);
```

`reproduceRun` supports `solve-run`, `continuation-run`, and `optimization-run`. It rejects incompatible versions and stale verified built-in hashes, reconstructs recorded options and lineage exactly, and then invokes the normal public service. Floating-point equality remains subject to the documented solver/platform tolerance; an external source path that cannot be verified is reported rather than silently treated as verified. See [the artifact reference](docs/artifact-reference.md).

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

For fixed, precompleted schedules beyond the measured two-stride load data,
use the separate experimental `slip_quad_load/n_stride_fit` problem. It has no
hidden timing solve, requires a complete plan/vector, and requires the explicit
`repeat_final_reference` policy when the requested stride count exceeds the
measured reference. That synthetic extension is never described as
source-equivalent.

Additional compatibility examples remain available (`demo_slip_biped_fit.m`, `demo_slip_quadruped_solve.m`, `demo_slip_quadruped_continuation.m`, and `demo_full_gui_workflow.m`), while the Round 6 scientific examples listed above are the recommended entry points.

## Visualization, animation, and recording

Every renderer consumes the same named `SimulationResult` boundary. The three
scientific models provide compound research renderers as well as deliberately
simplified clean renderers. `tutorial_hopper` demonstrates the generic
declarative `SceneSpec`/`SceneRenderer2D` path. Scene JSON describes only the
allowlisted ground, polygon, marker, line, spring, rope, force-vector, trail,
and text primitives; it cannot evaluate MATLAB expressions.

`AnimationController` owns normalized-time scrubbing, FPS/speed/loop playback,
and Play/Pause/Stop/Reset. Renderers only build axes-owned handles and update a
requested frame. Plot providers expose the model's named analysis views.
`RecorderService` exports GIF, MP4 where `VideoWriter` supports it, PNG/PDF
keyframes and plots, and animated axes through atomic temporary files; it
restores the displayed frame and closes resources on success, cancellation,
or error. Model authors should follow [the visualization authoring
guide](docs/visualization-authoring.md) instead of adding model-ID conditionals
to generic GUI code.

## Research Graphics Profiles

Graphics are selected per problem through the model-owned
`graphics.lmz.json`, `VisualizationProfileRegistry`, and `RendererFactory`.
The scientific maturity label and graphics profile answer different questions:
`source-equivalent` describes the problem's numerical validation, while
`research_legacy` describes a source-derived graphics implementation. Neither
label by itself is a blanket claim that every exported pixel is identical to an
upstream screenshot.

| Problem group | Default visual profile |
| --- | --- |
| `slip_quadruped/periodic_apex` | `research_legacy` |
| `slip_biped/periodic_apex`, `slip_biped/trajectory_fit` | `research_legacy` |
| `slip_quad_load/single_stride`, `slip_quad_load/multi_stride_fit` | `research_legacy` |
| The three scientific models' `demo_stride` problems | `clean_generic` |
| `tutorial_hopper/demo_hop`, `tutorial_hopper/periodic_hop` | `clean_generic` |

The available choices mean:

- **Research legacy** uses the source-derived compound body, limb, spring,
  COM/COG, ground, load/rope, camera, and layer geometry implemented for the
  applicable validated scientific problems. It does not copy the old figure,
  path setup, playback loop, or video-writer ownership into a renderer.
- **Clean generic** uses the declarative scene or the model's simple clean
  renderer. Its straight links and compact markers are intentional and are not
  presented as source-faithful scientific graphics.
- **High contrast** is an accessibility adaptation. For the scientific models
  it retains the compound research renderer when the profile is applicable but
  deliberately changes colors and line widths. The profile dropdown only lists
  choices allowed for the selected problem maturity.

To use a profile in the GUI:

1. Select the model and problem, then open **Physical Simulation**.
2. Choose **Research legacy**, **Clean generic**, or **High contrast** from
   **Visual profile**. The choice is stored separately for each model/problem.
3. Use **Detailed**, **Ground**, **Forces**, and **Follow** where the selected
   renderer supports them. **Reset camera** restores that profile's camera.
4. Simulate or record. Switching profile safely replaces the renderer and the
   animation GIF, MP4, or keyframes use the renderer currently displayed.

The header's high-contrast application palette affects GUI chrome. The
**High contrast** visual profile is the separate model-graphics choice above.

For a short programmatic scientific session, use the public example helper:

```matlab
startup;
session = lmz.examples.ResearchGraphics.open( ...
    'slip_quadruped', 'research_legacy', 'off');
cleanup = onCleanup(@() lmz.examples.ResearchGraphics.close(session));

index = 1 + round(0.5 * (session.Renderer.frameCount() - 1));
session.Renderer.updateFrame(index);
imageData = session.Renderer.captureFrame();
```

The ready-to-run examples are:

```matlab
examplesRoot = fullfile(lmz.util.ProjectPaths.root(), 'examples');
run(fullfile(examplesRoot, 'demo_quadruped_research_graphics.m')); % body/legs/COM/phase
run(fullfile(examplesRoot, 'demo_biped_research_graphics.m'));     % body/COG/contact legs
run(fullfile(examplesRoot, 'demo_quad_load_research_graphics.m')); % quadruped/load/rope
run(fullfile(examplesRoot, 'demo_visual_profile_switching.m'));    % one frame, 3 profiles
run(fullfile(examplesRoot, 'demo_research_graphics_recording.m')); % GIF plus metadata
run(fullfile(examplesRoot, 'demo_graphics_comparison_gallery.m')); % 27 frames, 3 reports
```

These scripts use repository-contained simulations and fixtures. The gallery
does not place a source checkout on the MATLAB path and does not contain or
write source-derived comparison rasters; source recapture is a separate
maintainer-only workflow described in
[the comparison evidence guide](docs/graphics-comparison/README.md).

For an already computed `simulation`, the lower-level public route is:

```matlab
registry = lmz.registry.ModelRegistry.discover();
registryCleanup = onCleanup(@() delete(registry));
profileRegistry = lmz.viz.VisualizationProfileRegistry(registry);
factory = lmz.viz.RendererFactory(registry, profileRegistry);
figureHandle = figure;
figureCleanup = onCleanup(@() delete(figureHandle));
axesHandle = axes('Parent', figureHandle);
options = struct('ShowForces', false, 'DetailedOverlay', true, ...
    'GroundVisible', true, 'CameraFollow', true, ...
    'GroundStyle', 'hatched', 'Palette', 'research_legacy');
[renderer, profile] = factory.createRenderer(axesHandle, simulation, ...
    'slip_quadruped', 'periodic_apex', 'research_legacy', options);
rendererCleanup = onCleanup(@() delete(renderer));
```

Pass profile metadata when recording outside the GUI. This creates the GIF and
an adjacent `research-animation.gif.lmz.json` sidecar:

```matlab
target = fullfile(tempdir, 'research-animation.gif');
metadata = struct('schemaVersion', '1.0.0', ...
    'modelId', 'slip_quadruped', 'problemId', 'periodic_apex', ...
    'visualizationProfile', profile.toStruct());
lmz.services.RecorderService().recordGif(renderer, target, ...
    struct('FrameCount', 40, 'DelayTime', 0.04, ...
    'Metadata', metadata));
```

The GUI adds this profile sidecar for animation GIF, MP4, keyframe, static-plot,
and oscillator-GIF exports. It also maps the profile's `frameCount`, `fps`, and
`dpi` defaults into the applicable recording request; an explicit GUI/request
option takes precedence. Direct `RecorderService` callers must supply
`Metadata` explicitly and pass any desired operational overrides because the
service receives a renderer, not a profile registry; otherwise its own defaults
apply.

Source-derived numeric geometry is kept in pure providers and checked against
repository fixtures under `tests/fixtures/graphics`; the corresponding tests
are under `tests/visualization`. The detailed file/formula map and intentional
deviations are in [the legacy graphics audit](docs/legacy-graphics-audit.md).
Portable image-metric helpers and hidden rendering do not substitute for human
approval. The desktop side-by-side graphics review remains a separate manual
gate, and [the test status](docs/TEST_STATUS.md) is authoritative for the latest
executed evidence.

Graphics retain the project's R2019b design target, but R2019b graphics runtime
has not been executed. Current R2019b evidence is static/fallback auditing only;
the recorded runtime and hidden-render evidence comes from the documented
R2025b environment.

## Artifact format

Supported artifact types include `solution`, `branch`, `simulation`, `solve-run`, `continuation-run`, `optimization-run`, `checkpoint`, and `branch-family-report`. New artifacts use artifact schema `1.0.0`, the current framework version, canonical model/problem identities and versions, and the declared minimum MATLAB release. Live handles, function handles, model objects, and callbacks are never the public serialization format.

Treat JSON, MAT files, and external plugins as inputs with different trust levels. Catalog and scene JSON are bounded declarative data, canonicalized inside an approved root, and never evaluated. `ArtifactStore` accepts only the expected bounded plain-data graph; do not use arbitrary `load` calls as an artifact inspector. MATLAB may deserialize a nested object before recursive validation can reject it, so this validation boundary is not a malware sandbox for an untrusted MAT file. External plugin roots contain executable MATLAB code and must be reviewed before explicit registration. See [SECURITY.md](SECURITY.md) and [the configuration reference](docs/configuration-reference.md).

## Legacy MAT import/export

Three model-specific adapters isolate all legacy indexing:

- `Results29Adapter` maps quadruped 29-row `results` matrices to 22 decisions plus seven parameters.
- `Results14Adapter` maps biped 14-row `results` matrices to 12 decisions plus two offsets.
- `XAccumAdapter` maps load decisions with exact length `44 + 13*(N-1)` and explicit first-/later-stride groups.

Each native point retains file/column/hash provenance, schema metadata, classification/observables, and problem maturity. Native artifacts are preferred when their recorded source digest is current; maintainers can explicitly reimport legacy MAT. Encoding unchanged data reconstructs Results29, Results14, or `X_accum` without numerical change. Deprecated model IDs remain read-only import aliases; new artifacts use canonical IDs.

## Adding a new model

The recommended starting point is the inactive external-model generator. It writes outside the production catalog by default and refuses reserved IDs, path traversal, collisions, or accidental production activation:

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(), 'tools'));
pluginRoot = fullfile(tempdir, 'my_lmz_plugin');
if exist(pluginRoot, 'dir') ~= 7
    mkdir(pluginRoot);
end
report = new_model('example_hopper', pluginRoot);
```

`new_model` defaults to `AuthoringRoute='minimal_simulation'`. To scaffold the
optional registered periodic-branch resources as well, use the exact scientific
route ID:

```matlab
report = new_model('example_hopper', pluginRoot, ...
    'AuthoringRoute', 'scientific_periodic_branch');
```

The generated project contains a model package, model/problem manifests, state/parameter/decision schemas, an analytic periodic problem, a plot plugin and scene, a test, an executable example, and `plugin.json`. It is not automatically added to the built-in registry. Review the generated executable MATLAB code, then register exactly that trusted root:

```matlab
pluginRegistry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
    pluginRoot, 'IncludeBuiltIns', false);
pluginModel = pluginRegistry.createModel('example_hopper');
results = runtests(fullfile(pluginRoot, 'tests', 'generated'), ...
    'IncludeSubfolders', true);
assert(~any([results.Failed]));
delete(pluginRegistry);  % releases the temporary plugin path lease
```

For a maintained built-in model, add a package below `models/+lmzmodels`, implement `lmz.api.LeggedModel`, and add `catalog/<model-id>/manifest.json`, one descriptor per problem, and a scene only when visualization is enabled. The catalog ID/directory, implementation identity/version, maturity, validation status, and capabilities must agree. Numerical problems expose named schemas and `ProblemEvaluation`/objective terms; model code never calls GUI widgets or generic solvers directly. Legacy matrix indexing belongs in one adapter, and scientific claims require immutable source provenance, hashes, baselines, and separate source-equivalence tests.

There are two exact authoring routes. `minimal_simulation` needs only the model/problem/schema/scene contracts above and receives the generic classic-tabs presentation. `scientific_periodic_branch` additionally provides a model-owned branch `DataSourceProvider`, branch-catalog and legacy-adapter provider templates, `data_sources.lmz.json`, `workbench.lmz.json`, a registered workflow preset/example/test, and the manifest bindings for branch source, root problem, second-seed policy, continuation defaults, provenance, and visualization/analysis views. The external analytic-hopper fixture proves that a complete provider/workflow appears through the scoped plugin registry and disappears when that registry is deleted, with no core edit.

Start with [the model-author guide](docs/model-author-guide.md), then use the [registered-workflow guide](docs/registered-workflows.md), [configuration reference](docs/configuration-reference.md), [service API](docs/service-api.md), [visualization guide](docs/visualization-authoring.md), [artifact reference](docs/artifact-reference.md), and [model testing checklist](docs/testing-a-model.md). The built-in `tutorial_hopper` and the isolated `tests/fixtures/external_plugins/analytic_hopper` fixture are executable examples of generic hybrid, event/reset, solve, continuation, registered data/workbench/workflow, scene, artifact, GUI-capability, discovery, and clean-removal integration without any `src/+lmz` modification.

## Testing

Start a fresh MATLAB session in the repository root. The canonical local gate is:

```matlab
startup;
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Its unattended batch equivalent is:

```bash
matlab -batch "cd('/path/to/Legged_Model_Zoo'); results=run_tests; assert(~any([results.Failed]));"
```

Run every top-level public example separately. The clean-copy all-scientific-model gate is the integration test below; it copies the repository and launches an unrelated child MATLAB process rather than merely rerunning the current checkout:

```matlab
startup;
toolsPath = fullfile(lmz.util.ProjectPaths.root(), 'tools');
addpath(toolsPath);
exampleReport = run_public_examples;
isolationResults = runtests(fullfile( ...
    lmz.util.ProjectPaths.tests(), 'integration', ...
    'TestStandaloneAllScientificModels.m'));
assert(~any([isolationResults.Failed]));
assert(~any([isolationResults.Incomplete]));
```

Documentation, architecture, static R2019b-target, redistribution, and code-quality checks are available independently for faster feedback:

```matlab
check_readme_contract;
architectureViolations = static_architecture_check( ...
    lmz.util.ProjectPaths.root());
assert(isempty(architectureViolations));
[compatibilityViolations, compatibilityReport] = ...
    check_matlab_compatibility(lmz.util.ProjectPaths.root());
assert(isempty(compatibilityViolations));
qualityReport = run_code_quality(lmz.util.ProjectPaths.root());
assert(isempty(qualityReport.Violations));
addpath(fullfile(lmz.util.ProjectPaths.root(), 'tools', 'release'));
redistributionReport = scan_redistribution;
```

The registry-derived model/problem tables in this README are generated content. After an intentional catalog change, regenerate and immediately validate them:

```matlab
generate_readme_tables(true);
check_readme_contract;
```

Run the measured performance gate from a fresh process. `GateOnly=true` is the routine budget check; omit it for the complete release profile and use at least three repetitions:

```matlab
addpath(fullfile(lmz.util.ProjectPaths.root(), 'benchmarks'));
quickPerformance = run_benchmarks(struct( ...
    'Repetitions', 1, 'GateOnly', true));
fullPerformance = run_benchmarks(struct( ...
    'Repetitions', 3, ...
    'OutputPath', fullfile(tempdir, 'lmz-benchmarks.json')));
round11Performance = run_round11_workbench_benchmarks(struct( ...
    'Repetitions', 3, ...
    'OutputPath', fullfile(tempdir, 'lmz-round11-workbench.json')));
```

The retained Round 11 reports are
`benchmarks/round11_full_matrix_r2025b_macos_arm64.json` and
`benchmarks/round11_r2025b_macos_arm64.json`. Their 29 and 10 records each use
three repetitions and have zero median budget overruns.

On MATLAB R2023a or newer, collect statement coverage for every runtime MATLAB file below `src/+lmz` and `models/+lmzmodels`, and enforce the measured stable-package policy when it is present:

```matlab
[coverageReport, coverageResults] = run_coverage(struct( ...
    'OutputPath', fullfile(tempdir, 'lmz-coverage.json'), ...
    'EnforceBaseline', true));
assert(~any([coverageResults.Failed]));
assert(~any([coverageResults.Incomplete]));
```

The MATLAB-free CI equivalent validates JSON, README/architecture contracts, the static compatibility rules, release-inventory completeness/hashes, and whitespace:

```bash
python3 tools/ci/static_checks.py --all
git diff --check
```

Release commands are authorization gates, not instructions to bypass licensing. These commands scan the current inventory and report both profiles without retaining a package:

```matlab
addpath(fullfile(lmz.util.ProjectPaths.root(), 'tools', 'release'));
scan = scan_redistribution;
coreDryRun = build_release('core', struct('DryRun', true));
scientificDryRun = build_release('scientific', struct('DryRun', true));
coreToolboxDryRun = build_toolbox('core', struct('DryRun', true));
scientificToolboxDryRun = build_toolbox( ...
    'scientific', struct('DryRun', true));
```

Maintainers may exercise deterministic ZIP or `.mltbx` construction with `Mode='technical-validation'` and `RunInstallTest=true`. That mode labels the package `NOT_FOR_REDISTRIBUTION`, tests registry discovery, the permitted tutorial workflow, hidden GUI construction, artifact round trip, and path removal in an unrelated temporary MATLAB process, and deletes the package before returning. Only `Mode='public'` can retain output, and it fails before writing when the profile or project decision is unresolved. Do not edit decision fields or add a root license without owner-supplied authority. See [release/README.md](release/README.md), [docs/CI.md](docs/CI.md), [the benchmark guide](benchmarks/README.md), [the coverage policy](docs/COVERAGE.md), and [docs/TEST_STATUS.md](docs/TEST_STATUS.md).

The final Round 8 R2025b suite completed `275 run, 0 failed, 0 incomplete`.
The separate example gate passed all 31 public examples, including a 27-frame
three-model/three-profile graphics gallery, and the clean-copy child process
rendered and captured `research_legacy` for all three scientific models without
a sibling source repository path. The measured Round 7 starting coverage was
7,401 of 9,792 runtime statements (75.5821%) across 174 files. The final Round
8 coverage run passed all 275 tests and covered 9,601 of 12,546 statements
(76.5264%) across 204 files while enforcing every stable-package floor. The
pre-edit scientific baseline was `117 run, 0 failed, 0 incomplete`; it remains
an explicit non-regression floor. See [the coverage policy](docs/COVERAGE.md)
and [the test status](docs/TEST_STATUS.md) for the exact qualification.

## Troubleshooting

- **Undefined `lmz` package:** run `startup` from the repository root.
- **GUI cannot construct or display:** first verify the locally tested R2025b environment and graphics availability. R2019b is only a static compatibility target until runtime evidence exists.
- **GUI layout/palette is stale:** choose **Reset preferences** in the header or call `app.resetPreferences()`. This clears the versioned window/palette/recent-folder preferences, not model data.
- **Solver controls fail:** verify Optimization Toolbox is licensed and the selected model advertises the requested capability.
- **A service button is disabled:** inspect the problem badge/capabilities; simulation, solve, continuation, homotopy, and optimization are advertised per problem rather than inferred from the model name.
- **Artifact uses an old model ID:** load it to migrate the ID, then save a new canonical artifact.
- **Run reproduction reports an unresolved hash:** restore the recorded built-in source/data file or register the reviewed external plugin root explicitly; do not replace the expected digest by hand.
- **External model is not discovered:** confirm the reviewed root contains `plugin.json`, `models`, and `catalog`, then keep the registry returned by `discoverWithPlugins` alive for as long as its path lease is needed.
- **Cyclic time rejected:** its named period must be finite and positive.
- **Homotopy parameter disabled:** the parameter is marked inactive because the migrated equations do not use it; choose an active field such as quadruped `k_leg`.
- **Bounded fit returns exit flag 0:** inspect objective decrease and solver diagnostics; the documented one-iteration load fit is intentionally budget-limited.
- **MAT/JSON input is rejected:** inspect the named schema/type/dimension/path/hash error. Do not weaken the safe loader or deserialize untrusted files with a general `load` call.
- **Preparing a public package:** stop and resolve every pending row in `docs/REDISTRIBUTION_STATUS.md`; local migration authorization and a successful technical-validation build are not redistribution licenses.
- **CI files exist but no check is visible:** the workflows still need to be pushed and run on GitHub. Local-equivalent success is not remote CI evidence.

## Project structure

```text
src/+lmz/                 Generic APIs, services, data, GUI, and utilities
models/+lmzmodels/        Canonically named standalone model packages
catalog/                  Model, problem, and scene descriptors
examples/                 Public API examples and built-in demonstrations
tests/                    Unit, integration, GUI, release, security, and performance tests
tools/                    Validation, authoring, coverage, CI, and release utilities
release/                  Redistribution inventory and reproducible package definitions
benchmarks/               Measured workflows, budgets, and platform baselines
coverage/                 Measured stable-package regression policy when finalized
docs/                     Architecture, API, authoring, security, provenance, and evidence records
.github/workflows/        Static, MATLAB-matrix, and non-publishing release-audit CI
```

## License and provenance

Scientific inputs are pinned to three immutable commits: quadruped `SLIP_Model_Zoo` commit `2c106101383ecee1b2a9d695efe09fbd72d5718a`, biped `2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` commit `4595146c5881a5313bc8fe92de85099193ef9be9`, and load-pulling `2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` commit `19f3133073c988cc0c3424a647b4adbb60a90b99`. Normal source-tree runtime and tests require only this repository.

There is no root `LICENSE`, and no owner-supplied project grant currently authorizes a public core or scientific package. Public release packaging therefore remains blocked. The quadruped checkout has no license/notice; the biped readme states CC BY-NC 4.0 but does not include a standalone file clarifying its exact code/data scope; the load readme claims BSD 3-Clause but its linked license file is absent at the audited commit. User authorization to perform this migration is recorded but is not treated as a public redistribution grant.

The machine-readable inventory records every candidate file's digest, category, source repository/commit, decision, notice, derivation, profile, and release role. Derived native artifacts and fixtures inherit their source-material decision. Both public builders fail before retaining output while the project decision is unresolved. Temporary internal builds use `technical-validation`, embed `NOT_FOR_REDISTRIBUTION`, and are deleted by the builder/tests. See [docs/REDISTRIBUTION_STATUS.md](docs/REDISTRIBUTION_STATUS.md), [docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md](docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [release/README.md](release/README.md), and [docs/provenance.md](docs/provenance.md).

Scientific attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse Quadrupedal Gaits,” *IEEE Robotics and Automation Letters* 9(5), 4782–4789 (2024), DOI `10.1109/LRA.2024.3384908`.

## Current verified status

The untouched Round 6 baseline was rerun under MATLAB R2025b Update 5 before Round 7 edits: `117 run, 0 failed, 0 incomplete`, with all 24 then-existing public examples and the three-scientific-model clean-copy workflow passing. Its scientific catalogs remain quadruped 9 branches/3,443 points, biped 6 branches/2,967 points, and load 2 datasets (one and two strides). No Round 7 work changes a scientific equation, source fixture, or regression tolerance.

Round 7 added version/API/artifact compatibility, the componentized GUI/event/preferences layer, compatibility fallbacks, release tooling, generic authoring proofs, security boundaries, reproduction, quality, benchmark, coverage, CI, and governance infrastructure. Round 8 adds source-audited compound research graphics, validated per-problem profiles/configuration, profile-aware GUI/recording, source-style plots, pure geometry fixtures, an 18-case source-versus-LMZ metric matrix, and clean-copy research rendering. The authoritative Round 8 suite passed 275/275, all 31 public examples passed, and the clean-copy isolation gate passed. Geometry-tested and image-metric-tested fidelity are recorded separately from the still-blocked human side-by-side review in [docs/TEST_STATUS.md](docs/TEST_STATUS.md) and [docs/RELEASE_CANDIDATE_STATUS.md](docs/RELEASE_CANDIDATE_STATUS.md).

Round 9 adds catalog-driven Poincaré sections, true section-aware start/stop
simulation and transfer, safe composite acceptance conditions,
fixed-state/fixed-physics contact timing, native stride plans, requested-N
simulation, explicit N-stride residual forms, recovery/checkpoint workflows,
artifact/reproduction extensions, five detailed guides, and eleven public
workflows. The final non-instrumented R2025b suite passed `396/396` in
`549.278033` seconds; all 42 public examples passed in `264.010607` seconds;
and clean-copy isolation passed in `40.948339` seconds. Instrumented coverage
passed all stable-package floors at `14,190/18,428` statements (77.0024%)
across 263 files and 28 packages. Code quality reported 265 files with zero
unallowlisted violations, architecture checks were clean, and the R2019b
static scan found zero violations across 558 MATLAB files. The seven Round 9
performance workflows completed three warm repetitions with no budget
overruns. Full evidence is recorded in
[docs/TEST_STATUS.md](docs/TEST_STATUS.md).

Round 8 closes at committed HEAD
`c2616735354a354fa432bac549f81861f8ddd9a5`, and Round 9 closes at committed
HEAD `c0d87860b59cfbdffe96e165cd01c68e2de7d948`. Round 10 closes at the latest
public committed HEAD `5c6a6c100f752ea6ed1fd20114f84800f9b52070`
with framework version `1.0.0-rc.2`. It adds rank-aware rectangular timing,
timing families, generic multiple shooting/horizon feasibility, section-local
scientific adapters, heterogeneous plans, quad-load horizon infrastructure,
artifacts, GUI controls, guides, and examples.
`ROUND10_LOCAL_AUTOMATION_PASSED`: the locally executed final R2025b suite
passed `544/544` in `1153.233186` seconds; all 54 public examples passed in
`424.166055` seconds; and clean-copy isolation passed 1/1 in `52.852335`
seconds. Instrumented coverage passed all five stable-package
floors at `19,973/25,363` statements (78.74857075267121%) across 317 runtime
files and 29 packages. Code quality checked 319 files with zero violations,
architecture checks were clean, and the R2019b static audit found zero known
violations across 699 MATLAB files. The 29-workflow, three-repetition
performance matrix completed in `113.18738520833334` seconds with no budget
overrun.

Round 11 is the current uncommitted Round 11 worktree on that committed Round 10 HEAD
and advances the framework candidate to `1.0.0-rc.3` while keeping artifact,
catalog, workflow, data-source, and workbench schemas at `1.0.0`. It adds
registered model-owned data/workbench/workflow contributions, a complete
quadruped RoadMap root/seed/both-direction workflow, external workflow-plugin
proof, GUI-independent solve progress, and selectable scientific-workbench and
classic layouts with shared branch overlays and scrollable adaptive content.
The unchanged 544-test Round 10 suite passed as the pre-edit baseline.
`ROUND11_LOCAL_AUTOMATION_PASSED`: the authoritative sequential R2025b suite
passed `631/631` in `2887.735954750` seconds; all 55 public examples passed in
`579.852970708` seconds; and clean-copy isolation passed 1/1 in
`51.230211833` seconds. Enforced coverage passed all five stable-package floors
at `23,614/29,755` statements (79.3614518568308%) across 375 runtime files and
34 packages. Code quality checked 377 files with zero unallowlisted
violations, architecture reported zero violations, and the R2019b static audit
reported zero violations across 807 MATLAB files. The 29-workflow and
10-workbench performance reports each completed three repetitions with zero
median budget overruns. Automated package-install tests passed while retaining
no unauthorized artifact; core source ZIP/toolbox selected 680/383 files and
scientific source ZIP/toolbox selected 1,065/660 files.

Focused section-local evidence passes its 12/12 exact tests; the quadruped
touchdown timing root is deliberately labeled rank deficient and non-unique.
The frozen load-horizon evidence contains a valid N=2 transition/contact root,
but the N=3 fixed-control and energy-neutral searches both ended in
`physical_validation_failure`, so physical N=4/N=5 continuation was not
reached. A separate stride-boundary N=5 search tested all four single-control
bounded-work-100 families. Its best physical candidate retained a scaled norm
of `0.3086908931991573` (maximum `0.11470808666193932`) at 119 residuals and
119 unknowns, rank 112/nullity 7, but ended at the evaluation limit and is
therefore `numerical_failure`; it publishes no simulation. These are local
numerical outcomes, not proof of global infeasibility, and the N=5 search is
not represented as continuation from validated N=3/N=4 roots. Exact residuals
and physical checks are recorded in the linked section and quad-load guides.

For the historical Round 9 quad-load path, five-stride carry-forward
establishes only the exact 96-entry layout. Its timing correction stops safely
at stride 3 and returns a partial `2/5` result with no simulation. Round 10
horizon analyses retain their own exact local numerical and physical
classifications; no vector length or solver exit flag is treated as a
validated five-stride physical return.

The Round 10 redistribution scan inventories 932 candidate files and retains
917 blockers while the project decision is unresolved. Temporary core and
scientific ZIP/toolbox technical-validation builds passed clean installation,
registry discovery, permitted workflow, invisible GUI construction, artifact
round trip, unload, and path-removal checks. Every selector remained
`Authorized=false`, every build remained `Retained=false`, and the final
installed LMZ toolbox count was zero. These checks did not authorize
publication.
The Round 11 redistribution inventory covers 1,080 files with 1,065 selected
release-profile blockers and zero structural, stale, missing, or unlisted
finding. Release qualifications remain explicit: the human MATLAB desktop walkthrough
is not executed; R2019b runtime is not executed; GitHub Actions workflows have
not run remotely; and public core/scientific packaging is blocked by the
missing project license and unresolved owner decisions. The present
recommendation is an internal, numerically testable release candidate—not a
public release. The local Round 10 and Round 11 commands above are not remote-CI,
human-desktop, R2019b-runtime, or redistribution-authority evidence.
