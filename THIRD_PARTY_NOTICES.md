# Third-party notices

This notice is informational and does not grant a license. The Legged Model
Zoo framework itself has no owner-supplied root license at this release
candidate. Consequently, neither the core profile nor the scientific profile
is authorized for public redistribution. Temporary packaging tests do not
change that status.

## DLARlab SLIP quadruped RoadMap and compatibility equations

- Source: `https://github.com/DLARlab/SLIP_Model_Zoo.git`
- Source commit: `2c106101383ecee1b2a9d695efe09fbd72d5718a`
- Copied data: complete quadruped `1_Roadmap` folder (nine MAT, two FIG)
- Migrated runtime: quadruped zero function, event-time regulation, and point gait classification compatibility code
- Round 8 graphics-derived material: research body, compound-leg, COM, ground, and phase geometry providers; research visual constants; numeric graphics fixtures; and source-referenced batch metric evidence
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

The graphics providers map to `ComputeBodyGraphics.m`,
`ComputeLegGraphics.m`, `ComputeJoint_LegLA.m`, `ComputePhaseDiagram.m`, and
the COM/ground portions of `SLIP_Animation_Quad.m` at that same commit. The
research style makes source-default dark edges and ground explicit RGB black.
The research camera uses `axis equal` because Round 8 requires it, while the
pinned source renderer itself does not call `axis equal`; this is an
intentional qualification rather than an assertion of exact source behavior.

## DLARlab jerboa biped equations, GaitMap, and trajectory-fit data

- Source: `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git`
- Source commit: `4595146c5881a5313bc8fe92de85099193ef9be9`
- Copied data: `W1.mat`, `R1.mat`, `HP1.mat`, `SK1.mat`, `SK2.mat`, `AR1.mat`, and the repository-contained trajectory-fit inputs
- Migrated runtime: biped apex zero function, hybrid dynamics/events, energy and GRF calculations, gait classification, and trajectory-fit objective
- Round 8 graphics-derived material: circular body, quartered COG, left/right compound-leg, and ground geometry providers; research visual constants; numeric graphics fixtures; and source-referenced batch metric evidence
- Notice found: `READMEDing2021JerboaFrontier.txt` states Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)

The source checkout does not include a standalone license file defining the
precise code/data scope of that statement. This project preserves the stated
attribution and noncommercial restriction and does not infer broader rights.
Public packaging remains blocked until the owner confirms coverage of the
adapted source, copied branch/data files, and derived fixtures/artifacts.
Per-file hashes and provenance are recorded in
`examples/data/slip_biped/GaitMap/gaitmap_manifest.json` and the trajectory-fit
manifest.

The biped graphics providers map to `DrawBody.m`, `SetDrawBody.m`,
`DrawLegsPointFeet.m`, `DrawLegsLeftPointFeet.m`,
`SetDrawLegsPointFeet.m`, and
`SLIP_Model_Graphics_PointFeet_BipedalDemo.m` at commit
`4595146c5881a5313bc8fe92de85099193ef9be9`. Where those files leave patch
colors to MATLAB defaults, the research style freezes the documented black
outline/ground intent. Both source and target use equal aspect.

## DLARlab load-pulling quadruped equations and datasets

- Source: `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git`
- Source commit: `19f3133073c988cc0c3424a647b4adbb60a90b99`
- Copied data: one 44-entry single-stride `X_accum` dataset and one 57-entry two-stride transition dataset, plus derived native artifacts and source-regression fixture
- Migrated runtime: quadruped/load hybrid equations, event and GRF output, tugline dynamics, source objective terms, and guarded R-squared calculations
- Round 8 graphics-derived material: load and duplicated-endpoint rope providers, source camera/style constants, shared quadruped research composition, numeric graphics fixtures, and source-referenced batch metric evidence
- Notice found: the upstream README claims BSD 3-Clause and links a license, but no license/notice file is present at the audited commit

The missing authoritative license text means the README claim is recorded but
not treated as a verified redistribution grant, especially for experimental
or model data. Public packaging remains blocked pending the owner-supplied
license/coverage decision. Dataset hashes and source paths are recorded in
`examples/data/slip_quad_load/Scientific/dataset_manifest.json`.

The load and rope providers map to `Stored_Functions/Graphics/ComputeLoadGraphics.m`
and `SLIP_Animation_Quad_Load.m` at commit
`19f3133073c988cc0c3424a647b4adbb60a90b99`. Its body, leg, COM, and ground
composition reuses providers mapped to `SLIP_Model_Zoo` commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a`; both source decisions therefore
apply to that combined research renderer. The load camera retains source
plot-box aspect `[2,1,1]`.

## Round 8 graphics fixtures and raster policy

The `research_legacy` providers/styles and their numeric geometry/style
fixtures are source-derived. The local `high_contrast` profiles retain the
research geometry and layer structure and are conservatively covered by the
same pending source review. `clean_generic` is a native LMZ profile and is not
described as source-faithful. None of these distinctions changes the broader
framework release block at the top of this notice.

The three maintainer capture scripts require the exact pinned commit and a
clean source checkout, and ordinary runtime/tests do not depend on those
checkouts. Any locally generated source, source-faithful target, or difference
raster inherits the applicable unresolved source authority and must remain
local until the owner decision permits it. No Round 8 source or difference
raster is committed under `docs/graphics-comparison`.

The committed comparison evidence consists only of
`batch_metrics_r2025b_macos_arm64.json` for each model. Those JSON records hold
numeric RMSE/edge/structural/bounding-box/color-cluster measurements, image
sizes and bounds, thresholds, environment metadata, and pass/status flags.
They contain no pixel arrays or encoded raster payloads and explicitly record
that source and difference images are not stored and human approval is false.
They are automated provenance evidence, not a redistribution grant.

The consolidated release decision and owner-response template are in
`docs/REDISTRIBUTION_STATUS.md` and
`docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md`.
