# Migration status

| Phase | Status | Evidence / blocker |
|---|---|---|
| 0 Inventory and baselines | Partial | Fixture dimensions and fields inspected; reproducible minimal-input extraction script added. MATLAB unavailable, so numerical baselines remain blocked and unexecuted. |
| 1 Core scaffold | Tested | ProjectPaths, catalog validation, aliases, schemas/charts, artifact validation, run context, and test runner are covered by the full R2025b run: 27 tests, 0 failed, 0 incomplete. |
| 2 `slip_quadruped` vertical slice | Partial | Canonical package/catalog, exact Results29 adapter, standalone analytic demonstration simulation, named outputs, generic SimulationService path, GUI use, and scene are implemented. Published legacy evaluator, native branch objects, solve/continuation, and numerical equivalence remain. |
| 3 Solve and continuation | Not started | Requires Phase 2 numerical baseline. |
| 4 GUI | Partial | `legged_model_zoo`, AppController, selectors, built-in examples, generic simulation, trajectory plot, time scrubber, status log, construction, and shutdown are tested in batch mode. Advanced tabs, playback/recording, and manual interactive-desktop inspection remain. |
| 5 `slip_biped` | Partial | Canonical analytic simulation, named states, built-in data, service/controller workflow, visualization data, and GUI use are tested. Published evaluator, import, solve, continuation, and fit remain. |
| 6 `slip_quad_load` | Partial | Canonical analytic simulation, load/tugline observables, built-in data, service/controller workflow, visualization data, and GUI use are tested. X_accum import, legacy evaluator, objective decomposition, and optimization remain. |
| 7 Native hybrid refactor | Blocked by adapter gates | Must not precede numerical equivalence fixtures. |

## Documentation deliverables

| Deliverable | Status | Evidence / blocker |
|---|---|---|
| Detailed standalone README | Tested | `README.md` follows the Round 3 section contract. `update_readme_status` reported the table current and `check_readme_contract` passed for three canonical models; the documentation test passed in the 27-test suite. |
| Architecture and migration records | Partial | Core architecture, provenance, inventory, fixtures, known differences, and test status exist. Model-author, configuration, data-format, continuation, and GUI guides remain incomplete. |
