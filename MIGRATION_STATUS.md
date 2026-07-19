# Migration status

| Phase | Status | Evidence / blocker |
|---|---|---|
| 0 Scientific baselines | Complete | Repository fixtures now cover the quadruped RoadMap, biped residual/raw trajectory/events/GRFs/gaits/trajectory-fit terms, and load single-/multi-stride trajectories/events/GRFs/tugline/objective/R-squared values. Ordinary tests use only repository-contained fixtures; all three immutable source checkouts remain clean. |
| 1 Core contracts | Implemented and tested | `SolutionBranch.point` preserves per-point observables, classifications, residual/feasibility diagnostics, maturity/validation status, and source lineage. Named coordinate lookup and nearest-point distance are schema-scaled and cyclic-aware; parameter activity, compatibility, chart-aware arclength, artifacts, and continuation diagnostics are explicit. |
| 2 `slip_quadruped` RoadMap | Tested vertical slice | Complete 9-MAT/2-FIG copy, 3,443 points, SHA-256 manifest, nine native artifacts, exact Results29 round-trip, 22-decision/7-parameter deterministic evaluator, physical simulation, selection, solve acceptance, adjacent seeds, and scientific continuation have executed. |
| 3 Generic numerical workflows | Implemented and tested | Continuation includes lifted cyclic history, callbacks, adaptive backtracking/growth, curvature control, forced rejection/minimum-step/stagnation/historical-loop termination, feasibility/gait policy, cooperative stop, partial preservation, atomic checkpoints, and history/step-aware resume. Homotopy rejects inactive parameters; quadruped `k_leg` transport changes the residual and corrects successfully. `FminconSolver` reduces exact fixed bounds while preserving the full public decision vector. |
| 4 Standalone GUI | Implemented in code; human QA blocked by display | Model/problem maturity badges, model-specific data selectors, grouped schema inspector, physical biped/quadruped/load renderers and plots, solve/seed/continuation controls, active-parameter filtering, bounded fitting/cancel, native/legacy/recording/plot exports, and downstream-state invalidation are wired through controller/services. Batch construction and callback tests pass; `usejava('desktop')` is false, so `docs/MANUAL_DESKTOP_QA.md` records the unexecuted human checklist without claiming desktop evidence. |
| 5 `slip_biped` | Scientific migration complete | Exact 12-decision/two-offset/eight-state/15-residual contract; six Results14 branches (2,967 points), exact round-trip and point metadata; source-equivalent residual/trajectory/event/GRF/gait regressions; solve, generated/adjacent seeds, continuation/checkpoint resume; 16-variable trajectory-fit terms and bounded objective decrease; renderer, plots, GUI, examples, and detailed usage guide. |
| 6 `slip_quad_load` | Scientific migration complete | Exact first 44 plus 13 named entries per later stride, 18-state output, exact `X_accum` round-trip, built-in one-/two-stride datasets, source-equivalent simulation/events/GRFs/tugline and three objective/R-squared terms, four-free-variable bounded objective decrease, renderer/plots/GUI, examples, and dataset usage guide. |
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

## Round 6 biped/load/release gates

| Deliverable | Status | Evidence / blocker |
|---|---|---|
| Biped GaitMap and fit data | Done | Six hashed 14-row branches (`W1`, `R1`, `HP1`, `SK1`, `SK2`, `AR1`), 2,967 points, two hashed trajectory-fit MAT files, native artifacts, exact import/export, and repository-only runtime. |
| Scientific biped equations | Done | The published 12-decision/two-offset evaluator returns the exact 15-entry residual, raw and strictly increasing public trajectories, event records, GRFs/energy, gait metadata, solve and continuation behavior. |
| Scientific load layouts/data | Done | Hashed 44-entry single-stride and 57-entry two-stride `X_accum` files; named first/later layouts, native artifacts, exact round-trip, and 18-state simulation boundary. |
| Scientific load fitting | Done | Source-equivalent duration, footfall, normalized loading-force, composite, and guarded R-squared diagnostics; the generic optimizer preserves all 57 entries and varies only indices 54–57 for the built-in transition. |
| Maturity/capability truth | Done | Catalog descriptors carry `tutorial|validated`, `tested|source-equivalent`, provenance, and per-problem capabilities. Registry derives model availability; GUI badges and generated README tables show the distinction; artifacts retain it. |
| Continuation hardening | Done | Deterministic analytic edge cases cover forced rejection, minimum step, curvature response, stagnation, historical loop closure, checkpoint resume, and quadruped controlled stop. `phi_neutral` is inactive/rejected; nearby active `k_leg` transport succeeds. |
| Detailed README usage | Done | Top-level tutorials cover RoadMap, GaitMap, and load fitting from installation/data selection through simulation, solve/continuation or optimization, animation, artifact save, exact legacy export, requirements, maturity, and redistribution. Model-level guides live at `models/+lmzmodels/+slip_biped/README.md` and `models/+lmzmodels/+slip_quad_load/README.md`; data READMEs cover manifests/layouts. `generate_readme_tables` plus `TestReadmeScientificModelContract` keep capability/maturity content synchronized. |
| R2019b | Static audit only | No R2019b installation is available. The compatibility tool/test audits language and selected API usage; runtime verification remains unexecuted and is not claimed. |
| Standalone isolation | Automated gate implemented | A clean-copy child MATLAB workflow exercises all three scientific models, biped/quadruped solve and continuation, load fit, GUI construction, and artifact round-trips without sibling repositories. Final command/result is recorded in `docs/TEST_STATUS.md`. |
| Redistribution | Release blocker | Quadruped lacks an explicit license; biped states CC BY-NC 4.0 without a standalone scope-defining license; load README claims BSD-3 but its linked license file is absent. Public packaging remains blocked pending explicit owner decisions recorded in `docs/REDISTRIBUTION_STATUS.md`. |
