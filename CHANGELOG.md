# Changelog

## 1.0.0-rc.1 — Round 8 research graphics fidelity

- Added validated `research_legacy`, `clean_generic`, and `high_contrast`
  visualization profiles for the quadruped, biped, and quadruped-with-load.
  Scientific problems select compound research geometry, while tutorials and
  generic plugins retain the clean generic profile (declarative where
  configured).
- Added pure, namespaced source-derived geometry for the quadruped body,
  springs/legs, COM, dense ground, and phase overlay; the biped body, quartered
  COG, compound point-foot legs/contact behavior, and ground; and the load body,
  duplicated-endpoint rope, and per-stride geometry selection. Load rendering
  composes the shared quadruped providers rather than duplicating them.
- Added stable research renderers and a trusted renderer factory/configuration
  path with classic-axes and UIAxes support, in-place frame updates, profile
  switching, selected-profile recording, cleanup, and source camera/layer
  behavior. High contrast retains the compound research geometry and source
  silhouette while deliberately adapting palette and selected line widths.
- Added selectable source-style scientific plots for quadruped trajectories,
  forces, and phase views; biped trajectories, forces, events, energy, and gait;
  and load footfalls, leg trajectories, tugline force, sensitivity, and
  R-squared readouts.
- Added pinned numeric geometry fixtures and direct equivalence tests.
  Quadruped source comparisons are exact to at most `2.22e-16`; biped and load
  geometry are fixture-backed at their pinned source commits, with no
  source-repository runtime dependency.
- Added headless matched-camera source-versus-LMZ comparisons. Maximum
  normalized RMSE and minimum edge overlap across the expanded canonical matrix
  are `0.067967` / `0.856892` (five quadruped cases), `0.012645` / `0.992179`
  (seven biped cases), and `0.047254` / `0.895824` (six load cases). Minimum
  foreground-box agreement is `0.849379`, `1.000000`, and `0.871708`; minimum
  color-cluster agreement is `0.972641`, `0.987551`, and `0.987968`,
  respectively. All values pass the recorded platform-tolerant thresholds.
- Added cross-model renderer performance coverage. Median R2025b construction,
  100-frame update, profile-switch, and capture times are documented in
  `docs/TEST_STATUS.md`; all owned handle identities remain stable.
- Re-ran programmatic coverage on the frozen closing tree: all 275 tests passed
  while covering 9,601/12,546 runtime statements (76.5264%) across 204 files,
  and every tracked stable-package floor passed.
- Committed numeric metrics and fixtures only. Source, LMZ, and difference
  rasters are not retained while redistribution authority is unresolved.
  Human desktop side-by-side review remains blocked, and R2019b evidence
  remains static/fallback-only. The final clean R2025b suite passed 275/275,
  all 31 public examples passed, and the clean-copy child process rendered the
  `research_legacy` profile for all three scientific models without a source
  repository runtime path.

## 1.0.0-rc.1 — Round 7 release candidate

- Added root Semantic Versioning and the `lmz.util.Version` contract for
  framework, artifact/catalog schema, compatibility, and minimum-release
  metadata; classified stable, provisional, internal, and legacy-import-only
  APIs and documented deprecation and 1.x artifact/catalog policy.
- Extended solve, continuation, optimization, and checkpoint artifacts with
  reproducible environment, options, lineage, problem-configuration,
  source/data-hash, evaluation, termination, and warning metadata; added
  `lmz.services.reproduceRun` for hash-checked reconstruction of all three run
  kinds.
- Added a complete hash-checked redistribution inventory and authorization-
  gated core/scientific profiles, deterministic ZIP and MATLAB toolbox build
  scripts, verification, clean install/uninstall checks, source-tree/test
  evidence, and technical-validation cleanup. No root license or owner grant
  was invented; public core and scientific output remains blocked.
- Added static, MATLAB-matrix, and non-publishing release-audit GitHub Actions
  definitions plus locally executable equivalents. The workflows are not
  described as passing remotely until a maintainer pushes and observes a run.
- Completed GUI componentization: all six tabs own their controls and
  callbacks, numerical work stays behind `AppController`/services, and a
  transactional presentation event bus synchronizes model, problem, data,
  selection, run-result, and status changes with listener/duplicate-refresh
  tests.
- Added GUI tooltips, busy/cancel behavior, minimum/resizable layouts,
  shape-and-color branch states, a high-contrast palette, versioned window and
  recent-folder preferences with reset, timestamped/copyable status history,
  and expandable/copyable error details. Human keyboard/focus/DPI/clipboard
  desktop QA remains explicitly unexecuted in the headless environment.
- Centralized R2019b-targeted compatibility fallbacks for UI/graphics, JSON,
  text, files, timestamps, recursive discovery, atomic moves, video, and
  Optimization Toolbox options. Preferred and forced-fallback paths are tested
  on R2025b; no R2019b runtime execution is claimed.
- Added the built-in analytic `tutorial_hopper`, stable generic scheduled/guard
  hybrid mode/event/reset/simulator contracts, and declarative kinematics,
  scene, renderer, and plot-plugin contracts. An isolated external analytic
  plugin proves discovery, simulation, solve, continuation, rendering,
  artifact round trip, GUI capabilities, and clean removal without a core
  registry modification.
- Added an inactive `new_model` generator and executable templates together
  with complete model-authoring, configuration, artifact, service,
  visualization, and model-testing guides.
- Hardened JSON/MAT/path trust boundaries with bounded schema/type/dimension
  validation and malicious/malformed fixtures; documented that recursive MAT
  validation is not a malware sandbox for an untrusted file.
- Added performance budgets and platform records, programmatic per-package/
  class coverage and measured-regression policy tooling, MATLAB code analysis
  with a path-scoped allowlist, and expanded architecture/decision records.
  Profiling did not justify adding an evaluation cache.
- Added `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CITATION.cff`,
  and `SUPPORT.md` without assigning unverified ownership or licensing.
- Reworked the top-level README into a detailed beginner-friendly guide for
  source installation, GUI and CLI workflows, preferences/accessibility,
  scientific and analytic models, artifacts and reproduction, authoring and
  trusted plugins, testing/CI/coverage/benchmarks/releases, troubleshooting,
  and the remaining release qualifications.
- Preserved all validated biped, quadruped, and load compatibility equations,
  source fixtures, and regression tolerances. Migrating those scientific
  oracles to the new hybrid contracts remains intentionally deferred.

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
