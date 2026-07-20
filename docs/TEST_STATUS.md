# Test status

## Environment

- Date: 2026-07-19
- MATLAB: `25.2.0.3177638 (R2025b) Update 5`, Apple silicon
- License: Student License
- Operating system: macOS 26.5.2 (build 25F84), arm64
- Optimization Toolbox: licensed and required for solve/continuation/fitting
- Parallel Computing Toolbox: licensed but not required
- `usejava('desktop')`: false in the verification process

MATLAB R2019b is the compatibility target, but no R2019b installation is
available. Runtime verification is therefore R2025b-only; the R2019b result
below is a static audit and is not described as execution evidence.

## Final Round 7 release-candidate gates

Canonical command:

```matlab
started = tic;
results = run_tests;
duration = toc(started);
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Final expanded-suite result:

```text
Legged Model Zoo: 195 run, 0 failed, 0 incomplete.
ROUND7_FINAL_SUITE_OK tests=195 failed=0 incomplete=0 duration=348.302462
```

The 195 methods retain the untouched 117-test Round 6 scientific floor and
add version/artifact compatibility, release inventory/profiles, deterministic
packaging, toolbox/ZIP clean installs, CI/governance contracts, complete GUI
components/events/preferences/accessibility, R2019b compatibility fallbacks,
safe-input boundaries, built-in/external analytic model authoring, generic
hybrid/scene contracts, run reproduction, code quality, coverage policy, and
performance budgets. No scientific tolerance was weakened.

Every top-level public example then ran in its own temporary output workspace:

```text
LMZ_PUBLIC_EXAMPLES_OK files=25
ROUND7_PUBLIC_EXAMPLES_OK files=25 failures=0 duration=164.501629
```

Representative new and retained markers include:

```text
LMZ_TUTORIAL_HOPPER_OK residual=1.22e-14 points=4
LMZ_BIPED_SOLVE_OK residual=2.708e-13
LMZ_BIPED_CONTINUATION_OK points=3 reason=maximum_points
LMZ_QUAD_LOAD_FIT_OK initial=63.5580630419 final=63.4193407268 decrease=0.138722315113
LMZ_ROADMAP_WORKFLOW_OK seed=267 residual=2.91e-11 solve=accepted-existing-seed continuation=20
```

The separate clean-copy integration test copied the entire repository beneath
an otherwise empty temporary parent and ran a child MATLAB process:

```text
ISOLATED_ALL_SCIENTIFIC_MODELS_OK
ROUND7_CLEAN_COPY_ISOLATION_OK tests=1 failed=0 incomplete=0 duration=30.521080
```

## Round 7 coverage and performance

Programmatic coverage instrumented every MATLAB runtime file below `src/+lmz`
and `models/+lmzmodels`. It ran the complete then-current suite except the one
policy test that required the measurement being generated:

```text
ROUND7_COVERAGE_SUITE_START tests=194
LMZ_COVERAGE_OK files=174 packages=24 statements=7401/9792 rate=0.7558
ROUND7_COVERAGE_MEASURED_OK tests=194 files=174 covered=7401 total=9792 rate=0.75582108 duration=332.977845
ROUND7_COVERAGE_POLICY_OK run=1
```

| Stable package | Measured statement rate | Regression floor |
|---|---:|---:|
| `lmz.api` | 78.5714% | 73.5714% |
| `lmz.data` | 82.5397% | 77.5397% |
| `lmz.io` | 85.9504% | 80.9504% |
| `lmz.registry` | 83.4356% | 78.4356% |
| `lmz.services` | 74.4932% | 69.4932% |

The tracked R2025b/macOS-arm64 performance baseline contains 14 workflows and
three warm-process repetitions. Every median is below its conservative budget.
Selected medians are short quadruped continuation 1.702488 seconds, real GUI
construction 2.829243 seconds, load objective 0.672667 seconds, 100 rendered
frames 0.391656 seconds, and artifact save/load 0.055345 seconds. Profiling did
not justify an evaluation cache.

## Round 7 quality, release, and authority evidence

```text
LMZ_CODE_QUALITY files=176 violations=0 allowed=150 missingHelp=36 complexity=2 excludedLegacy=5
README contract valid for 4 canonical models.
LMZ_STATIC_CHECKS_OK checks=6
```

`missingHelp` and `complexity` are visible informational findings; stable APIs
with missing primary help would fail the gate. The 150 Code Analyzer findings
are accepted only by identifier plus an exact path-scoped rationale. Five
source-preserved compatibility evaluators remain visible to numerical
regression and coverage, but are excluded from style-driven Code Analyzer
enforcement.

Both public release profiles remain blocked. Focused and full-suite packaging
tests show that temporary core technical-validation ZIP and MLTBX artifacts
are deterministic and pass preflight/final unrelated-directory discovery,
`tutorial_hopper`, invisible full-GUI construction, artifact round trip,
uninstall/path removal, and public-symbol unload checks. The builders return
`Retained=false`; no public artifact was written or uploaded. The hash-checked
redistribution inventory has no stale, missing, or unlisted entries after its
final refresh, while every unresolved project/scientific decision remains a
blocking entry.

The three GitHub Actions workflows pass local YAML and contract checks only.
No remote GitHub Actions execution occurred, so remote CI remains unexecuted.
Human desktop QA and R2019b runtime execution also remain unexecuted and are
not inferred from automated R2025b batch evidence.

## Final Round 6 release gates

Canonical test command:

```matlab
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Final clean rerun:

```text
Legged Model Zoo: 117 run, 0 failed, 0 incomplete.
ROUND6_FINAL_FULL_OK run=117 failed=0 incomplete=0
```

The 117 methods include all retained quadruped RoadMap regressions; all named
biped/load tests; GUI and physical renderer/plot coverage; maturity,
capability, activity, and artifact contracts; authoritative problem-selector
state, active-only homotopy choices, optimization reduction;
continuation edge cases; documentation; R2019b static compatibility; and a
clean-copy child-MATLAB all-model isolation run.

Documentation, architecture, compatibility, and data verification:

```text
README contract valid for 3 canonical models.
ROUND6_FINAL_README_OK tests=3
LMZ_ROADMAP_VERIFY_OK branches=9 points=3443 files=11
LMZ_BIPED_GAITMAP_VERIFY_OK branches=6 points=2967
LMZ_SLIP_QUAD_LOAD_VERIFY_OK datasets=2
ROUND6_FINAL_RELEASE_GATES_OK architecture=0 compatibility=0 runtime=2025b
```

Every top-level public example was then executed in an isolated function
workspace. The exhaustive gate found and corrected seven older scripts whose
anonymous cleanup callback used invalid command syntax and whose startup call
depended on the current directory. Each run now receives a unique temporary
output root that is removed on success or failure; the final rerun left no
artifact in `examples/`:

```text
LMZ_PUBLIC_EXAMPLES_OK files=24
ROUND6_FINAL_EXAMPLES_OK files=24 failed=0
```

The required cross-model markers include:

```text
LMZ_ALL_SCIENTIFIC_MODELS_OK biped=215 load=1 quadruped=891
LMZ_FULL_DESKTOP_WORKFLOW_OK artifacts=4
LMZ_ROADMAP_WORKFLOW_OK seed=267 residual=2.91e-11 solve=accepted-existing-seed continuation=20
```

## Scientific data inventory

| Model | Repository-contained scientific data | Verified content |
|---|---|---|
| `slip_quadruped` | nine Results29 MAT branches, two reference FIG files | 3,443 points; all 11 hashes and nine native artifacts valid; exact Results29 round-trip |
| `slip_biped` | `W1`, `R1`, `HP1`, `SK1`, `SK2`, `AR1`; two trajectory-fit MAT files | 2,967 points; all eight data hashes and six branch native artifacts valid; exact Results14 round-trip |
| `slip_quad_load` | `P3_Individual_1_TR.mat`, `P4_TR_RL_Individual_1.mat` | one 44-entry stride and one 57-entry/two-stride transition; both hashes/native artifacts and exact X_accum round-trips valid |

Fixture SHA-256 values:

```text
biped source_equivalence.mat = 3372368f375b27d9ab35755a00cf93b6c2eedda5048928579470c219a61376d4
load source_baselines.mat      = 303b33f5b5bd655533da133445230bf1a95477541506765c56d575cccfdd3c63
```

Ordinary runtime/tests do not inspect sibling repositories. Final source
checkout audits remained clean at:

```text
quadruped  2c106101383ecee1b2a9d695efe09fbd72d5718a
biped      4595146c5881a5313bc8fe92de85099193ef9be9
load       19f3133073c988cc0c3424a647b4adbb60a90b99
```

## Biped scientific regression

The fixture covers a representative point from each of the six branches and
the source trajectory-fit seed. The migrated evaluator matched captured
source residuals, raw time/state trajectories, event states, and fit terms;
the R2025b arrays were bit-identical, while tests retain these measured bounds:

| Quantity | Absolute tolerance | Relative tolerance |
|---|---:|---:|
| residual | `5e-11` | — |
| raw time | `5e-12` | — |
| raw state | `5e-10` | `5e-10` |
| event state | `5e-10` | — |
| resampled trajectory | `5e-10` | — |
| fit objective/terms | `1e-9` | — |

Exact workflow evidence:

```text
LMZ_BIPED_SOLVE_OK residual=2.708e-13
LMZ_BIPED_CONTINUATION_OK points=3 reason=maximum_points
LMZ_BIPED_TRAJECTORY_FIT_OK initial=168.712087 final=167.981259 decrease=0.730828
```

The captured unperturbed source-Main fit objective is
`167.4951469271463`. The bounded decrease example perturbs `dx` and `alphaL`
and uses the source-Main penalized mode. The alternate constrained mode is
separately checked against its 15-entry scaled residual. Public simulation
time is strictly increasing and reports six removed duplicate samples; five
event records retain pre/post states.

## Load-pulling scientific regression

The fixture covers source one- and two-stride raw simulation, stitched
parameters, event records, all 12 GRF channels, unilateral tugline force,
three objective terms, composite, and R-squared values. Measured bounds:

| Quantity | Absolute tolerance | Relative tolerance |
|---|---:|---:|
| residual | `1e-11` | — |
| raw time | `1e-12` | — |
| raw state | `1e-10` | `1e-9` |
| GRF | `1e-9` | `1e-8` |
| tugline force | `1e-10` | — |
| per-stride parameter/X_accum | `1e-12` | — |
| objective terms | `1e-10` | — |
| R-squared | `1e-12` | — |

Exact public example/optimization evidence:

```text
LMZ_QUAD_LOAD_SINGLE_STRIDE_OK samples=3057 events=9 residual=0.0034942
LMZ_QUAD_LOAD_MULTI_STRIDE_OK strides=2 samples=5825 objective=63.5580630419
SLIP_QUAD_LOAD_SCIENTIFIC_OK single=1 multi=2 objective=63.5580630419 terms=[0.52435 2.84657 5.96977]
LMZ_QUAD_LOAD_FIT_OK initial=63.5580630419 final=63.4193407268 decrease=0.138722315113
```

The public fitted solution remains 57 entries. Equal bounds fix the exact
source-prescribed prefix, while the shared optimizer varies only indices
54–57. The one-iteration SQP evidence intentionally returns a budget-limited
status when appropriate; the scientific assertion is finite objective
decrease, exact free-index/full-vector preservation, simulation of the result,
and optimization-artifact round-trip—not a global-optimum claim.

## Quadruped non-regression

The earlier RoadMap baseline remains unchanged: PK columns 1, 267, and 446
cover source residuals, duplicate-time trajectories, event states, 12-channel
GRFs, and gait classification. Existing tolerances remain residual `1e-11`,
time `1e-13`, state/event `1e-10` absolute with `1e-9` relative, and GRF
`1e-9` absolute with `1e-8` relative. Default point 267 still gives:

```text
scaled residual norm = 2.91e-11
solve algorithm      = accepted-existing-seed
```

All nine branches, exact Results29 conversion, physical visualization,
recording, GUI interaction, adjacent/generated seeds, scientific continuation,
checkpoint/resume, and the 20-point public RoadMap example remain green.

## Continuation hardening

Deterministic tests now record:

| Case | Expected evidence |
|---|---|
| Forced rejection | `maximum_backtracks`, two rejected snapshots at steps `0.08`, `0.04`, complete normalized diagnostics |
| Minimum step | `minimum_step`, one rejected `0.04` attempt; no subminimum corrector call |
| Curvature response | accepted step shrinks from `0.08` to `0.04` |
| History duplicate | rejected snapshot with `history-duplicate` |
| Stagnation | accepted terminal snapshot marked `stagnation` after a finite window |
| Historical segment crossing | three-point branch ending `loop_closure` |
| Cancellation | `controlled_stop`, seed/partial branch preserved |
| Scientific checkpoint | quadruped controlled stop after an accepted point, atomic snapshot artifact, resume to four points |
| Parameter activity | inactive `phi_neutral` rejected; nearby active `k_leg + 0.001` changes the residual, transports two targets, and corrects below `1e-7` |

Snapshots/artifacts expose predictor, corrected decision, residual, step,
curvature, corrector iterations, backtracking, feasibility, gait, checkpoint,
exit/failure, direction, achieved step, and termination candidate.

## GUI, desktop, and recording status

Automated tests construct every tab, display per-problem maturity badges,
select all three scientific models and their tutorial/scientific problems,
rebuild matching working solutions, gate actions from problem capabilities,
load all built-ins, edit/restore solutions, evaluate/simulate, dispatch physical
renderers and plots, solve/continue where supported, drive the load-fit GUI
callback and its objective/sensitivity/R-squared panes, and round-trip artifacts. The programmatic
`demo_full_desktop_workflow` completed in batch and is automated evidence only.

Human desktop QA is blocked because this process has no desktop/display.
`docs/MANUAL_DESKTOP_QA.md` records the exact quadruped, biped, and load
walkthrough still required. Existing Round 5 batch screenshots remain
automated captures and are not relabeled as human evidence.

## R2019b compatibility status

`check_matlab_compatibility` and `TestR2019bCompatibility` inspect language and
selected API usage, UI components, Optimization Toolbox option names,
`exportgraphics` guards, `VideoWriter` profiles, JSON/table calls, recursive
directory syntax, and `matlab.unittest` options. The final static result is
zero known violations on R2025b. No R2019b installation was available, so the
core suite and scientific examples remain unexecuted on R2019b.

## Standalone all-model isolation

`TestStandaloneAllScientificModels` copies the entire repository beneath a
new temporary parent containing no other directory, starts a clean child
MATLAB process, verifies all implementation paths resolve inside that copy,
and executes all three scientific models. It loads all built-in data,
evaluates/simulates each model, solves and continues biped/quadruped, performs
the bounded load fit, constructs the full GUI (or the documented display-only
fallback), and saves/reloads branch, solution, continuation, and optimization
artifacts.

Exact child-process marker:

```text
ISOLATED_ALL_SCIENTIFIC_MODELS_OK
```

The integration method passed in the final 117-test run; its focused timed
execution was approximately 31.3 seconds.

## Remaining release blockers

- Human MATLAB desktop walkthrough and human-captured model-specific
  screenshots are not available in this display-less process.
- MATLAB R2019b runtime execution is not available; only the static audit is
  complete.
- Remote GitHub Actions execution has not occurred; workflow configuration and
  local-equivalent checks are not reported as remote CI success.
- The repository has no owner-supplied root project license, so public core
  packaging is blocked independently of the scientific-source decisions.
- Public redistribution/packaging is blocked pending explicit owner decisions
  for quadruped code/data, biped code/data scope, and load code/data. See
  `docs/REDISTRIBUTION_STATUS.md`.

No remaining technical test, example, architecture, hash, isolation, or README
contract failure is known in the R2025b environment.
