# SLIP quadruped graphics comparison

- Source: `DLARlab/SLIP_Model_Zoo` at
  `2c106101383ecee1b2a9d695efe09fbd72d5718a`.
- Canonical batch frames: `flight_apex`, `one_leg_stance`,
  `two_leg_stance`, `asymmetric_body_morphology`, and
  `detailed_phase_overlay`. Every record includes the 14-state vector,
  16-source-parameter vector, expected contact mask, contact count,
  morphology, and overlay state.
- Result: maximum RMSE `0.067967`, minimum edge overlap `0.856892`, foreground
  box `0.849379`, and color-cluster agreement `0.972641`; all five frames pass
  the documented platform-tolerant thresholds.
- LMZ-only force regression: the `two_leg_stance` frame has four force handles.
  With forces disabled, zero are visible; with forces enabled, all four are
  visible and two contain nonzero vectors. The off/on images differ by RMSE
  `0.016780` while retaining edge overlap `0.991200` and identical foreground
  bounds. Temporary rasters are deleted and the report stores only metrics,
  checksums, handle counts, and the `force_vectors_off_on` outcome.
- Qualification: the LMZ research profile intentionally applies the Round 8
  equal-axis requirement although the pinned source renderer omits it; both
  batch images use that matched axis for comparison. Theme-dependent source
  edges are explicit black in LMZ. The source animation has no GRF-arrow
  layer, so force visibility is correctly identified as target-only evidence.

See `batch_metrics_r2025b_macos_arm64.json` for states, parameters, renderer
metadata, and per-frame results. Rasters are intentionally not redistributed,
and human desktop approval remains pending.
