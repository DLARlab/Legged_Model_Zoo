# Test status

## Environment

- MATLAB `25.2.0.3177638 (R2025b) Update 5`
- Optimization Toolbox: licensed
- Parallel Computing Toolbox: licensed but not required
- `usejava('desktop')`: false in batch mode
- Student License

Compatibility remains targeted at R2019b but was not executed on that release.

## Full suite

Command:

```bash
/Applications/MATLAB_R2025b.app/bin/matlab -batch "cd('/Users/nanyoujiayu/Documents/GitHub/Legged_Model_Zoo'); startup; addpath(fullfile(pwd,'tools')); update_readme_status; check_readme_contract; results=run_tests; assert(~any([results.Failed]));"
```

Exact summary:

```text
README model table is already current.
README contract valid for 3 canonical models.
Legged Model Zoo: 36 run, 0 failed, 0 incomplete.
```

Coverage includes prior architecture/catalog/schema/simulation/GUI tests plus solution/branch contracts, native run artifacts, both periodic solves, both optimizations, second-seed radius, pseudo-arclength continuation, homotopy, family scan, and advanced controller workflows.

## Direct numerical evidence

Executed end-to-end controller workflow result:

```text
WORKFLOW_OK solve=1.57e-16 radius=0.03 points=6 objective=3.04e-17
```

Executed quadruped continuation diagnostic:

```text
radius=0.0300009 err=9.22e-07
points=8 reason=maximum_points maxres=1.57e-16
```

Executed load optimization diagnostic:

```text
exit=2 initial=0.4425 final=3.03682e-17
```

These are native demonstration results, not legacy-equivalence measurements.

## Public examples

One clean MATLAB process executed all eleven required Round 4 examples. Each printed `EXAMPLE_OK`:

```text
demo_branch_explorer.m
demo_solution_inspector.m
demo_slip_biped_solve.m
demo_slip_biped_continuation.m
demo_slip_biped_fit.m
demo_slip_quadruped_solve.m
demo_slip_quadruped_continuation.m
demo_parameter_homotopy.m
demo_branch_family_scan.m
demo_slip_quad_load_fit.m
demo_full_gui_workflow.m
```

## Isolated advanced workflow

The repository was copied without `.git` or prompt files to:

```text
/private/tmp/lmz-round4-isolation.CMWr3w/Legged_Model_Zoo
```

The parent contained no research repositories. MATLAB executed branch selection, quadruped solve, second seed, five-point continuation, load optimization, and GUI construction. Exact marker:

```text
ISOLATED_ADVANCED_WORKFLOWS_OK
```

## Static checks

- Catalog and built-in JSON files parse.
- `git diff --check` passes.
- README contract and generated capability table pass.
- Generic services and GUI contain no direct model evaluator calls.
- GUI contains no direct `fsolve`, `fmincon`, or `fminsearch` calls.
- The three immutable source repositories remain clean.

## Not verified

- Published legacy residual, trajectory, event, force, gait, or objective equivalence
- Measured scientific regression tolerances
- Results14 and X_accum native imports
- File-backed checkpoint resume, pause/resume UI, curvature/stagnation/loop policies
- Manual interactive desktop inspection
- MATLAB R2019b execution
