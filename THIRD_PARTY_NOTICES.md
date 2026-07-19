# Third-party notices

## DLARlab SLIP quadruped RoadMap and compatibility equations

- Source: `https://github.com/DLARlab/SLIP_Model_Zoo.git`
- Source commit: `2c106101383ecee1b2a9d695efe09fbd72d5718a`
- Copied data: complete quadruped `1_Roadmap` folder (nine MAT, two FIG)
- Migrated runtime: quadruped zero function, event-time regulation, and point gait classification compatibility code
- Attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse Quadrupedal Gaits,” IEEE RA-L 9(5), 4782–4789 (2024), DOI `10.1109/LRA.2024.3384908`

No LICENSE, COPYING, NOTICE, or redistribution grant was found in the source repository. The local migration was performed under the user's explicit Round 5 request. No open-source license is inferred, and redistribution remains subject to separate owner/legal review.

The two copied FIG files are reference-only and predate part of the current MAT data. The manifest MAT files are the numerical authority.

Per-file compatibility-code record:

| Local file | Upstream file | Adaptation |
|---|---|---|
| `models/+lmzmodels/+slip_quadruped/+legacy/QuadrupedalZeroFun.m` | `SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m` | Package-safe name; invoked by the native boundary with `skipSolve`. Embedded alpha/stance/swing/GRF helpers retained. |
| `models/+lmzmodels/+slip_quadruped/+legacy/EventTimingRegulation.m` | `SLIP_Quadruped/4_Solution_Management/EventTimingRegulation.m` | Package-safe name. |
| `models/+lmzmodels/+slip_quadruped/+legacy/GaitIdentification.m` | `SLIP_Quadruped/4_Solution_Management/Gait_Identification.m` | Package-safe names; equivalent colon indexing replaces `downsample`. |

All three records use source commit `2c106101383ecee1b2a9d695efe09fbd72d5718a`. The complete 11-asset data record is in `roadmap_manifest.json`; this notice does not replace its per-file digests.
