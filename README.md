# Legged Model Zoo

## Project overview

Legged Model Zoo is a MATLAB framework and programmatic GUI for exploring legged-model simulations through common registry, model, service, data, and visualization boundaries. The current standalone preview includes three repository-contained analytic demonstrations. They are useful for GUI and API exploration but are not yet numerical-equivalence replacements for the original research models.

## Features

- One-command programmatic GUI launch
- Declarative discovery of three canonical models
- Standalone built-in simulation for every model
- Named state schemas and validated simulation results
- Trajectory plotting and normalized-time scrubbing
- Cooperative progress, pause, and cancellation context
- Versioned plain-struct artifact validation and atomic MAT persistence
- Deprecated import aliases for older model identifiers
- Native schema-based solutions and multi-point branches
- Generic `fsolve`, pseudo-arclength continuation, homotopy, branch-family scans, and `fmincon`

Native stride-closure solving, continuation, and fitting are being implemented in Round 4. They remain distinct from legacy-equation equivalence, which is not claimed.

## Requirements

- MATLAB R2019b or newer
- No toolbox is required for the built-in analytic simulations
- Optimization Toolbox will be required when solver and fitting capabilities are enabled
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

The header provides canonical model, problem, and built-in example selectors. Choose a model and press **Simulate**. The Simulation tab plots its body trajectory; move the normalized-time slider to inspect the current point. The status panel reports completion or an actionable error.

The Branch tab plots a repository-contained native branch and selects synchronized points. Solution displays named decision values. Solve runs generic `fsolve`; Continuation constructs a metric-aware second seed and traces a short branch; Optimization runs generic `fmincon` for supported models. These native problems exercise the real numerical stack but are not legacy-equivalence claims.

## Available models

<!-- LMZ:MODEL_TABLE:BEGIN -->
| Model ID | Label | Simulation | Visualization | Solve | Continuation | Optimization |
|---|---|---:|---:|---:|---:|---:|
| `slip_biped` | SLIP Biped | Yes | Yes | Yes | Yes | Yes |
| `slip_quad_load` | SLIP Quadruped with Load | Yes | Yes | No | No | Yes |
| `slip_quadruped` | SLIP Quadruped | Yes | Yes | Yes | Yes | No |
<!-- LMZ:MODEL_TABLE:END -->

The displayed simulations are self-contained analytic demonstrations identified by `diagnostics.source = standalone-analytic-demo`. They are not claimed to reproduce published trajectories.

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

Load a repository-contained branch and select a named solution:

```matlab
branch = lmz.services.BranchService().loadBuiltInBranch( ...
    registry, 'slip_quadruped');
solution = branch.point(3);
speed = branch.decision('speed');
```

See `examples/demo_branch_explorer.m` and `examples/demo_solution_inspector.m`.

Native artifacts contain exactly one top-level plain struct named `artifact`:

```matlab
lmz.io.ArtifactStore.save('result.lmz.mat', artifact);
restored = lmz.io.ArtifactStore.load('result.lmz.mat');
```

The store validates schema identity, dimensions, finite values, lineage, random seed, source commits, and version metadata before an atomic rename.

## Solving periodic solutions

`slip_biped/periodic_apex` and `slip_quadruped/periodic_apex` solve a native stride-closure condition through `SolveService` and `FsolveSolver`:

```matlab
model = registry.createModel('slip_quadruped');
problem = model.createProblem('periodic_apex', struct());
seed = problem.makeSolution([1.1; 0.75], [], []);
solveResult = lmz.services.SolveService().solve( ...
    problem, seed, struct(), lmz.api.RunContext.synchronous(11));
```

The residual is genuinely evaluated and solved; it is a native stride-closure formulation, not the unpublished legacy evaluator.

## Numerical continuation

Both periodic problems support metric-scaled second-seed construction and pseudo-arclength correction:

```matlab
seedPair = lmz.services.SeedService().makeSecondSeed( ...
    problem, solveResult.Solution, 0.03, struct(), context);
continuationResult = lmz.services.ContinuationService().run( ...
    problem, seedPair, struct('MaximumPoints', 12), context);
```

The current engine supports bidirectional tracing, adaptive step growth/reduction, duplicate rejection, cooperative cancellation, progress, and checkpoint callbacks. File-backed resume, loop detection, and curvature controllers remain incomplete.

## Parameter homotopy and branch-family scans

`slip_quadruped` supports parameter homotopy and repeated branch-family scans:

```matlab
homotopyResult = lmz.services.ContinuationService().parameterHomotopy( ...
    problem, solveResult.Solution, 'stride_length', [0.9 0.95 1.0], ...
    struct(), context);
familyReport = lmz.services.ContinuationService().branchFamilyScan( ...
    problem, solveResult.Solution, 'stride_length', [0.9 0.95], ...
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

Additional executable examples are `demo_slip_biped_solve.m`, `demo_slip_biped_continuation.m`, `demo_slip_biped_fit.m`, `demo_slip_quadruped_solve.m`, `demo_slip_quadruped_continuation.m`, `demo_slip_quad_load_fit.m`, and `demo_full_gui_workflow.m`.

## Visualization, animation, and recording

The GUI provides named body-trajectory plotting and normalized-time scrubbing. Models expose named plot descriptors and repository-contained scene specifications. Continuous playback, GIF/MP4 recording, and keyframe export are not yet implemented, despite the current `animate` capability indicating time-scrubbable simulation data.

## Artifact format

Supported artifact types include `solution`, `branch`, `simulation`, `solve-run`, `continuation-run`, `optimization-run`, `checkpoint`, and `branch-family-report`. New artifacts must use schema version `1.0.0` and one of the canonical model IDs. Live handle objects are never the public serialization format.

## Legacy MAT import/export

`lmzmodels.slip_quadruped.Results29Adapter` imports and exactly exports the legacy 29-row quadruped `results` layout. Native branch conversion is still pending. Deprecated model IDs are accepted for registry lookup and old artifact loading with warning diagnostics; newly saved artifacts must use canonical IDs.

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

The current complete result is 36 tests run, 0 failed, and 0 incomplete under MATLAB R2025b Update 5. All eleven Round 4 public examples and an isolated-copy advanced workflow also execute. See `docs/TEST_STATUS.md` for exact commands and evidence.

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

Project licensing and third-party redistribution review remain release blockers. Historical migration sources include `SLIP_Model_Zoo`, `2022_A_Template_Model_Explains_Jerboa_Gait_Transitions`, and `2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights`. They are provenance references only and are not runtime dependencies. No legacy numerical source or data was copied in this GUI slice.

## Current verified status

Static catalog, naming, dependency, and README checks pass. MATLAB executed native branch/solution persistence, both periodic solves, both fits, second-seed generation, bidirectional continuation, parameter homotopy, branch-family scanning, functional GUI/controller workflows, all eleven Round 4 examples, the 36-test suite, and isolated-copy advanced workflows. The periodic and fitting problems are native stride-closure demonstrations; no migrated legacy-equation equivalence, measured scientific tolerance, interactive desktop inspection, checkpoint resume, or recording result is claimed.
