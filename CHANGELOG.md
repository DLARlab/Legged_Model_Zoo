# Changelog

## Round 6 — Scientific biped, load pulling, and release hardening

- Replaced the biped toy closure with the exact 12-decision/two-offset,
  eight-state, 15-residual jerboa evaluator; imported six Results14 GaitMap
  branches (2,967 points) with exact export, native artifacts, gait metadata,
  physical rendering/plots, solve, second seed, continuation, checkpoint
  resume, and source-equivalent 16-variable trajectory fitting.
- Replaced the load toy fit with the exact `44 + 13*(N-1)` X_accum layout,
  one-/two-stride built-in datasets, 18-state hybrid simulation, events, GRFs,
  tugline output, source duration/footfall/loading objectives, guarded
  R-squared diagnostics, renderer/plots, GUI workflow, and objective-decrease
  fit evidence.
- Added reduced-variable `fmincon` execution for exact fixed bounds while
  preserving the full public decision/schema and artifact output.
- Added per-problem maturity, validation, provenance, and capabilities;
  registry-derived model capabilities; GUI maturity badges/activity-aware
  parameter controls; artifact metadata; and generated README capability and
  maturity tables.
- Refactored GUI construction into tab shells/components and generalized the
  branch, solution, simulation, solve/continuation, and optimization paths
  across all three scientific models.
- Hardened continuation with normalized snapshot/artifact diagnostics and
  deterministic forced rejection, minimum-step, curvature, stagnation,
  historical-loop, active/inactive homotopy, controlled-stop, and checkpoint
  tests without weakening the quadruped RoadMap suite.
- Added R2019b static compatibility auditing, cross-model clean-copy isolation,
  public scientific examples, detailed three-model tutorials, desktop-QA
  blocker documentation, and explicit redistribution decision records.

## Round 5 — SLIP Quadruped RoadMap

- Imported and hashed the complete nine-branch/two-figure RoadMap dataset.
- Added manifest-driven cataloging, native artifact generation, stale detection, and exact Results29 round-trip.
- Replaced the quadruped demonstration closure at `periodic_apex` with the migrated 22-decision/7-parameter deterministic evaluator.
- Added event, contact, GRF, observable, gait, feasibility, kinematic, and physical simulation contracts.
- Preserved full point metadata in `SolutionBranch` and added named/scaled/cyclic-aware coordinate operations.
- Added RoadMap selection, solve acceptance, adjacent seeds, scientific continuation callbacks/checkpoints/resume, and named parameter workflows.
- Expanded the standalone GUI with manifest/file/folder data management, visible multi-dataset hover/lock, working-copy editing, physical animation/playback, torso/leg/12-channel GRF/oscillator plots, manual/generated seed overlays, live continuation/checkpoint/homotopy/family controls, and atomic GIF/MP4/keyframe/plot exports.
- Added five automated R2025b app captures while retaining the human desktop walkthrough as an explicit pending check.
- Added source baselines, RoadMap tests, an end-to-end command-line example, a detailed README tutorial, provenance, and third-party notice.
