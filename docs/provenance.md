# Provenance

Immutable reference repositories selected from the common workspace root:

| Model | Local path | Origin | Commit |
|---|---|---|---|
| SLIP quadruped | `../SLIP_Model_Zoo` | `https://github.com/DLARlab/SLIP_Model_Zoo.git` | `2c106101383ecee1b2a9d695efe09fbd72d5718a` |
| Jerboa | `../2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` | `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git` | `4595146c5881a5313bc8fe92de85099193ef9be9` |
| Load-pulling quadruped | `../2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` | `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git` | `19f3133073c988cc0c3424a647b4adbb60a90b99` |

Round 5 copies the complete quadruped `1_Roadmap` folder: nine MAT branches, two reference FIG files, and no Finder metadata. `roadmap_manifest.json` records all source hashes. Round 6 additionally copies six biped GaitMap MAT branches, two biped trajectory-fit MAT inputs, one 44-entry load single-stride MAT, and one 57-entry load transition MAT. Their manifests record source paths, commits, exact dimensions, hashes, and native artifact paths. All three source repositories were clean before capture and are checked again after validation.

The migrated compatibility files are recorded individually:

| Local file | Source path at commit `2c1061…` | Local modification |
|---|---|---|
| `+legacy/QuadrupedalZeroFun.m` | `SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m` | Package-safe primary name; numerical statements and embedded stance/swing, GRF, geometry, parsing, `Func_alphaB_VA_v2`, and `Func_alphaF_VA_v2` functions retained. The native wrapper always requests `skipSolve`. |
| `+legacy/EventTimingRegulation.m` | `SLIP_Quadruped/4_Solution_Management/EventTimingRegulation.m` | Package-safe primary name. |
| `+legacy/GaitIdentification.m` | `SLIP_Quadruped/4_Solution_Management/Gait_Identification.m` | Package-safe primary name/helper call; `downsample(1:N,rate)` replaced by equivalent `1:rate:N` to remove a toolbox-only dependency. |

The source's separately stored `Func_alphaB_VA_v2.m` and `Func_alphaF_VA_v2.m` duplicate the functions embedded in `Quadrupedal_ZeroFun_v2`; only the embedded authoritative copies are active locally. `KinematicsProvider`, renderer, and plot code are native reimplementations of named equations and behavior rather than copies of the historical graphics classes.

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
