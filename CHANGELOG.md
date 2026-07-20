# Changelog

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
