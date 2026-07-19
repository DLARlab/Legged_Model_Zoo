# Legged Model Zoo

## Project overview

Legged Model Zoo is a standalone MATLAB framework and GUI for exploring legged-model simulation, solving, continuation, and visualization through common registry, service, schema, and artifact boundaries. It now includes the complete built-in SLIP quadruped RoadMap, a migrated 22-decision scientific evaluator, and repository-contained native branches. The biped and load-pulling slices remain compact native demonstrations and are not claimed as source-equivalent research migrations.

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
- Exact legacy 29-row RoadMap import/export with manifest hashes and native artifact caching

The scientific claim is deliberately scoped: `slip_quadruped/periodic_apex` is compared with repository-contained source baselines; the introductory `demo_stride` problem is still available but is never presented as RoadMap data.

## Requirements

- MATLAB R2019b or newer
- No toolbox is required to load RoadMap branches or run deterministic scientific quadruped simulation
- Optimization Toolbox is required for solve, continuation correction, fitting, and the optional ground-contact event projection. Default cyclic-time wrapping is toolbox-free.
- Parallel Computing Toolbox is optional

The current slice was executed with MATLAB R2025b Update 5. Optimization Toolbox and Parallel Computing Toolbox were licensed; `usejava('desktop')` was false in batch mode, but programmatic `uifigure` construction still passed. Compatibility remains targeted at R2019b and needs execution on that release.

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

The application opens on the SLIP quadruped RoadMap. The header still provides canonical model, problem, and demonstration selectors. **Run demo** executes the small introductory simulation; scientific work begins in **RoadMap Branches** by locking a stored point and pressing **Simulate point**.

The RoadMap tab supports built-in selection, folder/file import, one/all branch visibility, removal/reload, native and legacy export, named X/Y/Z coordinates, 2-D/3-D views, explicit view/limit/aspect controls, index and percentage navigation, independent hover data tips, keyboard navigation, click-to-lock selection, and gait-based styling. The Solution Inspector separates initial state, event timing, parameters, observables, residuals, diagnostics, and provenance; editable cells update an isolated working copy. Physical Simulation animates the body and four legs and synchronizes torso, back/front leg, 12-channel GRF, and oscillator plots. Solve and Continuation operate on the locked or edited scientific point through services rather than GUI-owned numerical code.

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
13. The Continuation tab also exposes named-parameter homotopy and family scans. A family scan repeats one-dimensional continuation at targets; it is not two-dimensional continuation.
14. Use **Save native…**, **Export legacy…**, **Save solution…**, or **Save result…** as appropriate. An unchanged imported branch reconstructs the source 29-row `results` matrix exactly. The Physical Simulation tab exposes GIF, MP4 where supported, PNG/PDF keyframes, five plot exports, and oscillator GIF; exports are temporary-file based, cancellation-aware, and restore the displayed animation frame.

The complete command-line equivalent is [examples/demo_slip_quadruped_roadmap_workflow.m](examples/demo_slip_quadruped_roadmap_workflow.m).

## Available models

<!-- LMZ:MODEL_TABLE:BEGIN -->
| Model ID | Label | Simulation | Visualization | Solve | Continuation | Optimization |
|---|---|---:|---:|---:|---:|---:|
| `slip_biped` | SLIP Biped | Yes | Yes | Yes | Yes | Yes |
| `slip_quad_load` | SLIP Quadruped with Load | Yes | Yes | No | No | Yes |
| `slip_quadruped` | SLIP Quadruped | Yes | Yes | Yes | Yes | No |
<!-- LMZ:MODEL_TABLE:END -->

The biped/load rows and each model's `demo_stride` remain self-contained demonstrations. The quadruped `periodic_apex` row additionally exposes the scientific RoadMap evaluator and data path described above.

## Built-in examples

Every model exposes `default_stride` through the application controller. The declarative JSON assets live under `examples/data/<model-id>/` and record model/problem identity, options, variable names, units, provenance, and redistribution status. `DataService` validates and loads them; no file browsing or external dataset is required. Run `examples/demo_gui.m` for the GUI or one of the model examples below for command-line use.

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

All three use the same public service API:

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

For the quadruped, replace the model ID with `slip_quadruped`; its body states are also named `x` and `y`. For the load-pulling demonstration, use `slip_quad_load` and plot `quad_x` against `quad_y`.

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

Native artifacts contain exactly one top-level plain struct named `artifact`:

```matlab
lmz.io.ArtifactStore.save('result.lmz.mat', artifact);
restored = lmz.io.ArtifactStore.load('result.lmz.mat');
```

The store validates schema identity, dimensions, finite values, lineage, random seed, source commits, and version metadata before an atomic rename.

## Solving periodic solutions

`slip_biped/periodic_apex` retains the compact native stride-closure demonstration. `slip_quadruped/periodic_apex` is the migrated 22-residual scientific formulation with eight ground-contact equations, one apex equation, and 13 periodicity equations:

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

`slip_quadruped` supports parameter homotopy and repeated branch-family scans:

```matlab
homotopyResult = lmz.services.ContinuationService().parameterHomotopy( ...
    problem, solveResult.Solution, 'phi_neutral', [0 0.05 0.1], ...
    struct(), context);
familyReport = lmz.services.ContinuationService().branchFamilyScan( ...
    problem, solveResult.Solution, 'phi_neutral', [0 0.05], ...
    struct(), context);
```

See `examples/demo_parameter_homotopy.m` and `examples/demo_branch_family_scan.m`. The family scan repeats one-dimensional branches; it is not two-dimensional continuation.

## Optimization and data fitting

`slip_biped/trajectory_fit` and `slip_quad_load/multi_stride_fit` expose named objective contributions and run through `OptimizationService` and `FminconSolver`:

```matlab
model = registry.createModel('slip_quad_load');
problem = model.createProblem('multi_stride_fit', struct());
seed = problem.makeSolution(problem.getDecisionSchema().defaults(), [], []);
optimizationResult = lmz.services.OptimizationService().run( ...
    problem, seed, struct(), lmz.api.RunContext.synchronous(12));
```

The native load objective reports stride-duration, footfall-timing, and loading-force terms. These terms are functional but not yet matched to captured legacy baselines.

Additional executable examples are `demo_slip_biped_solve.m`, `demo_slip_biped_continuation.m`, `demo_slip_biped_fit.m`, `demo_slip_quadruped_solve.m`, `demo_slip_quadruped_continuation.m`, `demo_slip_quadruped_roadmap_workflow.m`, `demo_slip_quad_load_fit.m`, and `demo_full_gui_workflow.m`.

## Visualization, animation, and recording

The quadruped renderer draws the torso, center of mass, back/front attachments, four legs and feet, ground, contact state, phase, and optional force vectors from named state/kinematic data. `AnimationController` provides normalized-time scrubbing, FPS/speed/loop playback, and Play/Pause/Stop/Reset. Named plot providers draw torso, back/front leg, all 12 stored GRF magnitude/x/y channels, and oscillator histories. `RecorderService` exports GIF, MP4 where `VideoWriter` supports it, animation keyframes, plot PNG/PDF, and animated axes through atomic temporary files; it restores the source frame and closes video/file resources on success, cancellation, or error.

## Artifact format

Supported artifact types include `solution`, `branch`, `simulation`, `solve-run`, `continuation-run`, `optimization-run`, `checkpoint`, and `branch-family-report`. New artifacts must use schema version `1.0.0` and one of the canonical model IDs. Live handle objects are never the public serialization format.

## Legacy MAT import/export

`lmzmodels.slip_quadruped.Results29Adapter` converts every finite 29-row RoadMap `results` matrix directly to `lmz.data.SolutionBranch`. Each point retains 22 decisions, seven parameters, file/column/hash provenance, gait classification, and stored observables. Native artifacts are preferred when their recorded source digest is current; maintainers can explicitly reimport legacy MAT. Encoding an unchanged branch reconstructs the source matrix without numerical change, including single-solution or edited exports where requested. Deprecated model IDs remain read-only import aliases; new artifacts use canonical IDs.

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

Round 5 adds manifest/hash/import, exact round-trip, scientific residual/trajectory/GRF/event equivalence, selection synchronization, rendering/plotting, seed/solve/continuation/checkpoint, recording, GUI, documentation, and isolation coverage. See `docs/TEST_STATUS.md` for the current exact totals and commands.

## Troubleshooting

- **Undefined `lmz` package:** run `startup` from the repository root.
- **GUI cannot construct:** verify MATLAB R2019b or newer and desktop graphics availability.
- **Solver controls fail:** verify Optimization Toolbox is licensed and the selected model advertises the requested capability.
- **Artifact uses an old model ID:** load it to migrate the ID, then save a new canonical artifact.
- **Cyclic time rejected:** its named period must be finite and positive.

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

The built-in quadruped RoadMap and compatibility evaluator derive from `SLIP_Model_Zoo` commit `2c106101383ecee1b2a9d695efe09fbd72d5718a`. They were copied under the user's explicit Round 5 migration authorization. The upstream repository contains no LICENSE, COPYING, NOTICE, or redistribution grant, so no OSI license is inferred; redistribution review remains a release blocker. Historical biped/load sources include `2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` and `2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights`; they remain provenance-only references and runtime-independent.

Scientific attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse Quadrupedal Gaits,” *IEEE Robotics and Automation Letters* 9(5), 4782–4789 (2024), DOI `10.1109/LRA.2024.3384908`.

## Current verified status

The complete RoadMap copy contains nine MAT branches, two reference FIG files, and 3,443 points. All copied hashes and all nine native artifacts verify; the default point simulates through the migrated physical evaluator; exact source baselines cover three RoadMap columns; solve acceptance, adjacent seeding, scientific correction, live callbacks, checkpoint save/resume, physical rendering, trajectory/GRF/oscillator plotting, recording exports, and standalone GUI construction have executed under MATLAB R2025b Update 5. Five automated app captures are under `docs/screenshots/`. Exact suite totals, isolated-process evidence, and the remaining human-desktop limitation are recorded in `docs/TEST_STATUS.md`.
