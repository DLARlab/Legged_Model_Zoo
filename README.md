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

Root solving, optimization, continuation, recording, and legacy-equation equivalence remain under implementation and are not advertised as available.

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

Branch, Solution, Solve, Continuation, and Optimization tabs are present as workflow landmarks but explicitly report that their runtime algorithms are not implemented. They do not expose nonfunctional controls. GUI construction, model selection, controller simulation, and clean shutdown have been executed in MATLAB batch mode; interactive desktop behavior has not been manually inspected.

## Available models

<!-- LMZ:MODEL_TABLE:BEGIN -->
| Model ID | Label | Simulation | Visualization | Solve | Continuation | Optimization |
|---|---|---:|---:|---:|---:|---:|
| `slip_biped` | SLIP Biped | Yes | Yes | No | No | No |
| `slip_quad_load` | SLIP Quadruped with Load | Yes | Yes | No | No | No |
| `slip_quadruped` | SLIP Quadruped | Yes | Yes | No | No | No |
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

Native artifacts contain exactly one top-level plain struct named `artifact`:

```matlab
lmz.io.ArtifactStore.save('result.lmz.mat', artifact);
restored = lmz.io.ArtifactStore.load('result.lmz.mat');
```

The store validates schema identity, dimensions, finite values, lineage, random seed, source commits, and version metadata before an atomic rename.

## Solving periodic solutions

Periodic root solving is not implemented in the standalone preview. Manifests report `solve = false`, and the GUI does not enable solver controls. No solver result is fabricated from the analytic demonstrations.

## Numerical continuation

Pseudo-arclength continuation is not implemented. Manifests report `continue = false`; checkpoint and branch APIs will be documented when executable.

## Parameter homotopy and branch-family scans

Parameter homotopy and branch-family scanning are not implemented. These names are reserved for transport and repeated one-dimensional branch workflows; the project will not mislabel a parameter scan as two-dimensional continuation.

## Optimization and data fitting

Optimization is not implemented. The load model currently demonstrates simulation and tugline-force output only. Optimization Toolbox absence therefore does not prevent application startup or simulation.

## Visualization, animation, and recording

The GUI provides named body-trajectory plotting and normalized-time scrubbing. Models expose named plot descriptors and repository-contained scene specifications. Continuous playback, GIF/MP4 recording, and keyframe export are not yet implemented, despite the current `animate` capability indicating time-scrubbable simulation data.

## Artifact format

Supported artifact types are `solution`, `branch`, `simulation`, `optimization-run`, and `checkpoint`. New artifacts must use schema version `1.0.0` and one of the canonical model IDs. Live handle objects are never the public serialization format.

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

The current complete result is 27 tests run, 0 failed, and 0 incomplete under MATLAB R2025b Update 5. See `docs/TEST_STATUS.md` for the exact command and supplementary isolation/example evidence.

## Troubleshooting

- **Undefined `lmz` package:** run `startup` from the repository root.
- **GUI cannot construct:** verify MATLAB R2019b or newer and desktop graphics availability.
- **Solver controls unavailable:** those algorithms are not implemented yet; this is not a toolbox-detection error.
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

Static catalog, naming, dependency, and README checks pass. MATLAB executed all three standalone simulations, headless controller workflows, programmatic GUI construction, four command-line examples, the README contract, the full 27-test suite, and an isolated-copy registry/simulation/GUI workflow with no sibling repositories. No legacy numerical-equivalence, solve, continuation, optimization, interactive desktop, or recording result is claimed. Refer to `MIGRATION_STATUS.md` and `docs/TEST_STATUS.md` for exact evidence.
