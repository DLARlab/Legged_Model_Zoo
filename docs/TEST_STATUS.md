# Test status

## Current MATLAB environment

Executed on 2026-07-19 with:

- MATLAB `25.2.0.3177638 (R2025b) Update 5`
- Optimization Toolbox license: available (`1`)
- Parallel Computing Toolbox license: available (`1`)
- `usejava('desktop')`: false in batch mode
- Student License

Compatibility is targeted at R2019b, but this slice has only been executed on R2025b.

## Full suite

Command:

```bash
/Applications/MATLAB_R2025b.app/bin/matlab -batch "cd('/Users/nanyoujiayu/Documents/GitHub/Legged_Model_Zoo'); results=run_tests; assert(~any([results.Failed]));"
```

Exact final summary:

```text
Legged Model Zoo: 27 run, 0 failed, 0 incomplete.
```

This included architecture, README contract, GUI construction, headless controller simulation, artifacts, canonical aliases, schema/chart, catalog, built-in data, all-model simulation, and the legacy quadruped layout adapter.

## README synchronization

Command executed in MATLAB:

```matlab
startup;
addpath(fullfile(pwd,'tools'));
update_readme_status;
check_readme_contract;
```

Result:

```text
README model table is already current.
README contract valid for 3 canonical models.
```

## Public command-line examples

Executed `demo_registry.m`, `demo_slip_biped.m`, `demo_slip_quadruped.m`, and `demo_slip_quad_load.m` in one clean MATLAB batch process. Exact terminal marker:

```text
CLI_EXAMPLES_OK
```

## GUI launch smoke test

Executed the exact `legged_model_zoo` launcher, ran a controller simulation, validated the returned `SimulationResult`, and deleted the app. Exact marker:

```text
GUI_LAUNCH_AND_SIMULATION_OK
```

The `uifigure` constructed in batch mode. Interactive desktop behavior was not manually inspected because `usejava('desktop')` was false.

## Standalone isolation test

Copied the repository without `.git` or prompt files to:

```text
/private/tmp/lmz-round3-isolation.KWheLW/Legged_Model_Zoo
```

The temporary parent contained no sibling research repositories. A clean MATLAB process discovered the exact canonical model list, loaded and simulated all three built-in demonstrations, constructed the GUI, and closed it. Exact marker:

```text
ISOLATION_REGISTRY_SIMULATION_GUI_OK
```

## Static checks

- `git diff --check`: passed.
- All 9 catalog JSON and 3 built-in example JSON files parsed successfully.
- README has all 24 required sections in order.
- README normal-use sections contain no external-repository installation references.
- Runtime scans found no prohibited globals, path resets, recursive path adds, or dynamic evaluation.
- Old model package names are absent from active runtime code.
- All three immutable reference repositories remained clean.

## Not verified

- Published legacy numerical equivalence and measured tolerances
- Root solving, continuation, homotopy, branch-family scan, or optimization
- Interactive desktop usability and visual appearance
- Playback, GIF/MP4 recording, or export
- MATLAB R2019b compatibility execution
