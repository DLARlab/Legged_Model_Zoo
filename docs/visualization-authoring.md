# Visualization authoring

Legged Model Zoo supports two complementary visualization paths:

- a declarative scene rendered by `lmz.viz.SceneRenderer2D`; and
- a trusted model renderer selected through a visualization profile.

Use the declarative path for tutorials, compact models, and generic plugin
integration. Use a custom renderer when the model needs compound geometry,
special layer order, source-derived graphics, or update behavior that the
allowlisted scene primitives cannot express. A model may expose either path or
both. JSON describes policy and appearance only; it never contains callbacks,
MATLAB expressions, state-vector indices, or executable constructor arguments.

## Ownership boundary

The framework owns:

- bounded configuration loading and path/namespace validation;
- profile selection by model, problem, and maturity;
- renderer construction through `RendererFactory`;
- GUI controls, renderer replacement, playback, interpolation, and cancellation;
- GIF/MP4/keyframe/static export through `RecorderService`; and
- profile metadata sidecars when the caller supplies recording metadata.

The model owns:

- named kinematic frames and vectors;
- pure geometry providers and their source provenance;
- model-specific renderer and plot implementations;
- style files and the model's `graphics.lmz.json`; and
- the mapping from named states, parameters, modes, and observables to geometry.

A renderer owns only handles below the axes supplied to it. It must not create,
clear, close, or resize the application figure; modify the MATLAB path; run a
playback loop; interpolate results; or own `VideoWriter`/GIF output.

## Choose an authoring pattern

### Generic declarative scene only

Provide `scene.lmz.json`, a `PlotPlugin`, and a `clean_generic` profile whose
`rendererClass` is `lmz.viz.SceneRenderer2D`. This is the default generated-model
pattern and needs no custom renderer.

### Custom renderer only

Provide a profile with a trusted `rendererClass` and omit or leave `sceneFile`
empty for that profile. The renderer constructor must accept:

```matlab
renderer = Constructor(axesHandle, simulation, profile, options)
```

The current registry still requires every model advertising visualization to
ship a valid base `catalog/<model-id>/scene.lmz.json`, even when all selected
profiles use custom renderers. An empty profile `sceneFile` means the factory
does not use a declarative scene for that profile; it does not remove the base
scene discovery requirement.

Keeping a generic profile is strongly recommended for tutorials and external
integration even when the custom renderer is the primary scientific view. Map
the relevant maturities to it explicitly; “fallback” is an authoring pattern,
not an implicit profile-resolution rule.

### Multiple profiles

Declare multiple entries in `graphics.lmz.json`. The built-in scientific
pattern is:

```text
research_legacy  source-derived compound renderer; validated maturity
clean_generic    simple scene/renderer; all relevant maturities
high_contrast    accessibility style, retaining research geometry where offered
```

Profile applicability is explicit through `maturities`. The GUI lists only
profiles applicable to the selected problem and persists the selected profile
per model/problem.

## Graphics configuration

First declare the model-level named interface in
`catalog/<model-id>/manifest.json`:

```json
"visualizationContract": {
  "frames": ["world", "body", "foot"],
  "parameters": []
}
```

Then create `catalog/<model-id>/graphics.lmz.json`. A compact generic example
is:

```json
{
  "schemaVersion": "1.0.0",
  "defaultProfileByMaturity": {
    "tutorial": "clean_generic",
    "compatibility": "clean_generic",
    "validated": "clean_generic",
    "experimental": "clean_generic"
  },
  "requiredFrames": ["world", "body", "foot"],
  "requiredParameters": [],
  "profiles": [
    {
      "id": "clean_generic",
      "label": "Clean generic",
      "rendererClass": "lmz.viz.SceneRenderer2D",
      "sceneFile": "scene.lmz.json",
      "styleFile": "graphics/clean_generic_style.json",
      "camera": {
        "xLimits": [-0.5, 2.0],
        "yLimits": [-0.1, 1.6],
        "dataAspectRatio": [1, 1, 1],
        "follow": false
      },
      "axis": {
        "equal": true,
        "grid": false,
        "visible": true,
        "xLabel": "x",
        "yLabel": "y",
        "title": "Example model",
        "backgroundColor": [1, 1, 1]
      },
      "layers": ["ground", "model", "overlay"],
      "overlays": ["trajectory"],
      "plotProfile": "clean_generic",
      "recordingProfile": {
        "frameCount": 40,
        "fps": 25,
        "dpi": 120
      },
      "maturities": ["tutorial", "compatibility", "validated", "experimental"]
    }
  ]
}
```

Paths are relative to and contained by the model catalog directory. The
only framework class accepted as a `rendererClass` is
`lmz.viz.SceneRenderer2D`; a custom class must use the registered model/plugin
namespace. In either case the class must resolve exactly once inside its
approved framework or trusted code root. See
[configuration-reference.md](configuration-reference.md) for the complete
field and allowlist contract.

Registry discovery validates the binding in this order:

- the manifest contract contains only unique identifier lists and has at least
  one frame;
- graphics `requiredFrames` and `requiredParameters` are subsets of the
  corresponding manifest lists; and
- every profile with a `sceneFile` contains every graphics `requiredFrames`
  entry in its validated scene.

`requiredParameters` entries are top-level roots in
`SimulationResult.Parameters`; custom geometry/providers must still retrieve
and validate their runtime values. For example, the load model declares
`per_stride_parameters`, `quadruped`, and `load`, not nested scalar names.
Neither contract list is a place for numeric state positions, dotted paths, or
expressions.

All four maturity keys are mandatory in `defaultProfileByMaturity`. There is no
tutorial-or-first-profile fallback inside an explicit graphics file. Make the
tutorial choice explicit, normally `clean_generic`. If a visualizable model has
no graphics file, the registry synthesizes one all-maturity `clean_generic`
profile from the base scene; that declarative renderer still needs the model's
`PlotPlugin`.

## Scene schema

Create `catalog/<model-id>/scene.lmz.json`:

```json
{
  "schemaVersion": "1.0.0",
  "frames": ["world", "body", "foot"],
  "primitives": [
    {"type": "ground", "frame": "world", "y": 0},
    {"type": "marker", "frame": "body"},
    {"type": "spring", "from": "body", "to": "foot"}
  ]
}
```

`SceneSpec.fromJson` uses bounded JSON loading. `SceneValidator` checks unique
frames, frame/vector references, allowed fields, finite geometry, and count
limits. Binding names must match `^[A-Za-z][A-Za-z0-9_]*$`. The legacy aliases
`point_mass`, `body`, `point`, and `link` are normalized to canonical types.

### Scene primitives

Supported canonical types are:

- `ground`: optional `y` and two-entry `xRange`;
- `polygon`: `frame`, with optional finite N-by-2 `vertices`;
- `marker`: `frame`, marker name, and size;
- `line`, `spring`, and `rope`: `from` and `to` frame names;
- `force_vector`: origin `frame`, named `vector`, and optional scale;
- `trail`: historical position of one `frame`; and
- `text`: `frame`, bounded literal text, and optional offset.

Common appearance values include finite RGB `color` and positive practical
`lineWidth`/`markerSize`. Unknown fields and primitive types fail validation.
The generic spring is a presentation primitive, not a substitute for a
source-derived compound spring/limb geometry claim.

## KinematicsFrame and PlotPlugin

At each simulation index, return finite frame poses `[x y]` or `[x y angle]`
plus named 2-D vectors:

```matlab
frames = struct('world', [0 0 0], 'body', [x y pitch], ...
    'foot', [footX footY 0]);
vectors = struct('ground_force', [fx fy]);
frame = lmz.viz.KinematicsFrame(time, index, frames, ...
    'Vectors', vectors);
```

Derive a plugin from `lmz.viz.PlotPlugin` and implement:

```text
sceneSpec
kinematicsFrame
plotDescriptors
plot
```

Return it from the model's `getVisualizationPlugin`. `RendererFactory` uses it
when a selected profile declares `lmz.viz.SceneRenderer2D`. Plot descriptors
must have stable IDs; `plot` receives the selected profile ID in its options.
The built-in complete example is
`models/+lmzmodels/+tutorial_hopper/HopperPlotPlugin.m`; the generated template
contains the minimal equivalent.

## Pure geometry for custom renderers

Keep geometry independent from graphics handles. The shared numeric containers
are:

- `lmz.viz.PatchGeometry`: finite N-by-2/N-by-3 vertices and indexed faces;
- `lmz.viz.PolylineGeometry`: ordered finite 2-D/3-D points; and
- `lmz.viz.LayeredGeometry`: an ordered collection of geometry values.

For research-derived graphics, put every inherited constant and formula in a
model-namespaced geometry provider or validated style file. Geometry providers
should accept named physical values and return deterministic numeric data. They
must not access figures, global state, source checkouts, or raw state-vector
indices in generic packages.

Record source repository, commit, file/formula, adaptation, constants, and the
fixture that validates each provider. Source checkouts may be used by
maintainer-only capture scripts but must not be runtime or ordinary-test
dependencies.

## Renderer lifecycle

Custom renderers normally derive from `lmz.viz.Renderer`; source-derived ones
may derive from the marker base `lmz.viz.ResearchRenderer`. Implement the two
protected methods:

```matlab
methods (Access = protected)
    function buildHandles(obj)
        % Create each axes child once and store it in obj.Handles.
    end

    function updateHandles(obj, index)
        % Mutate XData, YData, Vertices, Faces, text, or visibility.
    end
end
```

The inherited public contract is:

```text
initialize, updateFrame, setOptions, setProfile,
frameCount, captureFrame, resetCamera, clear, delete
```

Supported common options are `ShowForces`, `DetailedOverlay`,
`GroundVisible`, `CameraFollow`, `GroundStyle`, and `Palette`. A renderer may
ignore an inapplicable presentation option, but it must not silently reinterpret
scientific data. Preserve child creation order where z-order is meaningful,
reuse handles across frames, and make `clear`/`delete` safe after partial
construction or failure.

`RendererFactory.createRenderer` is the public construction route:

```matlab
registry = lmz.registry.ModelRegistry.discover();
profiles = lmz.viz.VisualizationProfileRegistry(registry);
factory = lmz.viz.RendererFactory(registry, profiles);
[renderer, profile] = factory.createRenderer(axesHandle, simulation, ...
    modelId, problemId, profileId, options);
```

Do not select renderer classes with a GUI `switch modelId` statement. The
factory resolves the selected profile, validates maturity applicability, and
constructs only a class already accepted by `GraphicsConfig`: the single
allowlisted framework scene renderer or a uniquely resolved class under the
registered trusted namespace/code root. It then checks the stable renderer
lifecycle. The JSON remains declarative, but selecting a custom
`rendererClass` invokes trusted executable MATLAB code; plugin registration is
a trust decision, not sandboxing.

## Plot profiles

`plotProfile` is a stable identifier passed with the selected profile. A model
may use it to choose source-style and clean analysis views. Keep the distinction
explicit:

- a source plot reproduces audited labels, channel order, scaling, aspect, and
  layout behavior;
- a clean plot is a modern presentation alternative; and
- an added diagnostic such as a footfall or R-squared view is an LMZ enrichment
  unless it exists in the audited source call path.

Do not describe all plots as source-faithful merely because the animation uses
research geometry.

## Recording and metadata

Renderers never record themselves. `AnimationController` chooses frames and
`RecorderService` performs atomic output, cancellation checks, cleanup, and
frame restoration. `recordGif` and `recordMP4` accept a scalar options struct;
`exportKeyframes` accepts normalized times and a metadata struct.

For direct calls, include the selected profile explicitly:

```matlab
metadata = struct('schemaVersion', '1.0.0', ...
    'modelId', modelId, 'problemId', problemId, ...
    'visualizationProfile', profile.toStruct());
lmz.services.RecorderService().recordGif(renderer, target, ...
    struct('FrameCount', 40, 'DelayTime', 0.04, ...
    'Metadata', metadata), context);
```

When metadata is nonempty, the service writes `<target>.lmz.json` next to the
GIF/MP4, keyframe target, plot, or axes GIF. The GUI supplies profile metadata
for main animation GIF, MP4, keyframe, static-plot, and oscillator-GIF exports.
Direct service callers must opt in.

The GUI maps the declarative `recordingProfile` defaults to applicable service
options: `frameCount` for GIF/MP4, `fps` to GIF delay or MP4 FPS, and `dpi` to
raster capture. An explicit request option takes precedence. Direct
`RecorderService` calls remain governed by the options passed to that call; the
service does not resolve a profile registry itself.

## Source-fidelity claims

Use three separate evidence labels:

1. **geometry-tested**: numeric vertices, faces, paths, layers, camera values,
   and style constants match reviewed fixtures;
2. **image-metric-tested**: a recorded platform/release comparison passes its
   declared tolerant image metrics; and
3. **human-approved**: a person completed the desktop side-by-side checklist.

Do not turn a hidden batch render into a human-approval claim. Document every
deliberate deviation, including deterministic replacement of release-dependent
defaults, service-owned frame loops, generalized stride handling, accessibility
palettes, and modern analysis enrichments. The current scientific mappings are
cataloged in [legacy-graphics-audit.md](legacy-graphics-audit.md).

## Accessibility and compatibility

Do not encode contact, selection, or source/simulation identity by color alone.
Combine color with marker, line style, text, fill, or shape. A high-contrast
research profile should retain scientific geometry while changing only the
documented presentation properties.

Route export, video, and release-sensitive graphics operations through
`lmz.compat.Graphics` and `lmz.compat.Video`. The codebase targets R2019b, but
R2019b graphics execution is not currently verified; only static and forced
fallback evidence is available. Test custom renderers with both classic axes
and UIAxes on the recorded runtime release, and keep the R2019b claim static
until an actual R2019b run is recorded.

## Minimum verification checklist

- Declare manifest `visualizationContract.frames` and `.parameters`, then bind
  the graphics `requiredFrames`/`requiredParameters` subsets through registry
  discovery.
- Load `graphics.lmz.json` through `ModelRegistry.getGraphicsConfig`.
- Verify all four maturity defaults exist and each applies to its maturity.
- Reject duplicate IDs, traversal, ambiguous/untrusted renderer classes,
  malformed colors, and invalid cameras.
- Verify generic scene frame/vector references.
- Compare pure geometry with numeric fixtures before comparing pixels.
- Verify renderer handle count/order is stable across repeated updates.
- Verify profile switching rebuilds without orphaned handles.
- Verify cancellation/error restores the original frame and removes temporary
  recording files.
- Run the generated model/plugin in an isolated external root without adding a
  core registry entry.
- Record hidden-image evidence separately from the pending desktop review.
