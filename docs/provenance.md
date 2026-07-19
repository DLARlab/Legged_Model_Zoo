# Provenance

Immutable reference repositories selected from the common workspace root:

| Model | Local path | Origin | Commit |
|---|---|---|---|
| SLIP quadruped | `../SLIP_Model_Zoo` | `https://github.com/DLARlab/SLIP_Model_Zoo.git` | `2c106101383ecee1b2a9d695efe09fbd72d5718a` |
| Jerboa | `../2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` | `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git` | `4595146c5881a5313bc8fe92de85099193ef9be9` |
| Load-pulling quadruped | `../2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` | `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git` | `19f3133073c988cc0c3424a647b4adbb60a90b99` |

Round 5 copies the complete quadruped `1_Roadmap` folder: nine MAT branches, two reference FIG files, and no Finder metadata. `roadmap_manifest.json` records all source hashes. The source repository was clean before and after capture.

The migrated compatibility files are recorded individually:

| Local file | Source path at commit `2c1061…` | Local modification |
|---|---|---|
| `+legacy/QuadrupedalZeroFun.m` | `SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m` | Package-safe primary name; numerical statements and embedded stance/swing, GRF, geometry, parsing, `Func_alphaB_VA_v2`, and `Func_alphaF_VA_v2` functions retained. The native wrapper always requests `skipSolve`. |
| `+legacy/EventTimingRegulation.m` | `SLIP_Quadruped/4_Solution_Management/EventTimingRegulation.m` | Package-safe primary name. |
| `+legacy/GaitIdentification.m` | `SLIP_Quadruped/4_Solution_Management/Gait_Identification.m` | Package-safe primary name/helper call; `downsample(1:N,rate)` replaced by equivalent `1:rate:N` to remove a toolbox-only dependency. |

The source's separately stored `Func_alphaB_VA_v2.m` and `Func_alphaF_VA_v2.m` duplicate the functions embedded in `Quadrupedal_ZeroFun_v2`; only the embedded authoritative copies are active locally. `KinematicsProvider`, renderer, and plot code are native reimplementations of named equations and behavior rather than copies of the historical graphics classes.

The 11 copied data/figure filenames, source paths, byte counts, SHA-256 values, kinds, and inferred gait summaries are enumerated in `examples/data/slip_quadruped/RoadMap/roadmap_manifest.json`. Nine native artifacts are derived local products and retain the corresponding source digest.

Source baselines were captured for PK columns 1, 267, and 446 in an isolated maintainer operation. They include residuals, duplicate-time trajectories, event states, all 12 GRF columns, and gait classification. Tests do not access the sibling repository.

The source repository contains no LICENSE, COPYING, NOTICE, copyright grant, or redistribution statement. RoadMap/data/code migration follows the user's explicit Round 5 request; this is recorded as authorization for the local work, not as an OSI license. Redistribution remains blocked pending owner/legal review.

Scientific attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse Quadrupedal Gaits,” *IEEE Robotics and Automation Letters* 9(5), 4782–4789 (2024), DOI `10.1109/LRA.2024.3384908`.
