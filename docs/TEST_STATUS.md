# Test status

## Environment

- MATLAB `25.2.0.3177638 (R2025b) Update 5`
- Optimization Toolbox: licensed
- Parallel Computing Toolbox: licensed but not required
- Student License
- `usejava('desktop')`: false in the verification process

Compatibility remains targeted at R2019b, but this round was not executed on that release.

## Full suite and static contracts

Final command:

```bash
/Applications/MATLAB_R2025b.app/bin/matlab -batch "cd('/path/to/Legged_Model_Zoo'); startup; addpath(fullfile(pwd,'tools')); addpath(fullfile(pwd,'tools','maintainers')); check_readme_contract; violations=static_architecture_check(pwd); assert(isempty(violations),strjoin(violations,newline)); report=verify_slip_quadruped_roadmap; results=run_tests; assert(~any([results.Failed])); assert(~any([results.Incomplete]));"
```

Exact final summary:

```text
README contract valid for 3 canonical models.
LMZ_ROADMAP_VERIFY_OK branches=9 points=3443 files=11
Legged Model Zoo: 55 run, 0 failed, 0 incomplete.
ROUND5_FULL_OK run=55 failed=0 incomplete=0
```

The 55 tests cover the earlier model/catalog/schema/simulation/solve/optimization contracts plus all-asset manifest hashes, nine native imports, exact Results29 round-trip and metadata, scientific residual/trajectory/event/GRF/gait equivalence, strictly increasing public simulation, physical kinematics/rendering/plots, multi-dataset 2-D/3-D hover and lock synchronization, real table edits, plot visibility semantics, downstream-state invalidation, manual/adjacent/generated seeds, scientific continuation, callbacks, controlled stop, checkpoints/resume, homotopy/family scan, atomic recording/export, GUI construction, README, and static architecture rules.

## Scientific regression

The repository-contained fixture was captured once from immutable `SLIP_Model_Zoo` commit `2c106101383ecee1b2a9d695efe09fbd72d5718a`, using `PK_20_2.mat` columns 1, 267, and 446. Ordinary tests do not access the sibling source repository.

| Quantity | Absolute tolerance | Relative tolerance |
|---|---:|---:|
| residual | `1e-11` | direct absolute comparison |
| raw time | `1e-13` | direct absolute comparison |
| raw state / event state | `1e-10` | `1e-9` |
| 12-channel GRF | `1e-9` | `1e-8` |

The source and migrated compatibility evaluator are the same preserved numerical statements, so the captured adaptive grids compare directly in R2025b. Each case also compares state and GRF trajectories on a 401-sample common interpolation grid after selecting the last sample at duplicate event times. Public `SimulationResult` separately applies that last-sample policy and preserves pre/post states in nine event records.

Default RoadMap point 267 produced:

```text
scaled residual norm = 2.91e-11
solve algorithm      = accepted-existing-seed
```

The first corrected point of a three-point scientific continuation produced:

```text
SCIENTIFIC_CONTINUATION_EVIDENCE points=3 residual=2.0478450749452257e-11 reason=maximum_points
```

Generated second-seed evidence used requested radius `0.005`, achieved `0.0050000007`, residual `5.45e-12`, and positive exit flag 4. Named `phi_neutral` homotopy completed two targets, and a one-target family scan returned one completed three-point branch.

## Public RoadMap example

The example now bootstraps correctly even when invoked with `run(...)`, which temporarily changes MATLAB's current directory to `examples`:

```text
LMZ_ROADMAP_WORKFLOW_OK seed=267 residual=2.91e-11 solve=accepted-existing-seed continuation=20
ROUND5_EXAMPLE_OK points=20 artifact=branch figures=6
```

It created a source branch plot, physical selected frame, torso/back/front trajectories, GRF plot, oscillator plot, continuation overlay, and a reloadable 20-point native artifact using only repository-contained data and public APIs.

## GUI and recording evidence

Automated GUI interaction tests construct the complete `uifigure`, edit a working value through the actual table callback, exercise Plot selected/all/clear, verify 3-D nearest hover leaves the lock unchanged, and check the new playback, metadata, diagnostics, and checkpoint widgets.

Recording tests verify:

- GIF output and renderer-frame restoration;
- three PNG keyframes;
- PNG plot export;
- animated-axes/oscillator GIF;
- MP4 through `VideoWriter` when supported;
- invalid frame-count rejection without a partial destination;
- inactive recording state and closed resources after completion.

Five real batch-graphics app captures are stored under `docs/screenshots/`:

```text
roadmap_branch_explorer.png
roadmap_selected_solution.png
roadmap_animation.png
roadmap_trajectories_grf.png
roadmap_continuation_overlay.png
```

Exact capture marker:

```text
ROUND5_BATCH_SCREENSHOTS_OK files=5 continuation=4
```

These are automated captures, not a claim that the human desktop checklist was performed.

## Final isolated workflow

The final working tree was copied without `.git` or Round prompt files to:

```text
/private/tmp/lmz-round5-final-isolation.eMRCoO/Legged_Model_Zoo
```

Its parent contains no sibling research repository. A clean MATLAB process loaded all nine branches (3,443 points), evaluated and simulated the default point, constructed the GUI, updated a physical renderer frame, accepted the solved seed, created the adjacent pair, ran a three-point scientific continuation, and saved/reloaded its native branch artifact.

Exact marker:

```text
ISOLATED_ROADMAP_WORKFLOW_OK branches=9 points=3443 residual=2.91e-11 solve=accepted-existing-seed continuation=3 gui=1 frame=1279 artifact=branch
```

## Still not verified

- Human MATLAB desktop walkthrough, including hover ergonomics, native file dialogs, interactive continuation Pause/Resume/Stop timing, codecs, and clean close
- The prompt's screenshots as manually captured evidence (the five repository PNGs are automated batch captures)
- MATLAB R2019b execution
- Forced scientific corrector rejection, curvature-threshold, stagnation, and historical-segment loop-closure termination cases
- Published biped Results14 equivalence and load-pulling `X_accum`/objective equivalence
- Upstream redistribution rights; the source repository provides no license or notice
