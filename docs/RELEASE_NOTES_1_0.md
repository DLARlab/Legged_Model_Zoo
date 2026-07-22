# Legged Model Zoo 1.0 release-candidate notes

## 1.0.0-rc.3

Round 11 advances the prerelease version for provisional registered-workflow,
data-provider, workbench-contribution, solve-progress, and GUI layout-profile
APIs. Artifact and catalog schemas remain `1.0.0`; workflow, data-source, and
workbench documents also use schema `1.0.0`. This is an additive framework
version change, not a persistent-format reset.

Highlights:

- Optional model-manifest bindings for declarative data sources, workbench
  contributions, and complete scientific workflow descriptors, with
  path-containment, provider-namespace, capability, reference, and frozen-hash
  validation.
- A registry/runner/session boundary that selects existing generic solve,
  seed, continuation, checkpoint, homotopy, family-scan, and artifact services
  without embedding algorithms in JSON.
- Three quadruped descriptors: RoadMap exploration, the validated
  `roadmap_root_continuation` reference, and a tested experimental touchdown-
  section transfer/root/continuation route.
- A public registered quadruped example covering RoadMap load, point 267,
  accepted root, adjacent seeds, both-direction continuation, and native
  artifact round trip.
- An external analytic-hopper data/workbench/workflow contribution proving
  registration, execution, trust containment, generic fallback, and clean
  removal without core model-ID edits.
- Selectable `scientific_workbench` and `classic_tabs` placement profiles. The
  source-inspired workbench keeps branch/data and status/progress visible while
  scrollable task panels change; classic tabs retain the established shell.
- Shared locked-selection, seed, prediction, corrected-solution, seed-pair,
  predictor, rejected, and incrementally updated accepted-continuation state;
  the terminal result replaces the accepted layer in place with the final or
  stopped partial branch.
- GUI-independent typed solve lifecycle/iteration snapshots retained by
  `SolveProgress` and `SolveResult`, including a truthful zero-iteration
  accepted-existing-seed lifecycle.
- Forward/backward/both GUI continuation with registered direction labels; the
  quadruped reference defaults to both directions.
- Detailed workflow, authoring, layout, source-parity, usage, migration, and
  API documentation.

The unchanged Round 10 suite passed 544/544 as the pre-edit baseline at
committed HEAD `5c6a6c100f752ea6ed1fd20114f84800f9b52070`.
`ROUND11_LOCAL_AUTOMATION_PASSED` records 631/631 final tests, all 55 public
examples, clean-copy isolation, `23,614/29,755` covered statements with every
stable floor passing, zero quality/architecture/R2019b-static violations, and
zero median budget overruns in both three-repetition performance reports.
Technical core/scientific ZIP and toolbox installs passed without retaining an
unauthorized artifact. Remote CI, human desktop QA, R2019b runtime, and
redistribution authority remain separate external gates. No public package or
release is authorized by rc.3.

## 1.0.0-rc.2

Round 10 advances the prerelease version for substantial provisional timing,
section, and multiple-shooting APIs. Artifact and catalog schemas remain
`1.0.0`; this is an additive framework-version migration, not a persistent-
format reset.

Highlights:

- Rank-aware square and overdetermined nonlinear solves with explicit solver
  selection, scaling, Jacobian rank/nullity, singular values, conditioning,
  active-bound, optimality, and physical-feasibility diagnostics.
- Fixed-contact-row timing policies and explicit nullity-one timing-family
  continuation; underdetermined point solves require declared gauges.
- Generic section-state nodes, segment horizons, interface defects,
  multiple-shooting problems/results, initialization, checkpointing, and
  dimension-aware `N` to `N+1` continuation.
- Direct model-owned section-local simulation/decision adapters for supported
  scientific non-apex combinations, without changing the preserved apex
  source-compatibility evaluators.
- Quad-load template and horizon infrastructure that preserves local numerical
  evidence, partial results, residual blocks, event/energy validity, and exact
  feasibility classifications instead of inferring physics from vector length
  or solver termination.
- Four quad-load example facades are provisional public APIs:
  `StrideTemplateLibrary`, `QuadLoadFeasibilityEvidence`,
  `QuadLoadMultipleShootingProblem`, and `QuadLoadHorizonContinuation`.
  Supporting model evaluators, codecs, adapters, and compatibility oracles
  remain internal.
- Heterogeneous native stride plans with per-stride schedules, controls,
  physical parameters, and explicit energy policy.
- Additive artifact and `reproduceRun` routes for rectangular timing,
  timing-family continuation, multiple shooting, feasibility analysis, and
  horizon continuation; callbacks remain runtime-only.
- GUI shooting/horizon controls, detailed usage guides, and executable public
  examples with structured output and explicit claim qualifications.

The exact result vocabulary is `root_found`, `least_squares_feasible`,
`best_known_residual`, `local_infeasibility_evidence`, `numerical_failure`,
and `physical_validation_failure`. Local failure is never presented as proof
of global nonexistence without a rigorous certificate.

Focused rc.2 evidence includes 12/12 scientific section-local tests. The
quadruped touchdown timing candidate is a physical root but rank deficient and
explicitly non-unique. Quad-load evidence contains an N=2 transition/contact
`root_found` result (`7.978e-13`); the N=3 fixed/energy-neutral searches are
`physical_validation_failure` at `0.713604` and `0.721789`, so requested
physical N=4/N=5 continuation was not reached. The distinct N=2 periodic
search and a separate stride-boundary N=5 bounded-work-100 search are
`numerical_failure` at `2.817276` and `0.308691`. The N=5 search tested all
four single-control families and retained physical candidates, but it met
neither residual tolerance nor acceptable solver termination and publishes no
root or simulation. It is not continuation from validated N=3/N=4 roots.
These local results do not prove global infeasibility.

`ROUND10_LOCAL_AUTOMATION_PASSED`: the final R2025b suite passed 544/544 in
`1153.233186` seconds, all 54 public examples passed in `424.166055` seconds,
and clean-copy isolation passed. Coverage reached `19,973/25,363` statements
(78.74857075267121%) across 317 files/29 packages with all stable floors
passing. Quality, architecture, and the 699-file R2019b static audit reported
zero violations; 29 workflows over three repetitions had zero performance
overruns. Temporary core/scientific ZIP and toolbox clean installs passed but
remained unauthorized, unretained, and `NOT_FOR_REDISTRIBUTION`; the 932-file
inventory retains 917 blockers. Remote CI, human desktop QA, R2019b runtime,
and redistribution authority remain unexecuted or unresolved. Consequently
rc.2 is a locally validated internal source-tree candidate, not an authorized
public release.

## 1.0.0-rc.1

This release candidate freezes the initial public API and persistent-format
contract. It is numerically verified on MATLAB R2025b Update 5. It is designed
for R2019b compatibility, but no R2019b runtime execution is claimed.

Highlights:

- Semantic framework versioning through `lmz.util.Version` and root `VERSION`.
- Additive artifact provenance fields while preserving schema 1.0 and Round
  5/6 artifact readability.
- Stable/provisional/internal/legacy-import-only API classifications.
- Machine-readable, hash-checked redistribution inventory.
- Deterministic ZIP staging and verification with authorization gates.
- Reproducible MATLAB toolbox build support and a clean-install ZIP fallback.
- Six owned GUI tab components, transactional presentation events, persistent
  versioned preferences, high-contrast presentation, and leak-tested disposal.
- Per-problem `research_legacy`, `clean_generic`, and `high_contrast` graphics
  profiles, source-audited compound geometry for all three scientific models,
  source-style analysis plots, live profile switching, and profile-aware
  GIF/MP4/keyframe metadata.
- A built-in analytic hopper tutorial plus an independently registered
  external analytic plugin exercising the stable hybrid and scene contracts.
- Model-template generation, safe input boundaries, run reproduction,
  benchmarks, measured coverage policy, CI definitions, and governance files.

The closing R2025b suite passed 275/275 and all 31 public examples passed. The
18-case headless source-comparison matrix and numeric geometry gates pass, and
the clean-copy process renders all three research profiles without source
repository paths. These are geometry-tested and image-metric-tested results;
human desktop side-by-side approval remains blocked and is not claimed.
The closing coverage run also passed all 275 tests and covered 9,601/12,546
runtime statements (76.5264%) across 204 files while enforcing the existing
stable-package floors.

This is not a public release. No root project license or owner authorization
record is present. Public core and scientific packages therefore remain
blocked. Technical-validation packages are temporary, labeled
`NOT_FOR_REDISTRIBUTION`, and deleted by their tests.

No scientific equation or regression tolerance is changed. The quadruped
catalog version is corrected to match its already-versioned implementation;
artifact compatibility tests retain the Round 5/6 readers.
