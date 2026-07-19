# Migration status

| Phase | Status | Evidence / blocker |
|---|---|---|
| 0 Inventory and baselines | Partial | Fixture dimensions and fields inspected; reproducible minimal-input extraction script added. MATLAB unavailable, so numerical baselines remain blocked and unexecuted. |
| 1 Core scaffold | Implemented, untested | ProjectPaths, catalog validation, truthful capabilities, candidate-period charts, structural artifact validation, and root test runner implemented. Static checks pass; MATLAB tests not executed. |
| 2 Quadruped vertical slice | Partial | Results29 boundary adapter and complete disabled descriptor exist. Vendored evaluator, native branch objects, simulation, and numerical regression remain. |
| 3 Solve and continuation | Not started | Requires Phase 2 numerical baseline. |
| 4 GUI | Not started | Requires service vertical slice. |
| 5 Jerboa | Inventory only | Source and fixtures located. |
| 6 Load pulling | Inventory only | Source and fixtures located. |
| 7 Native hybrid refactor | Blocked by adapter gates | Must not precede numerical equivalence fixtures. |

## Documentation deliverables

| Deliverable | Status | Evidence / blocker |
|---|---|---|
| Detailed usage README | Implemented, untested | `README.md` documents setup, registry discovery, current capability truth, project paths, schemas/charts, legacy quadruped import/export, run controls, artifacts, catalog authoring, fixture regeneration, testing, limitations, and troubleshooting. Examples were reviewed against the current public APIs; MATLAB execution remains unavailable. |
| Architecture and migration records | Partial | Core architecture, provenance, inventory, fixtures, known differences, and test status exist. Model-author, configuration, data-format, continuation, and GUI guides remain incomplete. |
