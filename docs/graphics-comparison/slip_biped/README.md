# SLIP biped graphics comparison

- Source: `DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` at
  `4595146c5881a5313bc8fe92de85099193ef9be9`.
- Canonical contact frames: `flight`, `left_stance`, `right_stance`, and
  `double_stance_wrapped_contact` using the pinned renderer's strict,
  one-pass-wrapped event logic.
- Source-supported gait frames: `walk_representative`, `run_representative`,
  and `hop_representative`. These are actual mid-stride simulations from the
  source `Main.m` Section 2 examples: W1 index 30, R1 index 30, and HP1 index
  50. The report records each original simulation frame index, event vector,
  state, contact mask, gait label, and source-support note.
- Result: maximum RMSE `0.012645`, minimum edge overlap `0.992179`, foreground
  box `1.000000`, and color-cluster agreement `0.987551`; all seven frames
  pass.
- Qualification: geometry follows the source post-update leg construction;
  LMZ makes release-dependent intended black edges explicit.

See `batch_metrics_r2025b_macos_arm64.json` for states, events, renderer
metadata, and per-frame results. Rasters are intentionally not redistributed,
and human desktop approval remains pending.
