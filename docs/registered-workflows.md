# Registered scientific workflows

Registered workflows make a complete, repeatable scientific route discoverable
without adding a model-specific branch to the GUI, a generic service, or the
workflow runner. A workflow is inert catalog data bound to trusted model-owned
providers during registry discovery. The generic runtime still owns solving,
seed construction, continuation, checkpoints, and result objects.

This API is provisional in `1.0.0-rc.3`. The workflow, data-source, workbench,
artifact, and catalog documents continue to use schema `1.0.0`; Round 11 is an
additive framework-version change, not a schema migration.

## Registration boundary

A branch-capable model can contribute three optional catalog resources:

```text
catalog/<model-id>/
  manifest.json
  data_sources.lmz.json
  workbench.lmz.json
  workflows/
    <workflow-id>.json
```

The model manifest refers to them with `dataSources`, `workbench`, and
`workflows`. Paths are resolved inside the model catalog, and their SHA-256
digests are frozen when `ModelRegistry` discovers the model. Editing one after
discovery causes workflow-registry construction to fail instead of silently
changing the active experiment.

`data_sources.lmz.json` names a model-owned provider class. External provider
classes must resolve uniquely inside the explicitly trusted plugin package and
code root. The JSON never contains a function handle, MATLAB expression, or
arbitrary path. `workbench.lmz.json` contributes presentation metadata only;
it cannot run a solver. A workflow descriptor may select registered data,
problem, axes, visualization, layout, solver defaults, seed policy,
continuation defaults, analysis views, and provenance.

All three resources are optional. A model without them remains usable through
its ordinary problem contracts and receives the generic `classic_tabs`
workbench. Omitting a workflow does not disable simulation, solving, or other
capabilities declared by the problem.

## Runtime objects

| Contract | Responsibility |
|---|---|
| `lmz.workflow.WorkflowRegistry` | Discover and validate model-bound data sources, workbench contributions, and workflows. |
| `WorkflowDescriptor` | Immutable, validated workflow metadata plus registry bindings. |
| `DataSourceDescriptor` | Inert identity, problem, kind, provider class, default dataset, metadata, source path, and hash. |
| `DataSourceProvider` | Model-owned trusted code that lists and loads `BranchDataset` values and recommends a seed point. |
| `WorkbenchContribution` | Layout profile, central views, sidebar panels, axis presets, filters, analysis contributions, direction labels, and default options. |
| `WorkflowRunner` | Create a runtime session from a bound descriptor and `RunContext`. |
| `WorkflowSession` | Own the selected dataset/seed, working solution, solve, seed pair, continuation, homotopy, family scan, and step history. |
| `WorkflowResult` | Aggregate the workflow identity, results, ordered steps, and diagnostics without serializing providers or callbacks. |

`WorkflowRegistry` validates referenced model/problem capabilities,
visualization profiles, axis presets, layout profiles, IDs, hashes, and provider
trust before a workflow runs. Registration therefore selects existing generic
algorithms; it does not move model equations into JSON.

## Use a registered workflow

The following is the public RoadMap route. It uses the catalog rather than a
direct call to a quadruped data catalog or legacy continuation routine.

```matlab
startup;
models = lmz.registry.ModelRegistry.discover();
workflows = lmz.workflow.WorkflowRegistry.fromModelRegistry(models);

descriptor = workflows.get( ...
    'slip_quadruped', 'roadmap_root_continuation');
context = lmz.api.RunContext.synchronous(1401);
session = lmz.workflow.WorkflowRunner().initialize(descriptor, context);

solved = session.solve(struct());
pair = session.makeAdjacentSeedPair(+1, struct());
continued = session.continueBranch(struct( ...
    'DirectionMode', 'both', ...
    'MaximumPoints', 20, ...
    'InitialStep', pair.AchievedRadius));

summary = session.result();
```

`DirectionMode` accepts `forward`, `backward`, or `both`. A registered
continuation preset supplies the default and its human-readable labels. The
generic continuation engine still applies chart-aware secants, prediction and
correction, acceptance policies, adaptive steps, controlled stop, and atomic
checkpoints. `continueBranch` is the method name because `continue` is a
MATLAB language keyword.

Run the complete public example with:

```matlab
run('examples/demo_registered_slip_quadruped_workflow.m')
```

The example writes only beneath a temporary output directory unless
`registeredWorkflowOutputDirectory` is supplied. It solves, makes the adjacent
pair, traces both directions, saves a native continuation artifact, reloads it,
and publishes `LMZ_REGISTERED_QUADRUPED_WORKFLOW_OK` on success.

## Descriptor fields

Every workflow descriptor contains:

```text
schemaVersion
id, label, modelId, problemId
maturity, validationStatus
dataSourceId, defaultDatasetId, defaultPointIndex
axisPresetId, visualizationProfileId, layoutProfileId
allowedSteps
seedPreset, solveOptions, continuationPreset
homotopyPreset, familyScanPreset
analysisViews, provenance
```

`problemConfiguration` is optional additive configuration for a specific
problem, such as a start/stop Poincare section. IDs use lowercase letters,
digits, and underscores. `maturity` is one of `tutorial`, `compatibility`,
`validated`, or `experimental`; `validationStatus` is `untested`, `tested`, or
`source-equivalent`. Only evidence tied to an immutable source may use
`source-equivalent`.

`allowedSteps` is enforced by `WorkflowSession`. It must agree with the
registered problem capabilities: for example, a workflow cannot advertise
continuation for a problem whose descriptor has `continue=false`.

## Data-source provider contract

A provider derives from `lmz.workflow.DataSourceProvider` and implements:

```matlab
records = provider.list(descriptor, registry);
dataset = provider.load(descriptor, datasetId, registry);
index = provider.recommendedPoint(descriptor, dataset);
```

The returned dataset must be an `lmz.data.BranchDataset` whose model and
problem agree with its descriptor. The provider owns scientific catalog
knowledge, legacy decoding, and recommended-point policy. Generic GUI and
services consume the descriptor/provider contract and never switch on a
built-in model ID.

Use a separate `LegacyDataAdapterProvider` when exact legacy import/export is
required. Keep raw row indexing in the model package, retain hashes and source
lineage, and test an unchanged round trip. A `BranchCatalogProvider` can also
own branch styling and catalog metadata. Neither belongs in `src/+lmz`.

## Workbench contribution

The workbench document selects one of the registered layout profiles and may
provide:

- central views such as `branch_state`, `hildebrand_footfall`, and
  `run_overlay`;
- task panels such as information/selection, visualization, solve/seeds,
  continuation, analysis, and advanced shooting;
- named axis presets with coordinates, dimensionality, camera, and limits;
- model-owned parameter-filter metadata and analysis contribution IDs;
- forward/backward direction labels; and
- default solve and continuation options.

These are presentation defaults. The workbench cannot override a problem's
capability, scientific tolerance, schema, or solver acceptance policy.

## Author a scientific branch model

Start with the minimal model path in
[getting-started-build-a-model.md](getting-started-build-a-model.md), then add
the scientific route:

1. Implement and test a problem that exposes the root and continuation
   contracts.
2. Implement a contained provider that returns one or more native branch
   datasets and recommends a valid interior point.
3. If needed, implement a contained legacy adapter and exact round-trip test.
4. Add `data_sources.lmz.json` and bind it from `manifest.json`.
5. Add a workbench contribution with an axis preset and either
   `scientific_workbench` or `classic_tabs`.
6. Add a workflow descriptor whose steps match the problem capabilities.
7. Record immutable data/source hashes, source commit, maturity, and validation
   status.
8. Test registry discovery, hash freezing, provider containment, initialization,
   solve, both seed routes, each advertised continuation direction,
   checkpoints, artifacts, and plugin removal.

An external model follows the same files and calls
`ModelRegistry.discoverWithPlugins` on an explicitly reviewed plugin root. The
`analytic_hopper` fixture proves that its data provider and complete
root-continuation workflow appear and disappear with that scoped registry,
without editing the built-in catalog or `src/+lmz`.

## Validation and qualifications

The Round 11 contracts cover built-in discovery, descriptor validation,
provider containment, hash freezing, generic fallback, external registration
and removal, the quadruped descriptor, and the canonical RoadMap end-to-end
route. The Round 10 full-suite result remains historical evidence. Current
Round 11 aggregate, public-example, clean-copy, coverage, performance, and
packaging results belong in [TEST_STATUS.md](TEST_STATUS.md) only after those
commands have actually completed.

Registered workflow execution is not redistribution permission. Plugin code is
trusted executable MATLAB code, and local R2025b tests are not remote-CI,
human-desktop, or R2019b-runtime evidence.
