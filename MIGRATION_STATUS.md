# Migration status

| Phase | Status | Evidence / blocker |
|---|---|---|
| 0 Scientific baselines | Quadruped tested | Three immutable RoadMap columns (1, 267, 446) contain source residual, raw duplicate-time trajectory, event-state, 12-channel GRF, and gait baselines. Ordinary tests use only `tests/fixtures/slip_quadruped_roadmap_baseline.mat`. Biped/load scientific baselines remain. |
| 1 Core contracts | Implemented | `SolutionBranch.point` now preserves per-point observables, classifications, residual/feasibility diagnostics, and source lineage. Named coordinate lookup and nearest-point distance are schema-scaled and cyclic-aware; parameter schema compatibility and chart-aware arclength are enforced. |
| 2 `slip_quadruped` RoadMap | Tested vertical slice | Complete 9-MAT/2-FIG copy, 3,443 points, SHA-256 manifest, nine native artifacts, exact Results29 round-trip, 22-decision/7-parameter deterministic evaluator, physical simulation, selection, solve acceptance, adjacent seeds, and scientific continuation have executed. |
| 3 Generic numerical workflows | Implemented | Continuation adds a lifted cyclic history, prediction/accepted/rejected callbacks, adaptive backtracking/growth, curvature response, history duplicate/stagnation/segment-loop checks, model feasibility/gait policy, cooperative pause/resume/stop, partial preservation, atomic checkpointing, and history/step-aware resume. Parameter homotopy and repeated one-dimensional family scans use named parameters. |
| 4 Standalone GUI | Implemented in code; manual evidence pending | RoadMap defaults on launch. Built-in/file/folder data management, visibility/removal/reload, named axes/view limits, visible hover tips and click/keyboard locking, editable schema tables, physical animation and full trajectories/GRFs/oscillator, solve/noise/manual/generated seeds, live continuation/checkpoint controls, homotopy/family actions, native/legacy/recording/plot exports, and downstream-state invalidation are wired. Batch construction and callback tests pass; human desktop screenshots remain outstanding. |
| 5 `slip_biped` | Partial | Native demonstration solve/continuation and trajectory fitting remain tested. Published 12-decision/15-residual evaluator, Results14 import, gait baselines, and equivalence remain. |
| 6 `slip_quad_load` | Partial | Native named objective and optimization remain tested. Published 44+13(N-1) evaluator/packer, X_accum import, objective baselines, and equivalence remain. |
| 7 Native hybrid refactor | Blocked | Compatibility equations should not be refactored until broader cross-release baselines and redistribution review are complete. |

## Round 5 RoadMap gates

| Deliverable | Status | Evidence / blocker |
|---|---|---|
| Complete copied source folder | Done | All 11 source assets match manifest SHA-256 values; no `.DS_Store` was copied. |
| Native branch conversion | Done | All nine branches load as `lmz.data.SolutionBranch`; unchanged export is bit-exact. |
| Scientific evaluator | Done | Migrated source closure always uses `skipSolve`; selected default residual is `2.91e-11`. |
| Physical visualization | Done | Named 14-state simulation, 9 event records, 12 GRF columns, stance-correct kinematics, renderer, torso/back/front/GRF/oscillator providers, atomic GIF/keyframe/plot/axes export, MP4 service path, and frame restoration pass batch checks. |
| Solve and continuation | Done | Existing seed acceptance, adjacent/manual 267/268 pair, generated scientific second seed, first corrected residual `2.05e-11`, live callback, controlled stop, checkpoint, history-aware resume, named homotopy, and family scan execute. |
| Detailed README usage | Done | `README.md` contains **SLIP Quadruped RoadMap Tutorial**, covering launch through native/legacy save and pause/resume/checkpoint. `TestReadmeRoadMapContract` enforces it. |
| Redistribution | Blocker | Upstream supplies no license/notice. Local migration follows the user's Round 5 authorization, but release redistribution needs explicit legal/owner review. |
| Desktop evidence | Partial | All five requested PNG names now contain real automated R2025b batch-graphics app captures under `docs/screenshots/`, including a four-point live continuation result. Human desktop interaction and manual capture remain pending and are not conflated with that evidence. |
