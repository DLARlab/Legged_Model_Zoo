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
| `SimulationTab` | Profile resolution, physical renderers, scientific plots, playback, recording, and export |
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
`SimulationTab` owns `VisualizationProfileRegistry`, `RendererFactory`, the
current renderer/profile, and renderer-only controls. The GUI therefore never
hard-codes a scientific renderer class in model-selection logic.

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

Each visualizable catalog may own `graphics.lmz.json`. On model/problem change,
`SimulationTab` asks `VisualizationProfileRegistry` for the profiles applicable
to the problem maturity. It uses the configured maturity default unless a
valid per-model/problem preference exists. The built-in validated scientific
problems default to `research_legacy`; tutorial problems default to
`clean_generic`.

The visible profile labels are **Research legacy**, **Clean generic**, and
**High contrast** where applicable. `research_legacy` chooses a source-derived
compound renderer. `clean_generic` chooses the declarative scene or the model's
simple clean renderer and is not labeled source-faithful. Scientific
`high_contrast` profiles retain compound research geometry but deliberately
change palette/width; tutorial high contrast remains a generic scene style.

Changing the visual profile disposes the animation controller and renderer,
constructs the newly configured renderer through `RendererFactory`, redraws the
model-owned plot views, and initializes the replacement at the first frame of
the existing simulation. The tab shows the resolved label, renderer class, and
plot-profile ID so configuration mistakes are visible rather than hidden.

The renderer-option controls are:

| Control | Renderer option/behavior |
| --- | --- |
| **Detailed** | `DetailedOverlay`; source phase/details where implemented |
| **Ground** | Hatched, line, or hidden request; renderer may support a subset |
| **Forces** | `ShowForces`; force arrows where the renderer supplies them |
| **Follow** | `CameraFollow` |
| **Reset camera** | Restores the selected profile's camera values |

The header high-contrast palette styles application chrome. It is distinct from
the Simulation tab's `high_contrast` model-graphics profile.

Generic registered models implement `getVisualizationPlugin` and provide a
validated scene. `RendererFactory` supplies `SceneRenderer2D` with that plugin,
scene, simulation, resolved profile, and options. Model-owned
`plotSimulation(axesStruct,simulation,profile)` may provide richer plot routing;
otherwise named `PlotPlugin` descriptors are used. If no usable visualization
exists, the tab shows a named body trajectory when possible or reports that no
visualization was supplied. External models may also have no built-in branch
dataset.

Animation playback maps normalized stride time to physical samples. GIF, MP4,
keyframe, axes-GIF, and static-plot exports remain delegated to
`RecorderService` with cooperative cancellation, atomic temporary files, and
frame restoration. Every GUI export includes an adjacent metadata sidecar with
schema version, artifact kind, model/problem IDs, the resolved profile
descriptor, and creation time. Profile `frameCount`, `fps`, and `dpi` values
seed applicable requests; an explicit request/control value takes precedence.

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
`LeggedModelZoo_GUI_v1`. Schema version 2 persists window position, the
default/high-contrast application palette, user-chosen recent data/output
folders, and one visualization-profile ID per model/problem. A stored profile
is used only if it is still applicable; otherwise profile resolution returns to
the current maturity default. Reset removes all of these preferences. Built-in
repository paths are never recorded as recent folders. High-contrast selection
and hover indicators differ by marker shape, fill, outline, and color rather
than color alone.

## Verification boundary

Headless tests cover transactional exact-once delivery, deterministic ordering,
component APIs, one-refresh model changes, subscription disposal, busy-state
precedence, preferences/reset, minimum sizing, tooltips, status timestamps, and
palette distinguishability. Profile tests cover maturity defaults,
per-model/problem preference round trips, trusted factory dispatch, profile
switch rebuilds, renderer lifecycle, and recording metadata. Numeric geometry
tests are separate from GUI tests and remain the primary scientific graphics
fidelity gate.

OS-native dialogs, human hover ergonomics, actual keyboard focus traversal,
playback timing, cancellation timing, codecs, and side-by-side graphics review
still require the manual MATLAB desktop checklist in
`docs/MANUAL_DESKTOP_QA.md`. Hidden figures and image metrics are not human
approval. R2019b graphics execution is also unverified; current R2019b evidence
is static/fallback analysis only.
