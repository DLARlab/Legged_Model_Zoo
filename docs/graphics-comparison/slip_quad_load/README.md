# Load-pulling quadruped graphics comparison

- Source: `DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights`
  at `19f3133073c988cc0c3424a647b4adbb60a90b99`.
- Canonical batch frames: `single_stride_stance`, `rope_slack_low_force`,
  `stride_boundary_before`, `stride_boundary_exact`,
  `stride_boundary_after`, and `rope_loaded`.
- The slack case records tugline force `0.02` and rope length `0.316228`; the
  loaded case records force `1.8` and rope length `3.546111`. Boundary frames
  occur at `1.499`, `1.5`, and `1.501`; their active stride rows are 1, 2, and
  2, explicitly proving the exact-boundary-later-row rule.
- Result: maximum RMSE `0.047254`, minimum edge overlap `0.895824`, foreground
  box `0.871708`, and color-cluster agreement `0.987968`; all six frames pass.
- Qualification: the exact-boundary-later parameter-row rule is active, the
  rope retains duplicated patch endpoints, and load/rope alpha is source
  faithful.

See `batch_metrics_r2025b_macos_arm64.json` for states, active parameter rows,
renderer metadata, and per-frame results. Rasters are intentionally not
redistributed, and human desktop approval remains pending.
