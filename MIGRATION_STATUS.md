# Migration status

| Phase | Status | Evidence / blocker |
|---|---|---|
| 0 Inventory and baselines | Partial | Repositories, commits, key entry points and fixtures inventoried. MATLAB unavailable, so numerical baselines are not executed. |
| 1 Core scaffold | Partial | Schema/chart, registry, run controls and artifact storage implemented; MATLAB tests not executed. |
| 2 Quadruped vertical slice | Partial | Results29 boundary adapter and manifest exist. Vendored legacy evaluator, simulation and regression fixture remain. |
| 3 Solve and continuation | Not started | Requires Phase 2 numerical baseline. |
| 4 GUI | Not started | Requires service vertical slice. |
| 5 Jerboa | Inventory only | Source and fixtures located. |
| 6 Load pulling | Inventory only | Source and fixtures located. |
| 7 Native hybrid refactor | Blocked by adapter gates | Must not precede numerical equivalence fixtures. |
