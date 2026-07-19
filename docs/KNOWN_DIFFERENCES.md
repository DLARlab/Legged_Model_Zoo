# Known differences

- `slip_quadruped/periodic_apex` is now the migrated 22-decision scientific problem. `demo_stride` remains a separate introductory animation and is never used as RoadMap data.
- Residual evaluation wraps cyclic event times deterministically but never performs the source evaluator's hidden `fsolve`. Ground-contact timing projection is an explicit seed operation.
- Public `SimulationResult.Time` is strictly increasing. The source trajectory repeats event timestamps; regression fixtures retain the raw arrays, while the public adapter keeps the last sample at each duplicate time and preserves event states separately.
- The source evaluator returns 23 residual entries for `J_pitch = Inf` and can append optional symmetry equations. The RoadMap contract is finite inertia, no optional symmetry constraints, and exactly 22 residuals.
- The copied FIG files are visual references, not numerical authority. Their Y labels disagree with their row-5 data, and their BG curve predates the current BG MAT branch. The MAT hashes and manifest are authoritative.
- `phi_neutral` is present in the seven-parameter source contract but is unused by the active source dynamics. Homotopy over it therefore demonstrates parameter transport without changing this evaluator's residual.
- Gait classification preserves the source point-classification rules. The compatibility branch helper replaces `downsample` with the equivalent colon index expression, removing its Signal Processing Toolbox-only dependency.
- The renderer recomputes stance leg length so stance feet remain on the ground; swing legs use the resting length. This follows source kinematic equations without migrating its graphics classes.
- Biped and load-pulling periodic/fit problems remain native demonstrations rather than source-equivalent research evaluators.
- Canonical IDs are `slip_biped`, `slip_quadruped`, and `slip_quad_load`; deprecated IDs are import aliases only.
- The upstream quadruped repository has no stated license. The local copy records user authorization but does not infer an open-source grant.
- Batch graphics, callbacks, recording services, and GUI construction are verified, but the five required human-desktop screenshots and MATLAB R2019b execution remain outstanding.
