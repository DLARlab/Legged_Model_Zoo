# Changelog

## 1.0.0-rc.2 — Round 10 rank-aware timing and multiple shooting

- Advanced the framework prerelease version to `1.0.0-rc.2` while retaining
  artifact and catalog schema `1.0.0`; Round 5/6 and rc.1 artifacts remain on
  the same additive compatibility line.
- Added rank-aware nonlinear solving for square and overdetermined systems,
  including `fsolve`, `lsqnonlin`, and explicitly requested constrained
  feasibility modes. Diagnostics retain residual/decision dimensions,
  Jacobian rank/nullity, singular values, conditioning, active bounds,
  optimality, scaling, and the selected solver.
- Extended fixed-data contact timing with explicit fixed-row policies.
  Overdetermined problems retain every configured row; underdetermined point
  solves require a gauge, while a declared nullity-one timing family can be
  traced through `TimingContinuationService`.
- Added the generic `lmz.shooting` horizon, node, segment, decision-schema,
  interface-defect, evaluation, result, initialization, and dimension-growth
  contracts plus public multiple-shooting, feasibility-analysis, and horizon-
  continuation services. Segment simulations are shared within one residual
  evaluation rather than repeated across residual blocks.
- Added model-owned section-local codecs/adapters for supported non-apex
  scientific shooting combinations. These direct section formulations are
  kept separate from the unchanged apex source-compatibility oracles and reject
  unsupported section/side/occurrence requests explicitly. Focused section
  tests passed 12/12; the quadruped touchdown timing root is explicitly
  qualified as rank deficient/non-unique rather than rejected as a physical
  failure.
- Added quad-load template, shooting-codec, multiple-shooting, feasibility,
  checkpoint, and horizon-growth infrastructure. A vector length, local search,
  or least-squares termination is not relabeled as a physically validated
  multi-stride return; exact load-horizon outcomes retain their classifications
  and qualifications. Frozen focused evidence contains an N=2 transition
  `root_found` result (`7.978e-13`). The N=3 fixed/energy-neutral searches are
  `physical_validation_failure` at `0.713604`/`0.721789`, so requested physical
  N=4/N=5 continuation was not reached. The distinct N=2 periodic search and a
  separate stride-boundary N=5 bounded-work search are `numerical_failure` at
  `2.817276` and `0.308691`; the latter tested all four single-control families,
  retained physical candidates, and publishes no root or simulation. The N=5
  search is not continuation from validated N=3/N=4 roots, and no global-
  infeasibility claim is made.
- Classified the four quad-load facades used directly by public Round 10
  examples (`StrideTemplateLibrary`, `QuadLoadFeasibilityEvidence`,
  `QuadLoadMultipleShootingProblem`, and `QuadLoadHorizonContinuation`) as
  provisional public; their supporting model implementation remains internal.
- Added heterogeneous per-stride schedules, controls, physical parameters, and
  energy policies to the native plan path, including a two-stride analytic
  tutorial with two distinct, physically checked apex returns.
- Extended artifacts and `reproduceRun` for rectangular timing, timing-family
  continuation, multiple-shooting solves, horizon feasibility, and horizon
  continuation without serializing callbacks. Added GUI shooting/horizon
  controls and classified residual/rank/physical diagnostics.
- Added detailed multiple-shooting and horizon-feasibility guides, expanded the
  README usage path, and added public examples for rectangular timing, timing
  families, analytic multiple shooting, heterogeneous plans, scientific
  sections, and quad-load horizon workflows.
- `ROUND10_LOCAL_AUTOMATION_PASSED`: the final R2025b suite passed 544/544,
  all 54 public examples and clean-copy isolation passed, coverage reached
  19,973/25,363 statements (78.74857075267121%) with every stable floor green,
  quality/architecture/R2019b static checks reported zero violations, and the
  29-workflow × 3 performance matrix had zero overruns. The 932-file inventory
  retains 917 blockers; temporary core/scientific ZIP and toolbox clean installs
  passed but remained unauthorized, unretained, and `NOT_FOR_REDISTRIBUTION`.
  Remote CI, human desktop QA, R2019b runtime, and redistribution authority
  remain open external gates.

## 1.0.0-rc.1 — Round 9 configurable sections and N-stride workflows

- Added catalog-driven Poincaré section descriptors, named-event/state-plane/
  composite implementations, pre/post reset semantics, transversality and
  initial-root handling, explicit symmetries, return maps, public return and
  section-transfer services, typed results, hashes, lineage, and artifacts.
  Returns now start from the selected section and truncate at the accepted stop
  crossing; composite sections require nonempty safe declarative conditions.
  Built-in tutorial/quadruped/biped transfers verify a fresh target-problem
  evaluation before reporting `DecisionCodecRephased=true`.
- Added fixed-initial-state/fixed-physical-parameter contact-timing problems and
  services for the tutorial, quadruped, biped, and load models. Timing results
  keep contact and section rows separate, report no periodicity residual, and
  retain exact fixed/free schedules and reproducible solver diagnostics. The
  tutorial supports `height_descending`-to-`height_descending` state-plane
  timing; migrated scientific providers remain explicitly apex-only, and
  unsupported/ambiguous section occurrences fail before solve.
- Added native stride plans, missing-data/failure/energy policies, checkpointed
  completion, exact load `44 + 13*(N-1)` conversion, requested-N APIs for all
  four models with explicit partial/failure outcomes, and explicit
  periodic/transition/timing-sequence residual forms that prohibit a declared
  hidden timing solve. Completion exposes deterministic baseline, step
  reduction, parameter homotopy, and multistart recovery attempts plus durable
  failure checkpoints. Legacy load problems accept explicit counts/plans and
  route to the N-stride forms while preserving their bare defaults.
- Added the experimental load `n_stride_fit` problem for complete fixed
  schedules with `HiddenTimingSolve=false`. Extensions beyond the two measured
  strides require the explicit synthetic `repeat_final_reference` policy; the
  source-equivalent `multi_stride_fit` compatibility oracle remains separate
  and labels its preserved legacy timing projection.
- Added parameter `Role` and `EnergyEffect` metadata plus explicit
  energy-transition/work diagnostics. Unknown and unbudgeted energy-changing
  transitions are rejected by the conservative policy.
- Added artifact payloads and reproduction routes for contact timing, section
  transfer, stride plans/completion, N-stride simulation, and N-stride periodic
  workflows, including a first-class N-stride-periodic run producer. Native
  stride definitions, configurations, catalogs, and descriptors are hash-bound;
  executable callbacks remain runtime-only trusted configuration.
- Added five detailed guides, expanded the beginner README with copyable usage
  and qualifications, and added eleven public examples with structured output,
  temporary output locations, and exact success markers.
- Closed the R2025b Round 9 gate with 396/396 tests, all 42 public examples,
  clean-copy isolation, and 14,190/18,428 covered statements (77.0024%) across
  263 files/28 packages. Code quality and architecture reported zero
  unallowlisted violations, the 558-file R2019b static scan reported zero
  violations, and seven workflows completed three benchmark repetitions with
  no budget overrun. Technical ZIP/toolbox clean installs passed; the refreshed
  775-file redistribution inventory retains 760 blockers because release
  authority remains unresolved.
- The load five-stride and N-stride periodic demonstrations are reported
  conservatively. Carry-forward proves the exact 96-entry layout only; timing
  correction returns an honest partial `2/5` failure at stride 3 and no
  simulation. The registered periodic example validates the explicit
  final-closure formulation without claiming solver convergence.

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
