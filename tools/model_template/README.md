# Model template

`tools/new_model.m` renders this template into a self-contained external Legged
Model Zoo plugin. Generated projects are inactive until their root is explicitly
passed to `ModelRegistry.discoverWithPlugins`; generation does not edit the core
registry. Placeholder text is replaced as plain text and is never evaluated.

## Generate an external model

From the Legged Model Zoo repository root:

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(), 'tools'));

pluginRoot = fullfile(tempdir, 'my_lmz_plugin');
if exist(pluginRoot, 'dir') ~= 7
    mkdir(pluginRoot);
end
report = new_model('example_hopper', pluginRoot);
```

The model ID must be a new lowercase MATLAB-safe identifier matching
`^[a-z][a-z0-9_]*$`. The output root must already exist. The generator refuses
reserved/core IDs, traversal, collisions, and accidental production-catalog
activation.

Discover only the reviewed generated root:

```matlab
registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
    pluginRoot, 'IncludeBuiltIns', false);
model = registry.createModel('example_hopper');
```

External plugin MATLAB is trusted executable code. Review it before discovery;
namespace/path containment is a provenance boundary, not a sandbox.

## Generated layout

```text
plugin.json
models/+lmzmodels/+<model-id>/
  Model.m
  PhysicalStateSchema.m
  ParameterSchema.m
  PeriodicProblem.m
  ModelPlotPlugin.m
catalog/<model-id>/
  manifest.json
  problems/demo_stride.json
  problems/periodic_orbit.json
  scene.lmz.json
  graphics.lmz.json
  graphics/clean_generic_style.json
  graphics/high_contrast_style.json
tests/generated/<model-id>/TestGeneratedModel.m
examples/demo_<model-id>.m
```

The generated project contains one analytic simulation/periodic problem, named
schemas, an executable example/test, a generic plot plugin, and declarative
graphics. It contains no research-fidelity claim or source-derived geometry.

## Generated visual profiles

`graphics.lmz.json` declares:

| Profile | Renderer | Default/applicability |
| --- | --- | --- |
| `clean_generic` | `lmz.viz.SceneRenderer2D` | Default for tutorial, compatibility, validated, and experimental maturities |
| `high_contrast` | `lmz.viz.SceneRenderer2D` | Optional generic accessibility style for the same maturities |

Both profiles use `scene.lmz.json` and `ModelPlotPlugin`. The scene declares
named `world` and `body` frames with ground, body marker, and trail primitives.
The plugin converts each simulation index to `KinematicsFrame` and provides one
named trajectory plot. The generated `manifest.json` declares
`visualizationContract.frames = ["world", "body"]` and an empty parameter-root
list; `graphics.lmz.json.requiredFrames` repeats those required names.

Registry discovery validates the manifest contract first, requires the
graphics required-name lists to be subsets of it, and checks every profile
scene for the required frames. The four maturity mappings in
`defaultProfileByMaturity` are all mandatory; the generated tutorial choice is
explicit, not an implicit fallback.

If an author deliberately removes `graphics.lmz.json`, the registry synthesizes
one `clean_generic` profile for every maturity from the base scene. That is the
configuration-level automatic synthesis; `manifest.json` does not select a
profile, and an explicit graphics file with a missing maturity mapping is
rejected.

Validate profile resolution after generation:

```matlab
graphics = registry.getGraphicsConfig('example_hopper');
assert(strcmp(graphics.defaultForMaturity('experimental'), ...
    'clean_generic'));

profiles = lmz.viz.VisualizationProfileRegistry(registry);
profile = profiles.resolve('example_hopper', 'periodic_orbit', ...
    'high_contrast');
```

## Customize the generic scene

Edit these generated files together:

1. Add named poses/vectors in `ModelPlotPlugin.kinematicsFrame`.
2. Add matching frame names and allowlisted primitives in `scene.lmz.json`.
3. Add those names to `manifest.json.visualizationContract.frames`, then keep
   `graphics.lmz.json.requiredFrames` synchronized with the manifest contract
   and every profile scene.
4. Declare top-level `SimulationResult.Parameters` roots in both
   `manifest.json.visualizationContract.parameters` and
   `graphics.lmz.json.requiredParameters`; do not use dotted/nested names.
5. Put palette/width/marker changes in the profile style JSON files.
6. Add stable plot descriptors and route each descriptor ID in `plot`.

Scene JSON may contain ground, polygon, marker, line, spring, rope,
force-vector, trail, and literal text primitives. It may not contain callbacks,
expressions, anonymous functions, or state-vector indices. Kinematics stays in
trusted model MATLAB and should use named states/parameters.

## Add a custom renderer

Use a custom renderer when compound geometry or special z-order cannot be
represented by the generic primitives:

1. Add a class inside the registered model namespace/code root.
2. Derive it from `lmz.viz.Renderer`; use `lmz.viz.ResearchRenderer` only for a
   documented source-derived profile.
3. Implement protected `buildHandles` and `updateHandles` methods.
4. Accept constructor arguments `(axesHandle, simulation, profile, options)`.
5. Add a profile whose `rendererClass` names that class and whose `sceneFile`
   is empty/absent.
6. Retain `clean_generic` and map tutorial maturity to it explicitly unless
   there is a documented reason not to.

For this generated external plugin, a custom class must begin with the
isolated namespace declared by `plugin.json` (`lmzmodels.<model-id>`), resolve
exactly once, and live under the registered plugin code root. The only core
framework renderer permitted by graphics JSON is `lmz.viz.SceneRenderer2D`.
These checks bind trusted code; they do not sandbox it. Keep the base
`scene.lmz.json` valid even if every selected profile is custom, because the
current registry validates that scene for every visualizable model.

The renderer must create each axes child once, mutate graphics data on update,
and delete only its own axes children. It must not create/clear the containing
figure, run an animation loop, interpolate simulation results, manage output
paths, or own a video/GIF writer.

## Add a research-fidelity profile

Do not rename a generic scene to `research_legacy`. A defensible research
profile needs:

- an audited source construction/update call path and pinned provenance;
- pure numeric geometry providers using `PatchGeometry`, `PolylineGeometry`,
  or `LayeredGeometry`;
- inherited constants in providers or validated style files;
- numeric vertices/faces/paths/layer/camera fixtures;
- a trusted custom renderer that preserves the reviewed layer/update behavior;
- explicit source-faithful versus deliberate-deviation documentation; and
- maturity/default policy that selects it only for the validated problems to
  which it actually applies.

Keep source checkouts out of normal runtime/tests. Maintainer capture scripts
may use them to regenerate reviewed numeric fixtures. A high-contrast research
profile should keep the same compound geometry and document its palette/width
changes as accessibility adaptations.

## Plot profiles

`plotProfile` is a stable identifier passed with the selected visualization
profile. The generated plugin may inspect `options.Profile` in its `plot`
method. If you add source-style plots, keep their channel order, labels, scaling,
aspect, and qualifications separate from modern clean/enrichment views.
Animation fidelity does not automatically make every diagnostic plot
source-faithful.

## Recording

The framework owns playback and recording. Use `RendererFactory` to construct
the selected renderer and pass it to `RecorderService`. The GUI maps profile
`frameCount`, `fps`, and `dpi` defaults into applicable requests and writes a
`.lmz.json` sidecar containing the resolved profile descriptor for animation,
keyframe, plot, and axes-GIF exports.

Direct recorder calls must supply profile metadata explicitly; operational
options may be supplied or left to service defaults:

```matlab
metadata = struct('schemaVersion', '1.0.0', ...
    'modelId', 'example_hopper', 'problemId', 'periodic_orbit', ...
    'visualizationProfile', profile.toStruct());
lmz.services.RecorderService().recordGif(renderer, target, ...
    struct('FrameCount', 40, 'DelayTime', 0.04, ...
    'Metadata', metadata));
```

## Verify the generated project

```matlab
results = runtests(fullfile(pluginRoot, 'tests', 'generated'), ...
    'IncludeSubfolders', true);
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));

run(fullfile(pluginRoot, 'examples', 'demo_example_hopper.m'));
```

Also test:

- graphics-config discovery and maturity defaults;
- both `clean_generic` and `high_contrast` through `RendererFactory`;
- classic axes and UIAxes on the supported runtime release;
- repeated frame updates without handle growth;
- profile switch/delete cleanup;
- recording sidecar contents and frame restoration; and
- clean discovery/removal of the external root.

The framework targets MATLAB R2019b, but current R2019b graphics evidence is
static/fallback-only. Avoid post-R2019b graphics APIs or route them through LMZ
compatibility adapters, and do not claim R2019b runtime support until the
generated plugin has actually run there.
