# Batch graphics comparison evidence

Round 8 compares the pinned source renderers with the migrated
`research_legacy` renderers at matched states, axes, cameras, 640-by-480
figures, and MATLAB R2025b Update 5 on macOS arm64. Geometry-equivalence tests
are the primary fidelity gate; these reports add platform-tolerant raster
evidence.

| Model | Frames | Maximum normalized RMSE | Minimum edge overlap | Minimum foreground-box agreement | Minimum color-cluster agreement |
|---|---:|---:|---:|---:|---:|
| `slip_quadruped` | 5 | 0.067967 | 0.856892 | 0.849379 | 0.972641 |
| `slip_biped` | 7 | 0.012645 | 0.992179 | 1.000000 | 0.987551 |
| `slip_quad_load` | 6 | 0.047254 | 0.895824 | 0.871708 | 0.987968 |

Each model directory contains a JSON report with the source commit, renderer
environment, state and parameter values, raw image dimensions, per-frame
metrics, thresholds, and automated outcome. Run each comparison in a fresh
MATLAB process because the source repositories define incompatible classes
with shared legacy names:

```matlab
startup;
addpath(fullfile(pwd,'tools','maintainers'));
compare_research_graphics_images('slip_quadruped');
```

Repeat with `slip_biped` and `slip_quad_load`.

The canonical labels are part of the committed report contract. They cover
quadruped flight/apex, one- and two-leg stance, asymmetric morphology and the
detailed phase overlay; biped flight, left, right, wrapped double contact and
the source project's W1/R1/HP1 walk/run/hop examples; and load-model stance,
slack/low-force rope, loaded rope, and before/exact/after stride boundaries.
The quadruped report also contains a target-only `forceVectorsOffOn`
regression because the pinned source animation has no force-vector layer.

The platform-tolerant thresholds are normalized RMSE `<= 0.35`, edge overlap
`>= 0.60`, foreground-box agreement `>= 0.84`, and color-cluster agreement
`>= 0.65`. Geometry-equivalence tests remain the primary gate; the slightly
lower box threshold accommodates font and detailed-overlay extents without
weakening the direct geometry comparisons.

No source, LMZ, clean-generic, or difference raster is committed. The source
projects' redistribution authority remains unresolved, so the maintainer tool
uses temporary images and commits only non-raster measurements. These batch
metrics are automated evidence, not human approval. The desktop side-by-side
checklist remains blocked until a MATLAB desktop is available.
