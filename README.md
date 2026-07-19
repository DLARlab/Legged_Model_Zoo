# Legged Model Zoo

Legged Model Zoo is a MATLAB framework for representing, discovering, validating, and eventually solving hybrid legged-locomotion models through common model, problem, service, persistence, and visualization APIs.

The project currently provides the validated core scaffold: project path discovery, declarative model catalogs, variable schemas and charts, cooperative run controls, artifact validation and persistence, and an exact layout adapter for legacy 29-row SLIP quadruped branches. Numerical model evaluation, solving, continuation, optimization, and the GUI are still under migration and are deliberately not advertised as available capabilities.

See [MIGRATION_STATUS.md](MIGRATION_STATUS.md) for implementation progress and [docs/TEST_STATUS.md](docs/TEST_STATUS.md) for exactly what has and has not been executed.

## Requirements

- MATLAB R2019b or newer
- Optimization Toolbox will be required for future `fsolve` and `fmincon` workflows, but is not required for catalog, schema, adapter, or artifact operations
- Parallel Computing Toolbox is optional and will not be required for synchronous workflows

MATLAB was not available in the current development environment, so the MATLAB tests described below are implemented but have not yet been executed.

## Installation and setup

Clone or copy this repository to a local directory. The original research repositories are not required for normal catalog and schema use. When regenerating migration fixtures, the following repositories are expected as siblings of this repository:

```text
workspace/
  Legged_Model_Zoo/
  SLIP_Model_Zoo/
  2022_A_Template_Model_Explains_Jerboa_Gait_Transitions/
  2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights/
```

Start MATLAB, change to the project directory, and initialize the code roots:

```matlab
cd('/path/to/Legged_Model_Zoo');
startup;
```

`startup` adds only `src` and `models`. It does not recursively add the repository, tests, examples, catalogs, or any legacy repository to the MATLAB path.

## Quick start: discover the model catalog

```matlab
startup;

registry = lmz.registry.ModelRegistry.discover();
modelIds = registry.listModels();
disp(modelIds);

manifest = registry.getManifest('slip.quadruped.planar.v2');
disp(manifest);

model = registry.createModel('slip.quadruped.planar.v2');
disp(model.getCapabilities());
disp(model.listProblems());
```

The registry resolves the catalog through `lmz.util.ProjectPaths`, so discovery does not depend on MATLAB's current working directory after `startup` has run.

The same workflow is available in:

```matlab
run(fullfile(lmz.util.ProjectPaths.examples(), 'demo_registry.m'));
```

## Available models and current capabilities

| Model ID | Declared problems | Current numerical capabilities |
|---|---|---|
| `slip.quadruped.planar.v2` | `periodic_apex` | Disabled pending vendored evaluator and regression baseline |
| `jerboa.biped.offset` | `periodic_apex`, `trajectory_fit` | Disabled pending migration |
| `slip.quadruped.load` | `single_stride_periodic`, `multi_stride_fit` | Disabled pending migration |

The models instantiate successfully, but calls to unavailable numerical operations fail with explicit model-specific errors. This is intentional: the framework does not claim simulation, solving, continuation, optimization, or visualization support merely because a catalog entry or boundary adapter exists.

## Project paths

Use the centralized path utility instead of manually traversing package directories:

```matlab
projectRoot = lmz.util.ProjectPaths.root();
sourceRoot = lmz.util.ProjectPaths.src();
modelRoot = lmz.util.ProjectPaths.models();
catalogRoot = lmz.util.ProjectPaths.catalog();
testRoot = lmz.util.ProjectPaths.tests();
exampleRoot = lmz.util.ProjectPaths.examples();
checkpointRoot = lmz.util.ProjectPaths.checkpoints();
```

Temporary and checkpoint paths are returned but are not created until a caller needs them.

## Variable schemas and charts

`VariableSpec` describes one named variable, while `VariableSchema` preserves ordering and supports validation, packing, unpacking, grouping, metadata, and persistence.

```matlab
period = lmz.schema.VariableSpec( ...
    'period', ...
    'Label', 'Stride period', ...
    'Unit', 's', ...
    'Group', 'timing', ...
    'DefaultValue', 1, ...
    'LowerBound', 0, ...
    'Scale', 1, ...
    'Topology', 'positive');

touchdown = lmz.schema.VariableSpec( ...
    'touchdown', ...
    'Label', 'Touchdown time', ...
    'Unit', 's', ...
    'Group', 'timing', ...
    'DefaultValue', 0.25, ...
    'Topology', 'cyclic_time', ...
    'PeriodSource', 'period');

schema = lmz.schema.VariableSchema([period; touchdown], '1.0.0');

vector = schema.pack(struct('period', 1.2, 'touchdown', 0.3));
namedValues = schema.unpack(vector);
timingSchema = schema.selectGroup('timing');
metadata = schema.metadataTable();
storedSchema = schema.toStruct();
restoredSchema = lmz.schema.VariableSchema.fromStruct(storedSchema);
```

Charts implement local cyclic geometry and canonical representation:

```matlab
chart = lmz.schema.VariableChart(schema);

localDelta = chart.difference([1.2; 0.05], [1.2; 1.15]);
candidate = chart.retract([1.2; 1.1], [-0.2; 0.15]);
canonical = chart.canonicalize(candidate);
```

When a retraction changes a period and a cyclic time in the same step, the candidate's new period is used for wrapping. Nonfinite and nonpositive periods are rejected.

`DiagonalMetric` supplies scale-aware norms and inner products:

```matlab
metric = lmz.schema.DiagonalMetric([1; 0.1]);
scaledLength = metric.norm([0.5; 0.02]);
scaledInnerProduct = metric.inner([1; 0], [0.5; 0.1]);
```

## Importing and exporting legacy quadruped branches

The SLIP quadruped legacy format stores a branch as a numeric `results` matrix with 29 rows:

- Rows 1–13: periodic initial-state values
- Rows 14–22: nine event times
- Rows 23–29: seven parameters

All raw positional indexing is confined to `lmzmodels.slipquadruped.Results29Adapter`.

```matlab
startup;

adapter = lmzmodels.slipquadruped.Results29Adapter();
branch = adapter.loadBranch('/path/to/legacy_branch.mat');

disp(branch.pointCount);
firstState = branch.state(:, 1);
firstEventTimes = branch.eventTimes(:, 1);
firstParameters = branch.parameters(:, 1);

legacyResults = lmzmodels.slipquadruped.Results29Adapter.encode(branch);
```

The current adapter guarantees exact numeric layout round trips. Conversion to native `SolutionBranch` objects, named branch access, and artifact lineage is part of the remaining quadruped vertical-slice work.

## Run context, cancellation, and progress

Long-running services will receive a GUI-independent `RunContext`. The synchronous context is usable now:

```matlab
context = lmz.api.RunContext.synchronous(42);
context.check();
context.progress(0.25, 'Preparing inputs');
context.log('info', 'Run initialized');
```

The seed passed to `synchronous` is retained as `context.RandomSeed`. Callbacks can be replaced for command-line logging or GUI integration:

```matlab
context.ProgressFcn = @(fraction, message) ...
    fprintf('%3.0f%% %s\n', 100 * fraction, message);
context.LogFcn = @(level, message) ...
    fprintf('[%s] %s\n', upper(level), message);
context.CheckpointFcn = @(value) disp(value);
```

Cancellation and pause are cooperative:

```matlab
context.Cancellation.cancel();
% A later context.check() throws lmz:Cancelled.
```

## Artifact persistence

Native MAT files contain exactly one top-level plain struct named `artifact`. Live class instances are not the public serialization format.

Supported artifact types are:

- `solution`
- `branch`
- `simulation`
- `optimization-run`
- `checkpoint`

Use:

```matlab
lmz.io.ArtifactStore.save('result.lmz.mat', artifact);
restored = lmz.io.ArtifactStore.load('result.lmz.mat');
```

Before writing, `ArtifactStore` validates:

- artifact schema version and type;
- model/problem identity and versions;
- ordered decision and parameter names;
- variable units, topology, and positive scales;
- finite real decision and parameter values;
- dimensions consistent with stored schemas;
- diagnostics, lineage, random seed, source commits, and version metadata;
- checkpoint-specific state and termination metadata.

Writes use a temporary MAT file, reload and validate it, then rename it to the requested destination. Unsupported or incomplete development artifacts are rejected explicitly.

## Model catalog format

Each model lives under `catalog/<model>/` and contains a `manifest.json`, problem descriptors, and—when visualization is advertised—a `scene.lmz.json`.

The registry validates:

- supported manifest and problem schema versions;
- unique model and problem IDs;
- semantic model versions;
- implementation classes restricted to `lmzmodels.*`;
- existence of every implementation class and problem descriptor;
- supported problem kinds;
- truthful relationships between implemented problems and capabilities;
- presence of a scene when visualization is enabled.

JSON is declarative. It must never contain executable MATLAB expressions.

## Regenerating minimal migration inputs

When the three immutable reference repositories are present as siblings, run:

```matlab
startup;
toolsPath = fullfile(lmz.util.ProjectPaths.root(), 'tools');
addpath(toolsPath);
cleanup = onCleanup(@() rmpath(toolsPath));
regenerate_regression_inputs;
```

This extracts small input fixtures under `tests/fixtures` and records their source paths, hashes, commits, and selected columns. It does not add legacy repositories to the path and does not execute legacy numerical functions.

Generated inputs are not numerical baselines. Residuals, trajectories, events, forces, gait classifications, and measured regression tolerances still require MATLAB baseline execution.

## Running tests

Run the complete recursive suite from the repository root:

```matlab
results = run_tests;
```

For batch validation:

```bash
matlab -batch "cd('/path/to/Legged_Model_Zoo'); results=run_tests; assert(~any([results.Failed]));"
```

`run_tests` initializes the project, temporarily adds only test utilities and fixtures, runs all test folders recursively, prints a concise summary, and raises `lmz:Tests:Failed` if any test fails.

The current suite covers project paths, registry discovery and validation, duplicate catalog IDs, schema packing, cyclic chart behavior, changing-period retraction, invalid periods, artifact round trips and corruption, the quadruped layout adapter, and architecture rules. Consult [docs/TEST_STATUS.md](docs/TEST_STATUS.md) before interpreting the suite as passing.

## Repository layout

```text
Legged_Model_Zoo/
  startup.m                 Project initialization
  run_tests.m               Root validation entry point
  src/+lmz/                 Generic framework packages
  models/+lmzmodels/        Model-specific code and adapters
  catalog/                  Declarative model/problem/scene descriptors
  examples/                 Public API examples
  tests/                    Unit, integration, regression, architecture tests
  tools/                    Explicit development and fixture utilities
  docs/                     Architecture, migration, provenance, test records
  vendor/dlar/              Reserved isolated legacy source area
```

Generic framework packages must not contain model-specific packed indices. Legacy indexing belongs only in documented model-specific adapters, codecs, layouts, or evaluators.

## Current limitations

The following workflows are not yet available:

- physical simulation for any of the three models;
- deterministic residual or objective evaluation;
- root solving and multistart search;
- second-seed construction;
- pseudo-arclength continuation, homotopy, or branch-family scans;
- trajectory/force rendering, animation, or recording;
- the programmatic GUI;
- native `SolutionBranch` import from legacy files;
- numerical regression baselines or equivalence claims.

Calling an unavailable model operation should produce an explicit error rather than placeholder numerical output.

## Troubleshooting

### The registry cannot find an implementation class

Run `startup` before constructing the registry. Confirm that `lmz.util.ProjectPaths.models()` exists and that the implementation class is under the `lmzmodels.*` namespace.

### A manifest is rejected

Check that every declared problem has a corresponding JSON file under `problems/`, IDs match filenames, versions use `major.minor.patch`, capability values are logical, and unsupported capabilities remain false.

### An artifact is rejected

Artifacts created before the current `1.0.0` contract may lack required schema metadata, lineage, seed, diagnostics, or source commits. Recreate them through the current artifact builder once the relevant model workflow is implemented; do not bypass validation.

### A cyclic time fails validation

Its named period source must exist in the same schema and resolve to a finite positive value at the evaluated point.

## Development status and provenance

- [Migration status](MIGRATION_STATUS.md)
- [Test status](docs/TEST_STATUS.md)
- [Architecture](docs/architecture.md)
- [Legacy inventory](docs/legacy-inventory.md)
- [Legacy data contracts](docs/legacy-data-contracts.md)
- [Baseline fixtures](docs/baseline-fixtures.md)
- [Source provenance](docs/provenance.md)
- [Known differences](docs/KNOWN_DIFFERENCES.md)

The three original research repositories are immutable reference inputs. The target project is designed to run without adding them to the MATLAB path.
