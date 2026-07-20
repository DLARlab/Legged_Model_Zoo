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

**Passed with qualification** as an internal release candidate. The expanded
R2025b suite, examples, isolation, coverage, and temporary clean-install gates
all pass. Technical-validation packages are temporary, carry
`NOT_FOR_REDISTRIBUTION`, and are removed after verification.

## Evidence by release dimension

| Dimension | Status | Evidence and qualification |
|---|---|---|
| Scientific correctness | Passed | The untouched Round 6 baseline ran 117 tests with 0 failures and 0 incomplete tests before edits. Round 7 preserves all scientific equations/tolerances, and the expanded suite passed 195/195 on R2025b. |
| Automated GUI | Passed | All six tabs own their complete handles and behavior; lifecycle, event synchronization, accessibility state, generic scenes, application construction, and controller workflows run in batch tests. |
| Human desktop | Not executed | No interactive desktop was available in the batch session. Keyboard traversal, visual clipping, high-contrast appearance, dialog expansion/copy, and real-time interaction still require the checklist in `MANUAL_DESKTOP_QA.md`. |
| Cross-release runtime | Passed with qualification | MATLAB R2025b Update 5 (`25.2.0.3177638`) on macOS arm64 is locally verified. Only that MATLAB installation was found. R2019b receives static API/syntax and forced-fallback coverage but no R2019b runtime claim. R2021a/latest jobs are configured but have not run remotely. |
| CI | Passed with qualification | Three workflow files pass local YAML/contract/static checks. Official actions are pinned by major version and no job publishes a release. GitHub-hosted execution is not executed in this local task. |
| Core ZIP packaging | Passed with qualification | Repeated technical-validation builds are byte-for-byte deterministic, verify file hashes, run the built-in analytic tutorial from an unrelated clean directory, construct the full GUI invisibly, round-trip an artifact, remove paths, and prove public functions unload. Public retention remains blocked by project licensing. |
| Core toolbox packaging | Passed with qualification | Temporary MLTBX preflight/final installs pass discovery, tutorial workflow, invisible GUI, artifact round trip, uninstall, and unload checks on R2025b. The toolbox is not retained or published. |
| Scientific/full packaging | Blocked | Dry-run inventory is available, but unresolved framework and scientific owner decisions prevent a public build before a final archive is written. |
| Redistribution authority | Blocked | Project decision is `NOASSERTION`/unresolved. The machine-readable inventory lists every file, source/hash, classification, profile, release role, required notice, and inherited decision. No authority was fabricated. |
| External extensibility | Passed | A generated external `analytic_hopper` fixture is discovered only through the explicit plugin API and runs simulation, solve, continuation, rendering, artifacts, and clean removal without modifying core registration code. |
| Hybrid and scene contracts | Passed | The analytic plugin and built-in `tutorial_hopper` exercise native hybrid modes/events/resets plus validated declarative 2-D scene contracts. Scientific compatibility evaluators remain unchanged. |
| Performance | Passed | A three-repetition R2025b/macOS-arm64 baseline records 14 workflows, median, median absolute deviation, shallow memory, fixture, release, and hardware. No record exceeds its conservative budget. Profiling did not justify an evaluation cache. |
| Coverage | Passed | A 194-test instrumented run covered 7,401/9,792 statements (75.5821%) across 174 runtime files. Five stable-package floors are exactly five percentage points below their measured rates; no runtime file is excluded. |
| Code quality | Passed with qualification | The repository analyzer reports zero unallowlisted violations. It still reports informational missing-help and complexity findings explicitly rather than hiding them behind a broad suppression. |
| Security/trust boundaries | Passed with qualification | JSON size/depth/key limits, canonical path containment, MAT variable/type/shape checks, plugin trust lifecycle, and hostile-input tests pass. MAT validation is a data-contract boundary, not a malware sandbox; nested MATLAB objects may deserialize before recursive rejection. |
| Documentation/API contract | Passed | Versioning, API stability, authoring, configuration, testing, visualization, artifacts, architecture, governance, CI, release notes, detailed usage README, and migration status are present. Registry-derived tables and README contracts pass for four models and ten problems. |

## Environment and frozen baseline

- Repository: `/Users/nanyoujiayu/Documents/GitHub/Legged_Model_Zoo`
- Frozen HEAD: `0ec3b32c7e6ed1db6efd86c30a9fd3c38cb73d11`
- Framework candidate: `1.0.0-rc.1`
- MATLAB: R2025b Update 5, `25.2.0.3177638`, Student License
- Platform: macOS arm64; MATLAB batch mode (`usejava('desktop') == false`)
- Toolboxes: Optimization Toolbox licensed; Parallel Computing Toolbox licensed
- Untouched baseline: 117 run, 0 failed, 0 incomplete, 282.580789 seconds
- Untouched public examples: 24
- Untouched static R2019b compatibility findings: 0

## Final automated validation

| Gate | Exact result |
|---|---|
| Complete MATLAB suite | `195 run, 0 failed, 0 incomplete`, 348.302462 seconds |
| Public examples | 25 files, 0 failures, 164.501629 seconds |
| Clean-copy all-scientific-model isolation | 1 test, 0 failed, 0 incomplete, 30.521080 seconds; child marker `ISOLATED_ALL_SCIENTIFIC_MODELS_OK` |
| README contract | Passed for four canonical models and ten problem descriptors |
| Architecture and R2019b static scans | 0 violations; runtime evidence remains R2025b-only |
| Redistribution inventory and hashes | 530 files before evidence-only status refresh, 0 structural/stale/unlisted findings; all 513 selected scientific blockers remain enforced |
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
scan_redistribution('verify');
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

Coverage is measured with `tools/run_coverage.m` over every runtime file under
`src/+lmz` and `models/+lmzmodels`. Performance is measured with three warm
repetitions through `benchmarks/run_benchmarks.m`.

## Release recommendation

**Blocked** for public release. Keep `1.0.0-rc.1` as an internal release
candidate until the project owner supplies an explicit framework license,
each scientific redistribution decision is resolved, remote CI executes, and
the human desktop checklist is completed. Once authority exists, the technical
evidence supports considering a core-only release before a scientific/full
release; neither profile is publicly authorized today.
