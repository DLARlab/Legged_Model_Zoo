# Quadruped GUI layout map

This document maps the spatial organization of the immutable
`SLIP_Quadruped_GUI.m` at source commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a` to the Round 11
`scientific_workbench` profile. It records layout and interaction
correspondence only. Numerical parity is audited separately in
[quadruped-workflow-parity.md](quadruped-workflow-parity.md).

## Source hierarchy retained

The source GUI defines `mainGrid` as three rows by two columns:

```text
RowHeight   = {'fit', '1x', 93}
ColumnWidth = {'3.35x', '1.85x'}
Padding     = [12 12 12 12]
RowSpacing  = 10
ColumnSpacing = 12
```

Its left column contains Data Info, a persistent Plotting region, and Status.
Its sidebar tab group spans rows 1 through 3 in column 2. Round 11 retains this
hierarchy in `ScientificWorkbenchLayout`:

| Source placement | Round 11 placement | Status |
|---|---|---|
| `dataInfoPanel`, row 1 / column 1 | `DataRegion`, row 1 / column 1 | Mapped |
| `plottingPanel`, row 2 / column 1 | `WorkspaceCanvas`, row 2 / column 1 | Mapped and generalized |
| `statusPanel`, row 3 / column 1 | `StatusDock`, row 3 / column 1 | Mapped and expanded with progress |
| `sidebarTabs`, rows 1:3 / column 2 | `SidebarHost`, rows 1:3 / column 2 | Mapped |

Automated tests pin the three-row/two-column placement, the `3.35:1.85`
weights, spacing/padding, sidebar span, and status-row location.

## Central workspace map

| Source `plotTabs` / control | Round 11 component | Difference |
|---|---|---|
| **State Plot** axes | `BranchWorkspace`/`BranchCanvas` in central view `branch_state` | Axes are owned by a host-neutral component and survive every sidebar switch. |
| **Hildebrand Plot** | central view `hildebrand_footfall` | Registered as a workbench view; model data/provider supplies content. |
| Temporary continuation line | incrementally updated overlay layer `accepted_continuation` | Shares the persistent branch axes instead of a tab-specific copy; the terminal result replaces this same layer in place. |
| Predicted/solved seed markers | overlay layers `prediction` and `corrected solution` | Typed controller state replaces nested graphics/global state. |
| Continuation predictor/accepted/rejected markers | live continuation overlay layers | Same branch coordinate mapper and axes preset are used by every task. |
| Source axis selectors below the plot | `AxisControlPanel`/`BranchNavigationPanel` | Reusable branch component; registered `roadmap_top` applies the source defaults. |

Round 11 also provides `run_overlay`, a central diagnostics view that has no
direct source tab equivalent. It is an additive workbench view, not a change to
the branch calculation.

## Data and selection map

| Source Data Info / Info control | Round 11 host | Status / qualification |
|---|---|---|
| Dataset dropdown, **Select Folder**, **Plot**, **Plot All**, **Delete All** | `DataToolbar` + `DatasetPanel`; registered provider and explicit user import | Functional parity; built-in data is manifest/hash-bound. |
| Fixed/varying parameter dropdowns | `ParameterFilterPanel` and registered filter metadata | Named schemas/providers replace raw row numbers. |
| **Plotted Datasets** list | `DatasetPanel` in Info / Selection | Mapped; removing a view never deletes source data. |
| Cursor Info | hover-selection presentation | Transient preview; does not change the locked point. |
| Selected Info / **Remove Selected** | locked-selection presentation | Locked selection is controller-owned and shared by every component. |
| Axis limit/ratio/view controls and **Roadmap** | axis/navigation controls + registered axis preset | Source RoadMap axes are declarative (`dx`, `dphi`, `y`, top view, pinned limits). |
| **Save Plot** | existing axes/export service | Service path is shared by layouts. |

## Sidebar map

| Source sidebar | Round 11 sidebar task | Mapping |
|---|---|---|
| **Info** | **Info / Selection** | Dataset, hover/lock, named solution inspector, axes, and provenance. |
| **Visualization** | **Visualization** | Same simulation/animation/trajectory/GRF/recording component used by classic tabs. |
| **Solve** | **Solve / Seeds** | Working solution, noise, prediction, root solve, and pair construction; live solve snapshots feed status/overlays. |
| **Continuation > 1D** | **Continuation** direction controls | Forward/backward/both pseudo-arclength, pause/stop, checkpoint/resume, and live layers. |
| **Continuation > Para** | scrollable continuation homotopy controls | Active-parameter transport through `ContinuationService`. |
| **Continuation > 2D** | scrollable family-scan controls | Repeated one-dimensional branches at targets; not relabeled as a 2-D manifold solve. |
| **Oscillator Plot** | **Oscillator / Analysis** plus detailed Visualization plots | Locked index remains synchronized; rendering is model/provider owned. |
| No source equivalent | **Optimization** | Preserves current LMZ capability without changing the source-inspired branch hierarchy. |
| No source equivalent | **Advanced Shooting / Horizon** | Additive scrollable task entry for current LMZ shooting/horizon workflows. |

Each dense Round 11 task owns a scrollable viewport. Changing tasks changes the
sidebar content, not the branch axes, selected dataset, or locked point.

## Status and progress

The source bottom status panel is a scrollable label updated by nested
callbacks. Round 11 keeps the bottom-left always-visible location and adds:

- timestamped copyable history;
- severity and technical details;
- current stage and progress gauge;
- GUI-independent solve-iteration snapshots; and
- continuation predictor/accept/reject summaries.

The status history remains when the current progress stage is cleared.

## Resize and scrolling map

The source figure is scrollable, its component positions are refreshed in
`FigureResized`, and dense solve/continuation sections maintain content panels
with explicit minimum heights. Round 11 generalizes that policy:

- the whole workbench has a scroll viewport;
- every dense sidebar tab has its own stable scroll viewport;
- minimum content dimensions are computed from nested grid/control extents and
  retained rather than shrinking controls until they overlap;
- the application remains operable at `900 x 650`; and
- branch/workspace space expands at `1120 x 740`, `1460 x 900`, and
  `1920 x 1080`.

Automated clipping tests inspect enabled controls against scroll-content
bounds. A minimum window setting alone is not counted as adaptive layout.

## Preserved framework separations

The source GUI is one nested-function application and uses global state. Round
11 deliberately does not reproduce that architecture. Its hierarchy is:

```text
layout and host-neutral components
  -> AppController / AppState / presentation events
  -> generic solve, seed, continuation, artifact, and export services
  -> registered problem contracts
  -> model-owned data, legacy, visualization, and scientific providers
```

The scientific and classic profiles construct the same six primary reusable
components. A layout switch disposes old roots and subscriptions; numerical
state remains in the controller. Generic GUI/services do not choose a
built-in model by ID.

## Verification status

Automated Round 11 tests cover scientific construction, source ratios,
three-row sidebar span, persistent branch axes and overlays across every
sidebar tab, scroll content, enabled-control clipping at minimum/preferred
sizes, large-window expansion, preference round trip, lifecycle/subscription
cleanup, status progress, and classic-tabs fallback.

The source-side-by-side human walkthrough remains unexecuted because the
validation process has no MATLAB desktop. Automated screenshots must remain
labeled automated and are not evidence of keyboard behavior, focus order,
platform/DPI quality, or human visual approval.
