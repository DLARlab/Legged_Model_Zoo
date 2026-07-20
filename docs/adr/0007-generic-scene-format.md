# ADR 0007: Declarative generic 2-D scene format

- Status: accepted
- Decision date: 2026-07-19

## Context

Hard-coded renderer selection prevents third-party visualization. Allowing
expressions in scene files would turn display data into executable code.

## Decision

Scene JSON version `1.0.0` declares unique frame names and an allowlisted set
of ground, polygon, marker, line, spring, rope, force-vector, trail, and text
primitives. Bindings are simple identifiers. `KinematicsFrame` supplies finite
poses/vectors, `PlotPlugin` owns model mapping and named plots, and
`SceneRenderer2D` reuses framework graphics handles.

Legacy `point_mass`, body, point, and link names normalize to canonical types.
No expression, callback, class, or function name is read from scene JSON.

## Consequences

An external model can animate through the GUI without a model-ID switch. Scene
files remain inspectable, bounded data. Scientific renderer classes stay in
place as visual regression oracles while tutorials can adopt the generic path.
