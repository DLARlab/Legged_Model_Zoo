# Provenance

Immutable reference repositories selected from the common workspace root:

| Model | Local path | Origin | Commit |
|---|---|---|---|
| SLIP quadruped | `../SLIP_Model_Zoo` | `https://github.com/DLARlab/SLIP_Model_Zoo.git` | `2c106101383ecee1b2a9d695efe09fbd72d5718a` |
| Jerboa | `../2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` | `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git` | `4595146c5881a5313bc8fe92de85099193ef9be9` |
| Load-pulling quadruped | `../2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` | `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git` | `19f3133073c988cc0c3424a647b4adbb60a90b99` |

Round 5 copies the complete quadruped `1_Roadmap` folder: nine MAT branches, two reference FIG files, and no Finder metadata. `roadmap_manifest.json` records all source hashes. Round 6 additionally copies six biped GaitMap MAT branches, two biped trajectory-fit MAT inputs, one 44-entry load single-stride MAT, and one 57-entry load transition MAT. Their manifests record source paths, commits, exact dimensions, hashes, and native artifact paths. All three source repositories were clean before capture and are checked again after validation.

## Round 9 section and multi-stride provenance

Round 9 introduces native framework classes, catalogs, guides, and examples;
it copies no additional upstream code, datasets, graphics, or raster assets.
The scientific apex compatibility evaluators and repository fixtures remain
pinned to the commits above. New scientific section/timing descriptors record
their source problem and commit but receive their own maturity/validation
status; they do not inherit `source-equivalent` merely by sharing an apex
evaluator.

The quad-load stride-plan adapter preserves the captured `X_accum` layout and
uses the two repository-contained datasets as its only built-in data.
Carry-forward can structurally generate native blocks beyond the measured
two-stride reference, but copied schedules are labeled synthetic and are not
validated returns. The public predictor-corrector attempt stops at the
stride-three trust-region boundary rather than inventing a replacement
trajectory. Repeated reference values for an extended fit likewise require
`ReferenceExtensionPolicy='repeat_final_reference'` and are not presented as
new measurements. Artifact section/catalog hashes and plan lineage identify
the exact declarative configuration used without serializing callbacks.

## Round 8 research graphics provenance

Round 8 does not copy the legacy handle-owning graphics classes into normal
runtime. It adapts their numeric geometry and visual constants into pure model
providers, deterministic styles, and native renderer lifecycle classes. The
quadruped graphics map is pinned to `DLARlab/SLIP_Model_Zoo` commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a`; the biped map is pinned to
`DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` commit
`4595146c5881a5313bc8fe92de85099193ef9be9`; and the load-specific map is
pinned to `DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights`
commit `19f3133073c988cc0c3424a647b4adbb60a90b99`.

| Local provider/composition | Pinned upstream graphics source | Adaptation or qualification |
|---|---|---|
| `lmzmodels.slip_quadruped.ResearchBodyGeometry` | `SLIP_Quadruped/2_Graphic_ToolBox/SLIP_Quadrupedal_Graphics/GraphicFunctions/ComputeBodyGraphics.m` | Pure 80-vertex body, shading faces, outline, skew, rotation, and translation. |
| `lmzmodels.slip_quadruped.ResearchLegGeometry` | `SLIP_Quadruped/2_Graphic_ToolBox/SLIP_Quadrupedal_Graphics/GraphicFunctions/ComputeLegGraphics.m` and `ComputeJoint_LegLA.m` in the same directory | Pure six-layer compound-leg geometry plus named hip, angle, length, strict-contact, and one-wrap event access. |
| `lmzmodels.slip_quadruped.ResearchCOMGeometry` | `SLIP_Quadruped/2_Graphic_ToolBox/SLIP_Quadrupedal_Graphics/GraphicFunctions/SLIP_Animation_Quad.m`, COM construction/update | Source outer and quartered inner symbol represented as indexed faces. |
| `lmzmodels.slip_quadruped.ResearchGroundGeometry` | `SLIP_Quadruped/2_Graphic_ToolBox/SLIP_Quadrupedal_Graphics/GraphicFunctions/SLIP_Animation_Quad.m`, ground construction | Source field and one dense 20,002-vertex/5,001-face hatch; built once rather than as independent stripe handles. |
| `lmzmodels.slip_quadruped.ResearchPhaseDiagramGeometry` | `SLIP_Quadruped/2_Graphic_ToolBox/SLIP_Quadrupedal_Graphics/GraphicFunctions/ComputePhaseDiagram.m` | Source box, labels, BL/BR/FL/FR ordering, and wrapped bars; equal touchdown/liftoff is defined as an empty bar because the source leaves it undefined. |
| `lmzmodels.slip_biped.ResearchBodyGeometry` | `Stored_Functions/Graphics/DrawBody.m` and `SetDrawBody.m` | Pure post-update radius-0.2 body vertices. |
| `lmzmodels.slip_biped.ResearchCOGGeometry` | `Stored_Functions/Graphics/SLIP_Model_Graphics_PointFeet_BipedalDemo.m`, COG construction/update | Four source quadrant columns flattened into four explicit faces. |
| `lmzmodels.slip_biped.ResearchLegGeometry` | `Stored_Functions/Graphics/DrawLegsPointFeet.m`, `DrawLegsLeftPointFeet.m`, `SetDrawLegsPointFeet.m`, and `SLIP_Model_Graphics_PointFeet_BipedalDemo.m` | Primary output preserves the shared post-update formula actually used for both legs; constructor-only asymmetry remains separately measurable. |
| `lmzmodels.slip_biped.ResearchGroundGeometry` | `Stored_Functions/Graphics/SLIP_Model_Graphics_PointFeet_BipedalDemo.m`, ground construction | Exact white mask and dense hatch geometry. |
| Load renderer shared quadruped composition | `Stored_Functions/Graphics/ComputeBodyGraphics.m`, `ComputeJoint_LegLA.m`, `ComputeLegGraphics.m`, and shared COM/ground construction in `SLIP_Animation_Quad_Load.m`; the three helper files are byte-identical to the pinned quadruped versions | Reuses the quadruped providers rather than duplicating equations; this composition therefore references both pinned source families. |
| `lmzmodels.slip_quad_load.ResearchLoadGeometry` | `Stored_Functions/Graphics/ComputeLoadGraphics.m` | Pure four-vertex load using source `load_y` half-width/half-height behavior. |
| `lmzmodels.slip_quad_load.ResearchRopeGeometry` | `Stored_Functions/Graphics/SLIP_Animation_Quad_Load.m`, `DrawRopeLoad`/`SetRopeLoad` | Retains the four duplicated endpoints as the source zero-area patch rather than simplifying it to a line. |

`ResearchStyle.m` and `graphics/research_legacy_style.json` under each
scientific model preserve the source colors, widths, alpha, camera, and layer
intent associated with those mappings. Where the source relies on MATLAB
patch defaults, the research profiles freeze the documented dark outline and
ground intent as explicit RGB black so results do not change with MATLAB
release or theme. The `high_contrast` files are local accessibility
adaptations that retain the research geometry and source layer structure; they
are conservatively treated as derivatives of the same source graphics while
authority is pending. The `clean_generic` scenes/styles are native LMZ
material and are not presented as source graphics.

The quadruped source does not call `axis equal`; Round 8 explicitly requires
equal aspect for its research profile. That camera choice is an intentional
prompt-level deviation, not a claim of exact source axis behavior. The biped
source and target both use equal aspect. The load target retains the source
plot-box aspect `[2,1,1]` rather than replacing it with equal aspect.

Maintainer-only numeric capture is implemented by
`tools/maintainers/capture_quadruped_graphics_baselines.m`,
`capture_biped_graphics_baselines.m`, and
`capture_quad_load_graphics_baselines.m`. Each verifies the exact commit and a
clean source checkout before temporarily adding only the required graphics
directory. Their default outputs are the respective
`tests/fixtures/graphics/<model>/source_capture.json` files and contain numeric
vertices, faces, endpoints, camera/style constants, and summaries. Primary
regression tests additionally consume the reviewed source-derived fixtures
`slip_quadruped/source_geometry_r2025b_macos_arm64.json`,
`slip_biped/source_canonical_full.json` plus `ground_summary.json`, and
`slip_quad_load/source_geometry.json`. Those primary fixtures are not the
capture scripts' current default output paths, so changing or regenerating
them requires an explicit source-review step. Ordinary tests and runtime do
not access the sibling source repositories.

`tools/maintainers/compare_research_graphics_images.m` renders matched source
and LMZ frames into a temporary directory, computes normalized RMSE, edge-map
overlap, structural similarity when available, foreground bounding-box
agreement, and color-cluster agreement, then deletes the temporary rasters.
Only non-raster measurement records are retained in
`docs/graphics-comparison/<model>/batch_metrics_r2025b_macos_arm64.json`.
Those JSON files contain scalar metrics, image dimensions/bounds, thresholds,
environment metadata, pass flags, and explicit `sourceImagesStored: false`,
`differenceImagesStored: false`, and `humanApproved: false`; they contain no
pixels or encoded images. No Round 8 source or difference raster is committed.

The adapted geometry providers, source-faithful style constants, numeric
fixtures/fingerprints, and any locally generated source or difference raster
inherit the applicable pinned repository's unresolved redistribution
authority. The non-raster metric JSON remains source-referenced validation
evidence and is not a license grant or human visual approval. The synthetic
performance benchmark in `tools/maintainers/benchmark_research_renderers.m`
is different: it uses repository-contained simulations and has no source
checkout runtime dependency.

The migrated compatibility files are recorded individually:

| Local file | Source path at commit `2c1061…` | Local modification |
|---|---|---|
| `+legacy/QuadrupedalZeroFun.m` | `SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m` | Package-safe primary name; numerical statements and embedded stance/swing, GRF, geometry, parsing, `Func_alphaB_VA_v2`, and `Func_alphaF_VA_v2` functions retained. The native wrapper always requests `skipSolve`. |
| `+legacy/EventTimingRegulation.m` | `SLIP_Quadruped/4_Solution_Management/EventTimingRegulation.m` | Package-safe primary name. |
| `+legacy/GaitIdentification.m` | `SLIP_Quadruped/4_Solution_Management/Gait_Identification.m` | Package-safe primary name/helper call; `downsample(1:N,rate)` replaced by equivalent `1:rate:N` to remove a toolbox-only dependency. |

The source's separately stored `Func_alphaB_VA_v2.m` and `Func_alphaF_VA_v2.m` duplicate the functions embedded in `Quadrupedal_ZeroFun_v2`; only the embedded authoritative copies are active locally. `KinematicsProvider`, renderer lifecycle, and plot code are native implementations. The Round 8 `Research*Geometry` providers adapt the numeric formulas mapped above rather than copying the historical figure/axes-owning graphics classes.

The 11 copied data/figure filenames, source paths, byte counts, SHA-256 values, kinds, and inferred gait summaries are enumerated in `examples/data/slip_quadruped/RoadMap/roadmap_manifest.json`. Nine native artifacts are derived local products and retain the corresponding source digest.

Source baselines were captured for PK columns 1, 267, and 446 in an isolated maintainer operation. They include residuals, duplicate-time trajectories, event states, all 12 GRF columns, and gait classification. Tests do not access the sibling repository.

## Biped migration record

The biped runtime adapts the source apex zero function and its hybrid
dynamics/event/energy/force helpers behind
`lmzmodels.slip_biped.LegacyBipedEvaluator`. Package-safe names and native
result types are the integration changes; the exact 12-decision/two-offset
input and 15-entry residual ordering are preserved. `Results14Adapter` is the
only 14-row branch boundary, and `GaitClassifier` preserves walk/run/hop/skip
and asymmetric-running provenance.

Copied GaitMap assets and SHA-256 values:

| File | Points | SHA-256 |
|---|---:|---|
| `W1.mat` | 215 | `52a6243833851ab9e498b0eb60e5489ab78747a3f9ff05c9be02d5c66e61d6dc` |
| `R1.mat` | 1,121 | `d8f891a0a6da9d3a99a6e202aac1d725a53e47714aed3cf998bdd14b05b2cfd0` |
| `HP1.mat` | 1,015 | `9003caa634b68401b1b0b91b4fef50515d41088a3685cd52db84cd0dfc3adf3e` |
| `SK1.mat` | 51 | `8898f7d209cefc8f80b700701d5a9331201cedaf2ed205af001272b934712c55` |
| `SK2.mat` | 73 | `bb17a9799ec8f407295b40a0d799f64ad793a1a90faedbc571e875b26a617eb7` |
| `AR1.mat` | 492 | `a39312da6db1f7119b7ccd941b6d4c7ac8e7251fb7700431a58b6ec5544df5fa` |

The trajectory-fit inputs are `exp_1802_j30.mat` (SHA-256
`4b16bfc041cc386e9768d035716a0dedb1ff38b7fb7efe70fbf749ce3c5596cc`)
and `sim_1802_j30.mat` (SHA-256
`303aeca45c7717d5745f1c0e436442d2b083edb9162ecbfc69277b1abfe35e23`).
The captured biped equivalence fixture SHA-256 is
`3372368f375b27d9ab35755a00cf93b6c2eedda5048928579470c219a61376d4`.
Ordinary tests use these repository assets only.

## Load-pulling migration record

The load runtime adapts the source multi-stride quadruped/load zero function,
hybrid dynamics/events, GRFs, tugline calculation, and objective/R-squared
terms behind named problems and providers. `FirstStrideLayout`,
`LaterStrideLayout`, and `XAccumAdapter` centralize the exact
`44 + 13*(N-1)` indexing; no runtime component interprets an unnamed tail.

| File | Strides | Length | SHA-256 |
|---|---:|---:|---|
| `P3_Individual_1_TR.mat` | 1 | 44 | `56736cc33ab31a0ab40b3de6783b625a07ebd54f1ae6a561b47aea5e04cd6abe` |
| `P4_TR_RL_Individual_1.mat` | 2 | 57 | `d23bd725a353d7cf1b6339699ed813755867b5dd1a0da213193eb24cb3bdad4b` |

The load fixture captures source single-/multi-stride residual, raw/public
trajectory, event, GRF, tugline, duration, footfall, loading-force, composite,
and guarded R-squared evidence. Ordinary tests and examples never inspect the
sibling source checkout.

The quadruped source repository contains no LICENSE, COPYING, NOTICE,
copyright grant, or redistribution statement. The biped source readme states
CC BY-NC 4.0, but no standalone file clarifies its exact code/data coverage.
The load source readme claims BSD 3-Clause and links a license that is absent
from the audited commit. User authorization records permission to perform this
local migration, not a broader public grant. Packaging remains blocked pending
the explicit owner decisions in `docs/REDISTRIBUTION_STATUS.md`.

Scientific attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse Quadrupedal Gaits,” *IEEE Robotics and Automation Letters* 9(5), 4782–4789 (2024), DOI `10.1109/LRA.2024.3384908`.
