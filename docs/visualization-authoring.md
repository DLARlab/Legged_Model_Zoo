# Visualization authoring

Visualization is split into model-owned kinematics and a framework-owned scene
renderer. JSON describes appearance and references; it never contains
callbacks or expressions.

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

`SceneSpec.fromJson` uses bounded JSON loading, and `SceneValidator` checks
unique frames, references, allowed fields, finite geometry, and count limits.
Binding names must match `^[A-Za-z][A-Za-z0-9_]*$`. `point_mass`, `body`,
`point`, and `link` are normalized legacy aliases.

## Primitives

Supported canonical types are:

- `ground`: optional `y` and two-entry `xRange`;
- `polygon`: `frame`, optional finite N-by-2 `vertices`;
- `marker`: `frame`, marker name and size;
- `line`, `spring`, `rope`: `from` and `to` frame names;
- `force_vector`: origin `frame`, named `vector`, optional scale;
- `trail`: historical position of one `frame`;
- `text`: `frame`, bounded literal text, optional offset.

Common appearance values include finite RGB `color` and positive practical
`lineWidth`/`markerSize`. Unknown fields and primitive types fail validation.

## KinematicsFrame

At each simulation index return finite frame poses `[x y]` or `[x y angle]`
plus named 2-D vectors:

```matlab
frames = struct('world',[0 0 0], 'body',[x y pitch], ...
    'foot',[footX footY 0]);
vectors = struct('ground_force',[fx fy]);
frame = lmz.viz.KinematicsFrame(time, index, frames, ...
    'Vectors', vectors);
```

## PlotPlugin and rendering

Derive from `lmz.viz.PlotPlugin` and implement `sceneSpec`,
`kinematicsFrame`, `plotDescriptors`, and `plot`. The inherited
`createRenderer(axes,simulation)` returns `SceneRenderer2D`, which implements
the existing `updateFrame(index)` animation contract and reuses graphics
handles.

Return the plugin from the model's `getVisualizationPlugin`. GUI components
may also call an optional model-specific `plotSimulation` convenience method;
the stable generic surface is the named descriptor `plot` method.

The built-in complete example is
`models/+lmzmodels/+tutorial_hopper/HopperPlotPlugin.m`. Its independently
registered external counterpart is
`tests/fixtures/external_plugins/analytic_hopper/models/+lmzplugins/+analytic_hopper/HopperPlotPlugin.m`.
The quadruped analytic tutorial is also exercised through
`QuadrupedScenePlugin`; `QuadrupedRenderer` remains the scientific regression
oracle.

## Accessibility

Do not encode contact or selection by color alone. Combine color with marker,
line style, text, or shape. Use palette-aware contrast and layouts that remain
legible after resizing and high-DPI scaling.
