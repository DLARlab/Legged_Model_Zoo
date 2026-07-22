# Performance benchmarks

`run_benchmarks` measures 29 release workflows: the 14 historical Round 7
startup/discovery, scientific data/evaluation, rendering, short solve and
continuation, GUI, and artifact paths plus seven Round 9 section, timing,
stride-plan, requested-N simulation/objective, and GUI-refresh paths, and eight
Round 10 rectangular-timing, two-/three-/five-segment shooting, Jacobian,
periodic-correction, horizon-continuation, and GUI-diagnostics paths. Run it
from a fresh MATLAB process after `startup`:

```matlab
addpath(fullfile(pwd, 'benchmarks'));
report = run_benchmarks(struct('Repetitions', 3));
```

The tracked historical Round 7 measurement is
`baseline_r2025b_macos_arm64.json`. It contains 14 three-repetition records
from MATLAB R2025b on macOS arm64. The tracked Round 9 addendum is
`round9_r2025b_macos_arm64.json`; it records the seven new workflows over three
warm repetitions. All medians are below their conservative budgets. Regenerate
the complete current 29-workflow report explicitly with:

```matlab
report = run_benchmarks(struct( ...
    'Repetitions', 3, ...
    'OutputPath', fullfile(pwd, 'benchmarks', ...
    'round11_full_matrix_r2025b_macos_arm64.json')));
```

The retained Round 11 full-matrix report contains 29 records over three
repetitions with zero median budget overruns. Representative medians are
`0.028220` seconds for quadruped evaluation, `2.412601` seconds for short
quadruped continuation, `23.801468` seconds for real GUI construction,
`31.308906` seconds for 20 stride-plan GUI refreshes, and `26.679989` seconds
for 20 horizon-diagnostics refreshes.

The reported median and median absolute deviation are warm-process wall-clock
measurements. `MemoryBytes` is only the shallow MATLAB size of each returned
value; it is a portable estimate, not a process-resident-memory measurement.
Each record names its fixture, exact MATLAB release, architecture, and a
deliberately conservative regression budget. The budgets protect against
large regressions, not normal machine-to-machine variation.

Round 11 adds a separate focused workbench benchmark covering the ten layout
and interaction operations required by the registered-workflow GUI gate:

```matlab
addpath(fullfile(pwd, 'benchmarks'));
report = run_round11_workbench_benchmarks(struct('Repetitions', 3));
```

The report contains these ten records:

| Record ID | Operation | Median / budget (s) |
| --- | --- | ---: |
| `workbench_construction` | Construct a hidden `scientific_workbench` at the preferred size. | `9.615918 / 30` |
| `model_workflow_switch` | Switch from the biped model to the registered quadruped RoadMap workflow. | `15.948671 / 20` |
| `roadmap_all_branches_registered_load` | Load every RoadMap branch through its registered provider. | `0.692777 / 60` |
| `branch_axis_change_with_overlays_20` | Change branch axes 20 times while source, locked, and edited overlays remain active. | `0.062638 / 20` |
| `branch_hover_updates_100` | Publish 100 nearest-point hover updates. | `0.368564 / 15` |
| `sidebar_tab_switching_50` | Switch the scrollable sidebar task 50 times without replacing the central axes. | `0.331013 / 20` |
| `solve_progress_updates_100` | Deliver 100 typed solve-progress snapshots. | `3.093588 / 20` |
| `accepted_continuation_overlay_updates_20` | Add 20 accepted continuation solutions incrementally. | `0.253893 / 20` |
| `minimum_size_resize_scroll_refresh_20` | Alternate minimum/preferred sizes and refresh scroll geometry 20 times. | `0.987596 / 20` |
| `classic_workbench_layout_switch_10` | Rebuild the host-neutral classic/workbench placement ten times. | `81.694518 / 120` |

Every record has a conservative budget. The retained R2025b report
`round11_r2025b_macos_arm64.json` records three repetitions and zero overruns.

For the routine test gate, use `GateOnly=true`. It measures the stable core and
service paths without repeating the full rendering and continuation workload.
The GUI record always constructs the real `uifigure`, all six tab components,
their subscriptions, and the initial refresh before closing the app; the
headless controller-only constructor is not counted as GUI construction:

```matlab
report = run_benchmarks(struct('Repetitions', 1, 'GateOnly', true));
```

There is no process-global numerical cache. A multiple-shooting residual call
retains each segment result only within that immutable evaluation, so residual
blocks, physical diagnostics, and optional simulations share one propagation
without allowing stale results after a decision edit. Any future cross-call
cache must be bounded, version/data-hash keyed, explicitly clearable, and tested
for invalidation and cross-run isolation.

The recorded profile does not justify a process-global numerical cache:
scientific evaluations remain well below one second and short continuation is
`2.412601` seconds. GUI construction is now `23.801468` seconds because it
builds the real selectable scientific/classic shell and every host-neutral
component, while subsequent overlay/sidebar refresh operations remain small.
Adding cache invalidation and cross-run state would currently cost more
complexity than it removes.
