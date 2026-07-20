# GUI design

## Ownership

`LeggedModelZooApp` is the composition root. It owns application lifecycle, the
top-level figure, model/problem/example selectors, capability summary, palette
and preference reset controls, timestamped status aggregation, tab composition,
and close/cancel coordination. It does not build tab contents, render model
results, or execute tab-specific callbacks.

The six complete handle components are:

| Component | Responsibility |
| --- | --- |
| `BranchTab` | Scientific catalogs, datasets, selection, hover, navigation, branch plots, import/export |
| `SolutionTab` | Schema-aware editing, evaluation, projection, restore, save, and workflow handoff |
| `SimulationTab` | Physical renderers, scientific plots, playback, recording, and export |
| `SolveTab` | Reproducible perturbations, solve/refine, seed-pair construction, and overlay |
| `ContinuationTab` | Live prediction/accept/reject presentation, pause/resume/stop, checkpoints, homotopy, and family scans |
| `OptimizationTab` | Fit/cancel controls and objective, sensitivity/term, and R-squared presentation |

Every tab implements `build`, `refresh`, `setBusy`, `setCapabilities`,
`setSelection`, `dispose`/`delete`, and `testHooks`. `BaseTab` supplies common
subscription ownership, refresh counting, and capability/busy-state
composition. Widget handles are private to their tab; read-only aliases on the
main app temporarily preserve the Round 6 test-facing interface.
`RoadMapBranchTab` is an internal compatibility name for `BranchTab`.

Tabs delegate scientific actions to `AppController`. The controller invokes
services and owns state transitions; it stores no graphics handles and no
callbacks that capture tabs or figures. Model-specific renderers and plot
providers remain presentation adapters and do not alter scientific arrays.

## State and synchronization

`AppState` carries the active model/problem, catalogs and datasets, hover and
locked selections, working/solved solutions, simulation, seed pair,
continuation preview/result, optimization result, run/recording state, and
status. Observable state changes are mapped to validated topics by
`PresentationEventBus`.

Controller transactions coalesce repeated topics and deliver one ordered batch
per logical operation. Thus a model change can load a dataset, lock its seed,
and invalidate incompatible results while every interested tab refreshes once
from the final state. Run-state events update control enablement without forcing
scientific redraws. Continuation progress is published as prediction, accepted,
rejected, and completed presentation state; numerical callbacks no longer hold
references to UI objects.

Subscriptions are explicit disposable handles. Application close cancels work,
removes the application subscription, disposes every tab subscription and
animation callback, clears figure callbacks, and deletes the figure. Lifecycle
tests retain the controller/event bus across close and assert zero remaining
subscriptions. The rationale and R2019b constraints are recorded in
`docs/adr/0004-gui-event-synchronization.md`.

## Branch and solution workflows

The branch component dispatches the same explorer to the nine-branch quadruped
RoadMap, six-branch biped GaitMap, and two load datasets. It supports catalog,
folder, individual legacy/native MAT, visibility, reload/remove, native/legacy
export, 2-D/3-D schema coordinates, view limits, and model presets. A registered
external model without branch data receives a valid empty-dataset view instead
of an error.

Hover uses visible range-scaled coordinates and never changes the locked point.
Locking synchronizes active dataset, working solution, problem, and oscillator
index and invalidates stale derived state. The inspector separates initial
state, event timing, parameters, observables, residual/objective blocks,
diagnostics, and provenance. Editable values update an unevaluated working copy;
evaluation repopulates derived data.

## Simulation and extensibility

The three migrated scientific models keep their existing renderer and plot
provider dispatch as regression oracles. Other registered models may implement
`getVisualizationPlugin`; the simulation component calls the plugin's
`createRenderer(axes,simulation)` and optional
`plotSimulation(axesStruct,simulation)` hooks. If no plugin exists, a generic
named body trajectory is shown when possible, otherwise the GUI reports that no
visualization was supplied. External models may also have no built-in branch
dataset.

Animation playback maps normalized stride time to physical samples and restores
frame state after recording. GIF, MP4, keyframe, axes-GIF, and static-plot
exports remain delegated to `RecorderService` with cooperative cancellation.

## Usability and accessibility

All workspaces use resizable grid layouts, including the trajectory sub-tabs.
The main window enforces a minimum usable size. Non-obvious controls have stable
tags and tooltips; controls are created in documented keyboard traversal order.
Arrow-key branch navigation is active only while the Branch tab is selected.

Busy state takes precedence over capability state. Ordinary actions are
disabled during a run, while the matching cancel or pause/resume/stop actions
remain available. Status records include timestamps and bounded copyable
history. Errors add a plain summary to status and open a dialog with
expandable/copyable technical details when a desktop is available.

`PreferencesStore` uses the versioned MATLAB preference namespace
`LeggedModelZoo_GUI_v1`. It persists the window position, default/high-contrast
palette, and user-chosen recent data/output folders, and exposes a reset action.
Built-in repository paths are never recorded as recent folders. High-contrast
selection and hover indicators differ by marker shape, fill, outline, and color
rather than color alone.

## Verification boundary

Headless tests cover transactional exact-once delivery, deterministic ordering,
component APIs, one-refresh model changes, subscription disposal, busy-state
precedence, preferences/reset, minimum sizing, tooltips, status timestamps, and
palette distinguishability. Existing controller and callback-level scientific
GUI tests remain non-regression gates for all three models.

OS-native dialogs, human hover ergonomics, actual keyboard focus traversal,
playback timing, cancellation timing, codecs, and screenshots still require the
manual MATLAB desktop checklist in `docs/MANUAL_DESKTOP_QA.md`.
