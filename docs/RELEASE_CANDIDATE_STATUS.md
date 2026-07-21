# Release candidate status

This report tracks Legged Model Zoo `1.0.0-rc.2` on 2026-07-21. It keeps
technical validation separate from release authority: a green test does not
grant permission to redistribute a file, and a configured CI job is not a
successful remote run.

## Decision

**Blocked** for a public release. The repository has no owner-supplied root
license or equivalent framework redistribution grant, and scientific-source
decisions remain unresolved. No public ZIP, toolbox, GitHub release, or other
distribution artifact was retained or published.

**Round 10 passed with qualification** as the latest locally closed internal
candidate. The uncommitted Round 10 worktree on committed HEAD
`c0d87860b59cfbdffe96e165cd01c68e2de7d948` passed its R2025b suite,
public-example, clean-copy, coverage, quality, compatibility, performance, and
technical packaging gates. Technical-validation packages remain unauthorized,
carry `NOT_FOR_REDISTRIBUTION`, were not retained, and left zero installed
Legged Model Zoo toolboxes. This local technical closure is not an authorized public release.

## Round 10 locally closed worktree status (2026-07-21)

Round 8 and Round 9 are committed history. The current committed HEAD is the
Round 9 closing commit `c0d87860b59cfbdffe96e165cd01c68e2de7d948`; Round 10
implementation and documentation are current worktree changes based on it.
The framework version is `1.0.0-rc.2`, while artifact and catalog schemas stay
at `1.0.0`.

The worktree adds rank-aware rectangular timing, explicit timing families and
gauges, generic multiple-shooting nodes/segments/interface defects, horizon
feasibility and dimension-aware continuation, supported section-local
scientific adapters, heterogeneous stride plans, quad-load horizon
infrastructure, additive artifacts/reproduction, GUI diagnostics, guides, and
examples. Focused development evidence includes:

- rectangular timing with `m=2`, `n=1`, rank 1, and residual `2.07e-15`;
- a five-point nullity-one timing family and successful artifact reproduction;
- an analytic two-segment `root_found` result with residual `1.78e-15`; and
- two distinct analytic stride schedules/impulses with physical apex-boundary
  error at most `5.63e-15`;
- 12/12 focused section-local tests, including quadruped/biped touchdown and
  transverse state-plane roots; quadruped touchdown timing is a physical root
  at `4.66e-12` but is explicitly non-unique (rank 2/nullity 6); and
- a quad-load N=2 transition/contact `root_found` result at
  `7.978014164613411e-13`, while N=3 fixed/energy-neutral searches are
  `physical_validation_failure` at `0.7136044533002278` and
  `0.7217887917287552`; no physical N=3 root or requested N=4/N=5 continuation
  is claimed; and
- a separate stride-boundary N=5 bounded-work-100 search across all four
  single-control families. Its best physical candidate is `numerical_failure`
  at `0.3086908931991573` (maximum `0.11470808666193932`, 119/119, rank
  112/nullity 7, exit 0/evaluation limit), with no root or simulation and no
  claim that it continued validated N=3/N=4 roots.

These qualified scientific observations remain part of the completed Round 10
closing evidence. Current aggregate status is:

| Round 10 gate | Status |
|---|---|
| Complete non-instrumented MATLAB suite | **Passed:** 544/544 in `1153.233186` seconds; 0 failed and 0 incomplete |
| Every top-level public example | **Passed:** 54/54 in `424.166055` seconds |
| Clean-copy standalone isolation | **Passed:** 1/1 in `52.852335` seconds |
| Programmatic coverage and stable-package floors | **Passed:** 19,973/25,363 statements (`78.74857075267121%`) across 317 runtime files and 29 packages; all tracked stable-package floors passed |
| Code quality, architecture, and static R2019b audit | **Passed:** 319 files and 0 unallowlisted quality violations; 0 architecture violations; 699 MATLAB files and 0 static R2019b violations |
| Measured Round 10 performance workflows | **Passed:** 29 workflows x 3 warm repetitions, zero budget overruns, `113.18738520833334` seconds |
| Redistribution inventory | **Structurally passed; authority unresolved:** 932 files, 917 blockers, unresolved project decision |
| Technical packaging and clean install | **Passed technically; unauthorized:** core and scientific ZIP and toolbox clean installs passed; `retained=false`; zero Legged Model Zoo toolboxes remained installed |

Closing contract marker: `ROUND10_LOCAL_AUTOMATION_PASSED`.

Remote CI, human desktop QA, R2019b runtime, and redistribution authority
remain unexecuted, unavailable, or unresolved. A local feasibility result is
classified as `root_found`, `least_squares_feasible`,
`best_known_residual`, `local_infeasibility_evidence`, `numerical_failure`, or
`physical_validation_failure`; local search failure is not a proof of global
nonexistence.

## Round 9 committed baseline (2026-07-20)

Round 9 is technically closed on the local R2025b batch platform. Catalog-driven
state/event/composite sections, true section-aware return/transfer, verified
built-in decision-codec rephasing, fixed-data timing solves, native N-stride
plans/forms, recovery checkpoints, artifact reproduction, GUI controls, and
the detailed usage route have all executed. The closing evidence is:

- final suite `396/396` in `549.278033` seconds;
- all 42 public examples in `264.010607` seconds;
- clean-copy isolation 1/1 in `40.948339` seconds;
- coverage `14,190/18,428` statements (77.0024%) across 263 files/28 packages,
  with all stable floors passing;
- zero unallowlisted quality violations across 265 files, zero architecture
  violations, and zero R2019b static violations across 558 MATLAB files; and
- seven Round 9 benchmarks over three warm repetitions with no budget overrun.

Qualifications remain part of that result:

- the quad-load 96-entry carry-forward layout is labeled synthetic, while
  predictor-corrector retains a partial `2/5` trust-region failure and no
  simulation; a validated five-stride return remains unmet;
- the registered load N-stride periodic example is evaluation-only and makes
  no solver-convergence claim; and
- the refreshed 775-file inventory retains 760 blockers under an unresolved
  project decision; no licensing, redistribution, human-desktop, R2019b-runtime, or remote-CI
  conclusion changes.

## Latest locally closed evidence by release dimension (Round 10)

The table below records the locally closed, uncommitted Round 10 worktree on
committed HEAD `c0d87860b59cfbdffe96e165cd01c68e2de7d948`. Round 8 and
Round 9 remain committed historical baselines; none of this technical evidence
authorizes a public release.

| Dimension | Status | Evidence and qualification |
|---|---|---|
| Scientific correctness | Passed with qualification | The untouched Round 6 baseline ran 117 tests with 0 failures and 0 incomplete tests before edits. Rounds 7–8 preserved the scientific equations/tolerances and closed at 195/195 and 275/275; Round 9 closed at 396/396. The uncommitted Round 10 worktree closed at 544/544 in `1153.233186` seconds with 0 failed and 0 incomplete, including rectangular timing, section-local transitions, multiple shooting, N-stride, horizon, artifact, GUI, and non-regression checks. The exact quad-load N=3/N=5 limitations above remain explicit. |
| Research graphics fidelity | Passed with qualification | `research_legacy`, `clean_generic`, and `high_contrast` use pure geometry plus renderer integration. The 18-case headless source-versus-LMZ matrix passes for quadruped, biped, and load; exact metrics are listed below. This is image-metric-tested evidence, not human approval. |
| Automated GUI | Passed | All six tabs own their complete handles and behavior; lifecycle, event synchronization, accessibility state, generic scenes, application construction, controller workflows, profile selection, and classic-axes/UIAxes renderer integration run in batch tests. |
| Human desktop | Not executed | No interactive desktop was available in the batch session. Keyboard traversal, visual clipping, research/source side-by-side fidelity, high-contrast appearance, dialog expansion/copy, and real-time interaction still require the checklist in `MANUAL_DESKTOP_QA.md`. |
| Cross-release runtime | Passed with qualification | MATLAB R2025b Update 5 (`25.2.0.3177638`) on macOS arm64 is locally verified. Only that MATLAB installation was found. The R2019b static audit covered 699 MATLAB files with 0 violations, but no R2019b runtime claim is made. R2021a/latest jobs are configured but have not run remotely. |
| CI | Passed with qualification | Three workflow files pass local YAML/contract/static checks. Official actions are pinned by major version and no job publishes a release. GitHub-hosted execution is not executed in this local task. |
| Core ZIP packaging | Passed with qualification | Core technical-validation ZIP clean installs passed, including clean-directory workflow checks and unload verification. The artifact carried `NOT_FOR_REDISTRIBUTION`, was not retained (`retained=false`), and is not authorized for public release. |
| Core toolbox packaging | Passed with qualification | Core technical-validation toolbox clean installs passed discovery, workflow, uninstall, and unload checks on R2025b. The artifact was not retained (`retained=false`), and zero Legged Model Zoo toolboxes remained installed. |
| Scientific/full packaging | Passed technically; public release blocked | Scientific technical-validation ZIP and toolbox clean installs passed. The artifacts remain unauthorized, were not retained (`retained=false`), and left zero Legged Model Zoo toolboxes installed. The unresolved framework and scientific-owner decisions still prohibit a public build or release. |
| Redistribution authority | Blocked | Project decision is `NOASSERTION`/unresolved. The machine-readable inventory lists every file, source/hash, classification, profile, release role, required notice, and inherited decision. No authority was fabricated. |
| External extensibility | Passed | A generated external `analytic_hopper` fixture is discovered only through the explicit plugin API and runs simulation, solve, continuation, rendering, artifacts, and clean removal without modifying core registration code. |
| Hybrid and scene contracts | Passed | The analytic plugin and built-in `tutorial_hopper` exercise native hybrid modes/events/resets plus validated declarative 2-D scene contracts. Scientific compatibility evaluators remain unchanged. |
| Performance | Passed | The 29 Round 10 workflows completed three warm repetitions each with zero budget overruns in `113.18738520833334` seconds. Final-suite research-renderer construction, 100-frame updates, profile switching, capture, ground generation, and phase-diagram updates also passed with stable handle counts. |
| Coverage | Passed | The closing 544-test instrumented run covered 19,973/25,363 statements (`78.74857075267121%`) across 317 runtime files and 29 packages. No runtime file was excluded and all tracked stable-package floors passed. |
| Code quality | Passed with qualification | The repository analyzer checked 319 files and reports 0 unallowlisted violations. It still reports informational missing-help and complexity findings explicitly rather than hiding them behind a broad suppression; architecture reported 0 violations and the 699-file R2019b static scan reported 0 violations. |
| Security/trust boundaries | Passed with qualification | JSON size/depth/key limits, canonical path containment, MAT variable/type/shape checks, plugin trust lifecycle, and hostile-input tests pass. MAT validation is a data-contract boundary, not a malware sandbox; nested MATLAB objects may deserialize before recursive rejection. |
| Raster retention | Passed | No comparison or golden raster is committed. Machine-readable batch metrics are retained; redistribution authority must be resolved before source-derived image evidence is added. |
| Documentation/API contract | Passed with qualification | Versioning, API stability, executable authoring, configuration, testing, visualization, sections/timing/N-stride usage, artifacts, architecture, governance, CI, release notes, detailed README, and migration status are present. Generated documentation validates four models and 30 problem kinds. |

## Environment and frozen baseline

- Repository: `/Users/nanyoujiayu/Documents/GitHub/Legged_Model_Zoo`
- Round 7 frozen HEAD: `0ec3b32c7e6ed1db6efd86c30a9fd3c38cb73d11`
- Round 8 closing HEAD: `c2616735354a354fa432bac549f81861f8ddd9a5` (committed)
- Round 9 base HEAD: `f65abf2f9dee17b3b5be363f8d6e508631a7435c` (committed history)
- Round 9 closing HEAD: `c0d87860b59cfbdffe96e165cd01c68e2de7d948` (committed)
- Round 10 worktree base/current committed HEAD: `c0d87860b59cfbdffe96e165cd01c68e2de7d948`
- Framework candidate: `1.0.0-rc.2`; Round 10 is a locally closed,
  uncommitted worktree candidate on the committed HEAD above
- MATLAB: R2025b Update 5, `25.2.0.3177638`, Student License
- Platform: macOS arm64; MATLAB batch mode (`usejava('desktop') == false`)
- Toolboxes: Optimization Toolbox licensed; Parallel Computing Toolbox licensed
- Untouched baseline: 117 run, 0 failed, 0 incomplete, 282.580789 seconds
- Untouched public examples: 24
- Untouched static R2019b compatibility findings: 0

## Round 8 closing graphics validation

| Gate | Verified result |
|---|---|
| Visualization profiles | `research_legacy`, `clean_generic`, and `high_contrast` verified through the profile factory and renderer integration |
| Numeric geometry | Pinned quadruped source agreement has maximum absolute error `2.22e-16`; biped and load comparisons are fixture-backed |
| Source-versus-LMZ batch metrics | Five quadruped cases: max RMSE `0.067967`, minimum edge similarity `0.856892`, foreground-box agreement `0.849379`, minimum color agreement `0.972641`; seven biped cases: `0.012645`, `0.992179`, `1.000000`, `0.987551`; six load cases: `0.047254`, `0.895824`, `0.871708`, `0.987968` |
| Renderer lifecycle | Classic axes and UIAxes construction, updates, profile switching, and capture pass with stable handle counts: quadruped 49, biped 12, load 34 |
| R2025b renderer medians | Quadruped: construct `0.132850 s`, 100 updates `0.305031 s`, switch `0.053857 s`, capture `0.845295 s`; biped: `0.098046 s`, `0.179934 s`, `0.023515 s`, `0.972726 s`; load: `0.110917 s`, `0.430181 s`, `0.026733 s`, `0.802519 s` |
| Supporting graphics medians | Ground generation: quadruped `0.000846 s`, biped `0.001696 s`, 20,002 vertices each; 100 phase-diagram updates: `0.013663 s`, 4 stable bars |
| Raster retention | No source-derived or golden raster is committed; only metric JSON summaries are retained |
| Human desktop | Blocked by display availability; batch comparisons do not constitute human approval |
| R2019b | Static compatibility only; no R2019b runtime claim |
| Closing suite | `275 run, 0 failed, 0 incomplete`; retained scientific equations and tolerances, generic scene/plugin, GUI, recording, release, security, isolation, geometry, raster, and performance gates all included |
| Public examples | 31/31 passed; the comparison gallery rendered 3 models x 3 profiles x 3 frames and loaded all three scalar source-comparison reports |
| Clean-copy graphics | Child MATLAB process rendered and captured `research_legacy` for `slip_biped`, `slip_quadruped`, and `slip_quad_load` with no sibling source repository path |
| Code quality/static compatibility | 206 files, 0 unallowlisted quality violations; 436 files, 0 R2019b static violations |
| Redistribution inventory | 628 files, 0 structural/stale/unlisted findings; all 613 selected scientific blockers remain enforced and the project decision remains unresolved |

## Historical Round 7 automated validation

| Gate | Exact result |
|---|---|
| Complete MATLAB suite | `195 run, 0 failed, 0 incomplete`, 348.302462 seconds |
| Public examples | 25 files, 0 failures, 164.501629 seconds |
| Clean-copy all-scientific-model isolation | 1 test, 0 failed, 0 incomplete, 30.521080 seconds; child marker `ISOLATED_ALL_SCIENTIFIC_MODELS_OK` |
| README contract | Passed for four canonical models and ten problem descriptors |
| Architecture and R2019b static scans | 0 violations; runtime evidence remains R2025b-only |
| Redistribution inventory and hashes | Historical Round 7 result: 530 files, 0 structural/stale/unlisted findings; all 513 then-selected scientific blockers remained enforced |
| Code quality | `LMZ_CODE_QUALITY files=176 violations=0 allowed=150 missingHelp=36 complexity=2 excludedLegacy=5` |
| Coverage | 194 tests; 174 files; 7,401/9,792 statements; 75.5821% overall; stable-package policy passed |
| Core ZIP/MLTBX clean installs | Passed preflight and final technical-validation installs for both artifact types; packages removed and public symbols unloaded |
| External plugin and hybrid/scene fixture | 42 integrated extensibility/security/GUI/registry/legacy tests passed during implementation; included again in the full suite |

## Commands used by the closing gate

```matlab
startup;
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));

addpath(fullfile(pwd, 'tools'));
run_public_examples;
run_standalone_all_scientific_models;
check_readme_contract;
check_matlab_compatibility;
run_code_quality;
```

```matlab
addpath(fullfile(pwd, 'tools', 'release'));
scan_redistribution;
build_release('core', struct('Mode', 'technical-validation', ...
    'RunInstallTest', true));
build_toolbox('core', struct('Mode', 'technical-validation', ...
    'RunInstallTest', true));
build_release('core', struct('DryRun', true));
build_release('scientific', struct('DryRun', true));
```

```text
python3 tools/ci/static_checks.py --all
git diff --check
```

Round 10 coverage was measured with `tools/run_coverage.m` over every runtime
file under `src/+lmz` and `models/+lmzmodels`; its 544-test run enforced every
tracked stable-package floor. Performance was measured across 29 workflows
with three warm repetitions each through the focused research-renderer
benchmark and `benchmarks/run_benchmarks.m`.

## Release recommendation

**Blocked** for public release. Treat the uncommitted Round 10
`1.0.0-rc.2` worktree as the latest locally closed internal source-tree
candidate. Public release still requires an explicit framework license,
resolution of every scientific redistribution decision, remote CI execution,
and completion of the human desktop checklist. Once authority exists, the
technical evidence supports considering a core-only release before a
scientific/full release; neither profile is publicly authorized today.
