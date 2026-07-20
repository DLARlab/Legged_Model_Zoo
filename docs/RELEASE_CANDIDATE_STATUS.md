# Release candidate status

This report audits Legged Model Zoo `1.0.0-rc.1` on 2026-07-19. It keeps
technical validation separate from release authority: a green test does not
grant permission to redistribute a file, and a configured CI job is not a
successful remote run.

## Decision

**Blocked** for a public release. The repository has no owner-supplied root
license or equivalent framework redistribution grant, and scientific-source
decisions remain unresolved. No public ZIP, toolbox, GitHub release, or other
distribution artifact was retained or published.

**Passed with qualification** as an internal release candidate. The final
Round 8 R2025b suite passed 275/275, all 31 public examples passed, and the
clean-copy workflow rendered the research profile for all three scientific
models. The closing coverage gate and the historical Round 7 baseline are
recorded below. Technical-validation packages are temporary, carry
`NOT_FOR_REDISTRIBUTION`, and are removed after verification.

## Evidence by release dimension

| Dimension | Status | Evidence and qualification |
|---|---|---|
| Scientific correctness | Passed with qualification | The untouched Round 6 baseline ran 117 tests with 0 failures and 0 incomplete tests before edits. Round 7 preserved the scientific equations/tolerances and passed 195/195 on R2025b. Round 8 preserved every numerical tolerance, passed 275/275, and adds pinned-source geometry exact to `2.22e-16` for the quadruped plus fixture-backed biped/load geometry. |
| Research graphics fidelity | Passed with qualification | `research_legacy`, `clean_generic`, and `high_contrast` use pure geometry plus renderer integration. The 18-case headless source-versus-LMZ matrix passes for quadruped, biped, and load; exact metrics are listed below. This is image-metric-tested evidence, not human approval. |
| Automated GUI | Passed | All six tabs own their complete handles and behavior; lifecycle, event synchronization, accessibility state, generic scenes, application construction, controller workflows, profile selection, and classic-axes/UIAxes renderer integration run in batch tests. |
| Human desktop | Not executed | No interactive desktop was available in the batch session. Keyboard traversal, visual clipping, research/source side-by-side fidelity, high-contrast appearance, dialog expansion/copy, and real-time interaction still require the checklist in `MANUAL_DESKTOP_QA.md`. |
| Cross-release runtime | Passed with qualification | MATLAB R2025b Update 5 (`25.2.0.3177638`) on macOS arm64 is locally verified. Only that MATLAB installation was found. R2019b receives static API/syntax and forced-fallback coverage but no R2019b runtime claim. R2021a/latest jobs are configured but have not run remotely. |
| CI | Passed with qualification | Three workflow files pass local YAML/contract/static checks. Official actions are pinned by major version and no job publishes a release. GitHub-hosted execution is not executed in this local task. |
| Core ZIP packaging | Passed with qualification | Repeated technical-validation builds are byte-for-byte deterministic, verify file hashes, run the built-in analytic tutorial from an unrelated clean directory, construct the full GUI invisibly, round-trip an artifact, remove paths, and prove public functions unload. Public retention remains blocked by project licensing. |
| Core toolbox packaging | Passed with qualification | Temporary MLTBX preflight/final installs pass discovery, tutorial workflow, invisible GUI, artifact round trip, uninstall, and unload checks on R2025b. The toolbox is not retained or published. |
| Scientific/full packaging | Blocked | Dry-run inventory is available, but unresolved framework and scientific owner decisions prevent a public build before a final archive is written. |
| Redistribution authority | Blocked | Project decision is `NOASSERTION`/unresolved. The machine-readable inventory lists every file, source/hash, classification, profile, release role, required notice, and inherited decision. No authority was fabricated. |
| External extensibility | Passed | A generated external `analytic_hopper` fixture is discovered only through the explicit plugin API and runs simulation, solve, continuation, rendering, artifacts, and clean removal without modifying core registration code. |
| Hybrid and scene contracts | Passed | The analytic plugin and built-in `tutorial_hopper` exercise native hybrid modes/events/resets plus validated declarative 2-D scene contracts. Scientific compatibility evaluators remain unchanged. |
| Performance | Passed | In addition to the historical workflow baseline, focused research-renderer medians cover construction, 100-frame updates, profile switching, capture, ground generation, and phase-diagram updates. All observed handle counts remain stable. |
| Coverage | Passed | The closing 275-test instrumented run covered 9,601/12,546 statements (76.5264%) across 204 runtime files and 25 packages. No runtime file was excluded and all five tracked Round 7 stable-package floors passed. |
| Code quality | Passed with qualification | The repository analyzer reports zero unallowlisted violations. It still reports informational missing-help and complexity findings explicitly rather than hiding them behind a broad suppression. |
| Security/trust boundaries | Passed with qualification | JSON size/depth/key limits, canonical path containment, MAT variable/type/shape checks, plugin trust lifecycle, and hostile-input tests pass. MAT validation is a data-contract boundary, not a malware sandbox; nested MATLAB objects may deserialize before recursive rejection. |
| Raster retention | Passed | No comparison or golden raster is committed. Machine-readable batch metrics are retained; redistribution authority must be resolved before source-derived image evidence is added. |
| Documentation/API contract | Passed with qualification | Versioning, API stability, authoring, configuration, testing, visualization, artifacts, architecture, governance, CI, release notes, detailed usage README, and migration status are present. Round 8 configuration/authoring, fidelity-map, comparison, test, migration, and release evidence is reconciled to the closing gates. |

## Environment and frozen baseline

- Repository: `/Users/nanyoujiayu/Documents/GitHub/Legged_Model_Zoo`
- Round 7 frozen HEAD: `0ec3b32c7e6ed1db6efd86c30a9fd3c38cb73d11`
- Round 8 closing HEAD: `c2616735354a354fa432bac549f81861f8ddd9a5`; the requested implementation remains an uncommitted worktree change
- Framework candidate: `1.0.0-rc.1`
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

Round 8 coverage was measured with `tools/run_coverage.m` over every runtime
file under `src/+lmz` and `models/+lmzmodels`; its 275-test run enforced the
tracked Round 7 stable-package floors. Performance is measured with warm
repetitions through the focused research-renderer benchmark and
`benchmarks/run_benchmarks.m`.

## Release recommendation

**Blocked** for public release. Keep `1.0.0-rc.1` as a technically validated
internal release candidate. Public release additionally requires an explicit
framework license, resolution of every scientific redistribution decision,
remote CI execution, and completion of the human desktop checklist. Once
authority exists, the technical evidence supports considering a core-only
release before a scientific/full release; neither profile is publicly
authorized today.
