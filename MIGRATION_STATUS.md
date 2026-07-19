# Migration status

| Phase | Status | Evidence / blocker |
|---|---|---|
| 0 Scientific baselines | Partial | Source repositories and fixture layouts are documented. Published residual/trajectory/objective baselines were not captured in Round 4; no legacy equivalence or tolerance is claimed. |
| 1 Core contracts | Tested | Validated problem, residual evaluation, solution, solution-pair, schema-matrix branch, dataset, selection, and numerical result contracts pass the 36-test R2025b suite. |
| 2 `slip_quadruped` | Partial | Native periodic problem, branch, solve, second seed, continuation, homotopy, family scan, persistence, controller, and GUI paths are tested. The published 22-variable compatibility evaluator and baseline equivalence remain. |
| 3 Generic numerical workflows | Tested | Generic `FsolveSolver`, `SolveService`, seed perturbation/second seed, pseudo-arclength continuation, parameter homotopy, branch-family scan, `FminconSolver`, and optimization service execute in regular and isolated copies. |
| 4 GUI | Partial | Branch, Solution, Solve, Continuation, and Optimization tabs have executable controls; construction and controller workflows are tested. Full editing, hover/click UI, pause/resume controls, file dialogs, and manual desktop inspection remain. |
| 5 `slip_biped` | Partial | Native periodic solve/continuation and trajectory fitting are tested. Published 12-decision/15-residual evaluator, Results14 import, gait baselines, and equivalence remain. |
| 6 `slip_quad_load` | Partial | Native multi-stride named objective and optimization are tested. Published 44+13(N-1) evaluator/packer, X_accum import, objective baselines, and equivalence remain. |
| 7 Native hybrid refactor | Blocked | Compatibility evaluators and measured scientific baselines must precede equation refactoring. |

## Documentation deliverables

| Deliverable | Status | Evidence / blocker |
|---|---|---|
| Standalone README | Tested | Machine-generated capability table is current; README contract passes in MATLAB and the full suite. |
| Numerical workflow evidence | Tested | Exact R2025b commands, 36-test result, eleven-example result, and isolated advanced workflow are recorded in `docs/TEST_STATUS.md`. |
| Scientific provenance/equivalence | Partial | Repository commits and legacy layouts are recorded; no legacy code was copied and no scientific equivalence result exists. |
