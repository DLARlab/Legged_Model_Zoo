# Configuration reference

## Plugin descriptor

`plugin.json` is required at an explicitly trusted external root.

| Field | Contract |
|---|---|
| `schemaVersion` | Currently `1.0.0` |
| `id` | Unique lowercase identifier |
| `version` | Semantic version |
| `namespace` | Isolated `lmzplugins.*` or `lmzmodels.<new-id>` prefix |
| `codeRoot` | Relative directory containing the package root |
| `catalogRoot` | Relative catalog directory |

Absolute paths, `.`/`..`, symlink escapes, all built-in model namespaces,
ambiguous class resolution, and implementations outside the registered code
root are rejected.

## Model manifest

Required fields are `schemaVersion`, `id`, `version`, `name`,
`implementationClass`, and `problems`. `capabilities` is accepted as a declared
summary, but runtime availability is derived from problem descriptors.
`implementationClass` is executable trusted code; no class name is accepted
from an unregistered external root.

A visualizable model with `graphics.lmz.json` must also declare exactly one
`visualizationContract` object:

```json
"visualizationContract": {
  "frames": ["world", "body", "foot"],
  "parameters": ["leg_length"]
}
```

The object may contain only `frames` and `parameters`. `frames` must be a
nonempty list of unique simple identifiers; `parameters` may be empty but, when
present, follows the same uniqueness/identifier rule. Parameter entries name
top-level roots in `SimulationResult.Parameters`, not nested fields or MATLAB
expressions. During registry discovery, the graphics configuration's
`requiredFrames` and `requiredParameters` must be subsets of these manifest
lists.

Every model advertising visualization currently also needs a contained
`scene.lmz.json`, because registry discovery validates the base scene before it
loads any optional profile configuration. When `graphics.lmz.json` is absent,
`visualizationContract` is optional: the registry uses a declared contract when
provided, otherwise it infers `frames` from the base scene and uses an empty
parameter list.

Round 11 adds three optional manifest fields without changing catalog schema
`1.0.0`:

| Field | Contract |
|---|---|
| `dataSources` | One contained relative path to a data-source catalog. |
| `workbench` | One contained relative path to a workbench contribution. |
| `workflows` | A list of unique contained relative workflow-descriptor paths. |

The registry resolves each path inside the model catalog and records its
SHA-256 digest. `WorkflowRegistry` rejects a digest change after discovery.
Omitting all three fields is valid and produces no registered workflows, no
registered datasets, and a generic `classic_tabs` workbench contribution.

## Registered data-source catalog

`data_sources.lmz.json` is an object with `schemaVersion` equal to `1.0.0` and
a `dataSources` object list. Each record requires:

```text
id, label, modelId, problemId, kind, providerClass
```

Optional fields are `defaultDatasetId` and inert `metadata`. IDs are lowercase
identifiers. `kind` is one of `branch_catalog`, `single_branch`,
`scientific_dataset`, `native_artifact`, `legacy_mat`, or
`generated_tutorial`. `providerClass` is a trusted MATLAB class name and must
resolve through the model registry inside the registered model/plugin package
and code root as an `lmz.workflow.DataSourceProvider`. JSON cannot name an
unregistered core or foreign provider.

The provider lists inert records and loads `lmz.data.BranchDataset` values. It
may recommend a point, return an axis-preset ID/style, and expose a model-owned
legacy adapter. Paths/hashes and legacy row layouts remain provider/model
responsibilities, not generic GUI configuration.

## Workbench contribution

`workbench.lmz.json` uses schema `1.0.0`. Its fields are:

| Field | Contract |
|---|---|
| `id`, `label` | Lowercase contribution ID and nonempty user label. |
| `modelId` | Optional; when omitted it is bound to the containing model. |
| `layoutProfileId` | `scientific_workbench` or `classic_tabs`. |
| `centralViews` | Text IDs such as `branch_state`, `hildebrand_footfall`, and `run_overlay`. |
| `sidebarPanels` | Text IDs for information/selection, visualization, solve/seeds, continuation, optimization/analysis, or advanced shooting tasks. |
| `axisPresets` | Unique named coordinate/camera/limit objects. |
| `parameterFilters`, `analysisPlugins` | Inert filter metadata and contribution IDs. |
| `directionLabels` | Human-readable `backward`/`forward` and optional `both` labels. |
| `defaultSolveOptions`, `defaultContinuationOptions` | Presentation/run defaults; problem capability and service validation remain authoritative. |

An axis preset has `id`, `label`, `x`, `y`, optional `z`, `dimension`, finite
`azimuth`/`elevation`, and optional increasing finite `xLimits`, `yLimits`, and
`zLimits`. Coordinate names are resolved against the loaded branch. A
workbench is inert and cannot contain a callback or enable an unsupported
problem capability.

## Workflow descriptor

Each workflow JSON uses schema `1.0.0` and requires:

```text
id, label, modelId, problemId
maturity, validationStatus
dataSourceId, defaultDatasetId, defaultPointIndex
axisPresetId, visualizationProfileId, layoutProfileId
allowedSteps
seedPreset, solveOptions, continuationPreset
homotopyPreset, familyScanPreset
analysisViews, provenance
```

`problemConfiguration` is an optional inert object. `maturity` is `tutorial`,
`compatibility`, `validated`, or `experimental`; `validationStatus` is
`untested`, `tested`, or `source-equivalent`. The default point is a positive
integer. `allowedSteps` is a nonempty unique text list and must agree with the
registered problem capabilities.

`seedPreset` contains `firstSeed`, `secondSeedOptions`,
`defaultSecondSeed`, positive finite `generatedRadius`, and inert `options`.
`continuationPreset` contains `directionMode` (`forward`, `backward`, or
`both`), direction labels, logical `checkpointEnabled`, and inert service
options. Homotopy/family presets are inert IDs/labels/value objects. Registry
construction also verifies the data source, axis preset, layout profile, and
visualization profile before returning a descriptor.

See [registered-workflows.md](registered-workflows.md) for provider methods,
the runtime session, and complete built-in/external examples.

## Problem descriptor

Required fields are:

```text
schemaVersion, id, kind, implementationId, implemented,
maturity, provenance, validationStatus, capabilities
```

Kinds are `simulation`, `nonlinear_equation`, and `optimization`. Capabilities
are logical scalars named `simulate`, `solve`, `continue`, `optimize`,
`visualize`, `animate`, and optionally `parameterHomotopy` and
`branchFamilyScan`. An unimplemented problem cannot advertise a capability.

## Variable specifications

`VariableSpec` supports `Label`, `LatexLabel`, `Group`, `Unit`, `Note`,
`DefaultValue`, `LowerBound`, `UpperBound`, `Scale`, `Topology`,
`PeriodSource`, `Activity`, `Role`, and `EnergyEffect`. Topologies are
`euclidean`, `positive`, `bounded`, `angle`, and `cyclic_time`. Activities are
`active`, `inactive`, and `derived`.

Roles are `physical`, `control`, `schedule`, and `derived`. Energy effects are
`invariant`, `state_dependent`, `work_input`, and `unknown`. Missing fields in
older serialized specifications default to `physical` and `unknown`, which is
the conservative transition behavior.

## Poincaré section catalog

`catalog/<model-id>/poincare_sections.json` uses schema `1.0.0` and contains
only `schemaVersion`, `defaultSectionByProblem`, and `sections`. Every problem
default names a declared section; there is no first-entry fallback.

Common section fields are `id`, `label`, `kind`, `crossingDirection` (or the
equivalent `direction`), `stateSide`, `minimumReturnTime`,
`requiredEventSequence`, `returnOccurrence`, `coordinateNames`,
`symmetryClass`, `symmetryParameters`, `maturities`, and `validationStatus`.
`named_event` requires `eventId`. Declarative `state_plane` requires
`stateName` and accepts `threshold` and `modeRestriction`. A declarative
`composite` requires `parameters.primarySectionId` plus a nonempty
`parameters.conditions` list. Safe condition kinds are `state_comparison`
(`stateName`, `comparator` in `gt/ge/lt/le`, finite `threshold`, and optional
`stateSide`), `mode_equals` (`modeId` and optional `stateSide`), and
`event_seen` (`eventId`). Empty conditions and unknown fields/operators are
rejected; JSON conditions cannot contain callbacks. A trusted implementation
class may implement an extension inside the registered code root.

Custom implementation and symmetry classes must resolve uniquely within the
registered trusted code root and namespace. JSON never stores executable
section functions.

## Contact timing configuration

`section_return_timing` problems accept `InitialState`,
`PhysicalParameters`, `EventSchedule`, `FixedEventMask`, `FreeEvents`,
`FixedEvents`, `FreeReturnTime`, `FixReturnTime`, `MinimumGap`,
`StartSectionId`, and `StopSectionId`. A complete `EventSchedule` takes
precedence over masks. The free count must equal the explicit contact plus
section residual dimension.

Section-pair support is provider-specific. The tutorial implements
`apex`-to-`apex` and `height_descending`-to-`height_descending`; it rejects
named-event endpoints and the ambiguous apex-to-descending occurrence. The
quadruped, biped, and quad-load timing providers are apex-only to preserve the
migrated source formulation and reject non-apex requests before solve. Catalog
membership alone does not imply timing-provider support.

`ContactTimingService.solve` additionally accepts ordinary solver options and
`MultistartCount`/`MultistartScale`. The random sequence is determined by
`RunContext.RandomSeed`.

## Multi-stride request and policies

`MultiStrideRequest` fields are `NumberOfStrides`, `InitialDecision` or
`StridePlan`, `CompletionPolicy`, `EnergyPolicy`, `EnergyNeutralOnly`,
`FailurePolicy`, `StartSectionId`, `StopSectionId`, `ProviderCallback`,
`ParameterOverrides`, `DeclaredWork`, `MaximumStrides`, and `Provenance`.
Specifying both input forms is invalid; exceeding `MaximumStrides` is rejected.

Completion policies are `error_if_missing`, `carry_forward`,
`carry_forward_and_solve_timings`, `predictor_corrector`, `request_user`, and
`provider_callback`. Failure policies are `return_partial` and `error`.
`request_user` returns structured missing state; it never invokes a UI.

Energy-policy IDs are `energy_neutral_only`, `declared_work`, and
`allow_non_neutral`. `EnergyNeutralOnly=true` conflicts with
`allow_non_neutral`. Unknown energy effects are rejected under every policy.
Runtime callbacks are not serialized.

### Load N-stride optimization configuration

`slip_quad_load/n_stride_fit` accepts `NumberOfStrides`, a complete
`InitialDecision` or `StridePlan`, `ReferenceExtensionPolicy`,
`ActiveOptimizationIndices`, and `InitialPerturbation`. The exact decision
length is `44 + 13*(N-1)`. An incomplete/fallback plan is rejected before the
optimizer starts, and objective evaluation keeps the supplied timings fixed
with `HiddenTimingSolve=false`. Nonlinear constraints expose nine explicit
contact/section rows per stride.

The bundled reference contains two measured strides. For `N>2`, callers must
explicitly choose `ReferenceExtensionPolicy='repeat_final_reference'`; this is
synthetic, experimental, and not source-equivalent. The separate validated
`multi_stride_fit` compatibility problem is restricted to the exact bundled
two-stride vector and retains the legacy timing projection with
`HiddenTimingSolve=true`.

When no plan/vector is supplied, the default two-stride `n_stride_fit` uses a
hash-bound corrected timing seed captured in the repository; it does not solve
timings at runtime. Repeating its final 13-entry block demonstrates a
three-stride schema, but does not by itself satisfy the new nine timing rows.

## Hybrid simulator options

`HybridSimulator.simulate(system, request, context, options)` accepts:

| Option | Default | Meaning |
|---|---:|---|
| `RelativeTolerance` | `1e-9` | ODE relative tolerance |
| `AbsoluteTolerance` | `1e-11` | ODE absolute tolerance |
| `MaximumStep` | `0.02` | Maximum continuous-flow step |
| `DuplicateTimePolicy` | `post` | Keep final post-event public sample |

The request is a scalar struct with increasing `TimeSpan`, `Parameters`, and
model-defined declarative values such as `Decision`. Unknown options are
rejected.

## Solver and continuation configuration

`SolveService.solve` accepts either `SolverOptions` or its scalar-struct form.
`ContinuationService.run` accepts `ContinuationOptions` or a scalar struct.
Use schema scales and bounded point counts. Callback fields belong to trusted
run configuration and are stripped when reproducing persisted continuation
runs. Optimization options are translated through `lmz.compat.Optimization`.

## Scene configuration

Scene schema `1.0.0` declares `frames` and `primitives`. Supported primitives,
fields, aliases, and limits are listed in
[visualization-authoring.md](visualization-authoring.md). Bindings are simple
identifiers, never MATLAB expressions.

## Graphics configuration

A visualizable model may provide `catalog/<model-id>/graphics.lmz.json`.
`ModelRegistry` parses and validates it during discovery, binds its named
requirements to `manifest.json.visualizationContract`, and repeats that binding
when `getGraphicsConfig(modelId)` returns the parsed configuration. If the file
is absent, the registry synthesizes one `clean_generic` profile for all four
maturities using the model's `scene.lmz.json`; constructing that declarative
renderer still requires the model to return a visualization `PlotPlugin`.

The root object uses graphics schema `1.0.0`:

| Field | Required | Contract |
| --- | --- | --- |
| `schemaVersion` | yes | Exactly `1.0.0` |
| `defaultProfileByMaturity` | yes | Object mapping known maturities to declared profile IDs |
| `profiles` | yes | One to 32 profile objects with unique IDs |
| `requiredFrames` | no | Simple identifier list bound to manifest `visualizationContract.frames` and required from each declared profile scene |
| `requiredParameters` | no | Top-level parameter-root identifiers bound to manifest `visualizationContract.parameters` |

Known maturities are `tutorial`, `compatibility`, `validated`, and
`experimental`. Every graphics configuration must contain all four mappings,
and each default must name an existing profile that lists that maturity.
`defaultForMaturity` has no tutorial-or-first-profile fallback: an incomplete
mapping fails configuration loading. Tutorial behavior is therefore explicit:
built-in tutorial problems map to `clean_generic`, and a model without a
graphics file receives the synthesized all-maturity `clean_generic` profile.
The manifest does not select a profile. External models with a graphics file
use that file's complete maturity mapping just like built-ins.

Profile IDs, plot-profile IDs, layer names, overlay names, frame names, and
required-parameter names are simple identifiers matching
`^[A-Za-z][A-Za-z0-9_]*$`. They are data labels, not expressions.

### Profile object

Each profile requires:

| Field | Contract |
| --- | --- |
| `id` | Unique simple identifier |
| `label` | Nonempty GUI label |
| `rendererClass` | Trusted class name, described below |
| `camera` | Camera object using the allowlist below |
| `axis` | Axes object using the allowlist below |
| `layers` | Ordered list of known layer identifiers |
| `overlays` | List of known optional overlays |
| `plotProfile` | Simple identifier passed to model plot code |
| `recordingProfile` | Declarative recording metadata object |
| `maturities` | Nonempty list of known applicable maturities |

The optional `sceneFile` and `styleFile` fields are relative paths contained by
the model catalog directory. An empty or absent `sceneFile` is normal for a
custom renderer. `lmz.viz.SceneRenderer2D` requires a model visualization
plugin; when `sceneFile` is present, the factory uses that validated scene.
Scene and style JSON remain data only: their contents are never evaluated as
callbacks, expressions, arbitrary constructor arguments, or class definitions.

The only framework renderer allowed directly from JSON is
`lmz.viz.SceneRenderer2D`. Its unique resolution must be inside the framework
`src` root. Every other class names already-trusted executable model/plugin code
and must:

- begin with the namespace registered for that catalog/code root;
- resolve exactly once on the MATLAB path;
- resolve inside the registered trusted code root; and
- implement the stable renderer lifecycle checked by `RendererFactory`.

For built-ins the registered prefix is `lmzmodels`. For an explicitly
registered external plugin it is exactly the isolated namespace in
`plugin.json` (for example `lmzmodels.example_hopper` or an `lmzplugins.*`
namespace). Discovery rejects missing, ambiguous, namespace-escaping, and
root-escaping renderer classes before profile use. `RendererFactory` then
constructs the selected class and checks the public renderer lifecycle. These
checks establish binding and provenance; trusted MATLAB plugin code is still
executable code and is not sandboxed.

### Camera fields

The camera allowlist is:

| Field | Validation |
| --- | --- |
| `xLimits`, `yLimits` | Two finite increasing numeric values |
| `dataAspectRatio` | Three finite positive numeric values |
| `follow` | Logical scalar |
| `followWindow` | Positive finite scalar width, or two finite increasing offsets |
| `position` | `[x y width height]` with finite values and positive width/height |

Custom renderers decide how a valid `followWindow` or `position` maps to their
camera. Unknown fields fail configuration loading.

### Axis fields

The axis allowlist is:

| Field | Validation |
| --- | --- |
| `equal`, `grid`, `visible` | Logical scalar |
| `xLabel`, `yLabel`, `title` | Character text |
| `backgroundColor` | RGB or RGBA in `[0,1]` |

### Layers and overlays

Known layer identifiers are:

```text
ground, shadow, model, body, legs, com, load, rope,
forces, phase, labels, overlay
```

Known overlay identifiers are:

```text
detailed_phase, phase_labels, force_vectors, contacts, trajectory
```

The ordered `layers` declaration is metadata and policy. A custom renderer is
responsible for matching its handle creation/z-order to that declaration and
for testing the order. `SceneRenderer2D` uses primitive order from the scene.

### Recording profile

Known fields are `frameCount`, `fps`, `dpi`, and `backgroundColor`. Numeric
values must be finite and positive; color is RGB/RGBA in `[0,1]`. The GUI maps
these defaults into applicable recording requests: `frameCount` for GIF/MP4,
`fps` to GIF delay or MP4 FPS, and `dpi` to capture/export resolution. Explicit
request options take precedence. Direct `RecorderService` calls remain governed
by the options supplied to the call because the service does not resolve a
profile itself.

GIF/MP4, keyframe, plot, and axes-GIF calls write `<target>.lmz.json` when the
caller supplies a nonempty `Metadata` struct. The GUI supplies artifact kind,
model/problem IDs, the resolved visualization-profile descriptor, and creation time for
animation, keyframe, static-plot, and oscillator-GIF exports. Direct service
callers must supply equivalent metadata explicitly.

### Style files

A style file is one bounded JSON object. Validation is recursive for nested
objects:

- numeric values must be real and finite;
- names ending in `color` must contain RGB or RGBA values in `[0,1]`;
- names ending in `width`, `size`, `radius`, `length`, or `scale` must be
  positive;
- names ending in `alpha` must lie in `[0,1]`; and
- character, logical, and cell values are accepted as declarative metadata.

The renderer defines the semantic shape of its style object and should merge it
with deterministic defaults. Keep inherited scientific constants in style or
pure geometry providers, not in generic GUI code.

### Required frames and parameters

These lists form a two-stage binding rather than an executable lookup language:

1. `GraphicsConfig.validateContract` requires every graphics
   `requiredFrames`/`requiredParameters` name to be declared by the manifest's
   `visualizationContract.frames`/`.parameters` list.
2. For every profile with a nonempty `sceneFile`, configuration loading also
   requires every `requiredFrames` name to occur in that validated scene.

Profiles backed only by a custom renderer have no profile scene to check, but
they remain bound to the manifest contract. Runtime providers are responsible
for producing the declared named frames and for retrieving and validating the
declared top-level parameter roots from `SimulationResult.Parameters`; the
registry does not inspect a future simulation result while loading metadata.
Neither list accepts state-vector positions, dotted paths, or expressions.

For example, the load model declares the parameter roots
`per_stride_parameters`, `quadruped`, and `load`. Nested values inside those
containers are renderer/provider concerns; names such as `leg_length` or
`back_attachment_ratio` would be incorrect contract entries unless they were
actual top-level `SimulationResult.Parameters` fields.

### Built-in default policy

The built-in scientific configurations select `research_legacy` for all
validated problems:

```text
slip_quadruped/periodic_apex
slip_biped/periodic_apex
slip_biped/trajectory_fit
slip_quad_load/single_stride
slip_quad_load/multi_stride_fit
```

Their tutorial `demo_stride` problems select `clean_generic`.
`tutorial_hopper/demo_hop` and `tutorial_hopper/periodic_hop` also select
`clean_generic`. `high_contrast` is an explicit alternative only where its
`maturities` list makes it applicable; the GUI filters the list accordingly.
If a saved GUI preference is absent from that filtered list, the GUI restores
the problem's declared maturity default. This preference recovery is not a
fallback for an incomplete `defaultProfileByMaturity` object; incomplete
graphics policy is rejected during loading.

`research_legacy` is source-derived geometry and styling, `clean_generic` is a
deliberately simplified generic/clean view, and `high_contrast` is a deliberate
accessibility adaptation. A high-contrast research renderer is not a claim that
its palette matches the source.

### Resolution API

```matlab
registry = lmz.registry.ModelRegistry.discover();
profiles = lmz.viz.VisualizationProfileRegistry(registry);

available = profiles.profilesForProblem(modelId, problemId);
defaultProfile = profiles.defaultProfile(modelId, problemId);
selected = profiles.resolve(modelId, problemId, profileId);
factory = lmz.viz.RendererFactory(registry, profiles);
[renderer, selected] = factory.createRenderer(axesHandle, simulation, ...
    modelId, problemId, profileId, options);
```

An empty `profileId` resolves the maturity default. An explicit but
inapplicable profile raises `lmz:Graphics:ProfileNotApplicable`; unknown IDs,
untrusted/ambiguous classes, traversal, malformed colors, and invalid cameras
fail before renderer construction.

Graphics configuration remains independent of source checkouts. Source paths
belong only in provenance records and maintainer capture tools, never in normal
runtime configuration.

## Input limits

`SafeJson` defaults to 1 MiB, nesting depth 32, and 100,000 decoded items.
`SafeMat` defaults to 512 MiB, depth 64, and 20,000,000 aggregate elements.
MAT values are restricted to bounded numeric/logical/character/string/cell and
plain-struct data. Function handles and objects are rejected before application
use. MATLAB can deserialize a nested object during `load`, before the recursive
check runs, so intentionally hostile MAT serialization requires process
isolation; this loader is validation, not a sandbox.
