# Round 11 automated GUI captures

Every PNG in this directory is generated in MATLAB batch mode by
`tools/generate_round11_gui_screenshots.m`. These images document automated
construction and deterministic staged presentation states. They are not human
desktop approval and do not replace the manual walkthrough, focus, resize, or
visual-quality gates.

| File | Automated state |
|---|---|
| `01_workbench_initial_roadmap_automated.png` | Registered quadruped workflow at `PK_20_2` point 267 in `scientific_workbench`. |
| `02_workbench_locked_solution_automated.png` | Locked point 268 propagated to the shared branch and Info / Selection views. |
| `03_workbench_live_solve_automated.png` | Deterministically staged typed solve iteration 4, including residual history and current-iterate overlay. |
| `04_workbench_seed_pair_automated.png` | Adjacent 268/269 seed pair with source-aware diagnostics on the persistent branch canvas. |
| `05_workbench_live_continuation_automated.png` | Deterministically staged accepted continuation point with direction, prediction, corrected coordinate, residual, and overlay. |
| `06_workbench_physical_visualization_automated.png` | Registered physical renderer hosted in the scrollable Visualization sidebar while the branch canvas remains visible. |
| `07_workbench_minimum_scrolled_sidebar_automated.png` | Requested `900 x 650` window with the dense continuation content intentionally scrolled. |
| `08_classic_layout_fallback_automated.png` | The same controller state rehosted on the Scientific Branches tab in the retained `classic_tabs` shell. |

The `live solve` and `live continuation` names refer to the same event-driven
presentation paths used during a run. They are deliberately staged at stable
mid-run states so the repository does not depend on screenshot timing races;
they are not evidence that a human watched those operations execute.

Every PNG is classified by the redistribution inventory as a
`scientific-quadruped-derived` file sourced from the RoadMap manifest. The
captures are excluded from the core profile and remain unauthorized for public
redistribution while the quadruped owner decision is unresolved.

The 2026-07-21 R2025b batch display capped the rendered client area at 1352 by
749 pixels. Captures 1–6 use that rendered extent, capture 7 is exactly 900 by
650, and the classic capture is 1460 by 749. Automated visual inspection
confirmed nonempty, internally consistent states, but no human desktop review
was performed.
