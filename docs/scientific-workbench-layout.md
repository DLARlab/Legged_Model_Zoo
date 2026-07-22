# Scientific workbench layout

The `scientific_workbench` profile reorganizes the existing GUI around one
persistent branch context. It is inspired by the useful spatial hierarchy of
the source SLIP quadruped GUI while retaining the Legged Model Zoo controller,
services, reusable components, problem capabilities, and model registration
boundaries. It does not embed scientific algorithms in UI callbacks.

The classic six-tab shell remains available as `classic_tabs`. Both profiles
host the same branch, solution, simulation, solve, continuation, and
optimization component implementations.

## Choose a layout

Launch the application and use the **Layout** selector in the header:

- **Scientific workbench** (`scientific_workbench`) keeps the branch/data
  canvas visible while task panels change.
- **Classic tabs** (`classic_tabs`) retains the established six top-level
  tabs.

The selected profile is stored in the versioned GUI preferences. **Reset
preferences** restores the registered/default profile. Selecting a registered
workflow may select its declared layout; the user can still switch profiles.

For tests or embedding code:

```matlab
controller = lmz.gui.AppController();
controller.setLayoutProfile('scientific_workbench');
profileId = controller.layoutProfileId();
```

`LayoutProfileRegistry.list()` returns the available IDs. Layout objects and
widget handles are internal GUI APIs; external code should select a profile by
ID through the controller/application boundary.

## Spatial contract

At the preferred size, the scientific shell uses a three-row, two-column
hierarchy:

```text
+--------------------------------------+-----------------------+
| Data Info                            |                       |
+--------------------------------------+  scrollable sidebar   |
| Persistent workspace                |  task tabs             |
|  - Branch / State Plot              |                       |
|  - Hildebrand / Footfall            |                       |
|  - Run Overlay                      |                       |
+--------------------------------------+                       |
| Status / progress                    |                       |
+--------------------------------------+-----------------------+
```

The nominal left/right column weights are `3.35:1.85`. The left column has a
fit-height data region, an expanding workspace, and an always-visible
93-pixel status/progress dock. The right sidebar spans all three rows. Padding
is 12 pixels, row spacing is 10, and column spacing is 12 at the source-inspired
profile level.

The central workspace owns independent view tabs, but changing them does not
recreate the application controller or sidebar components. `branch_state` is
the primary shared coordinate system. Registered workbench contributions may
also expose footfall and run-diagnostic views.

## Persistent branch context

The branch axes remain alive while the user opens information, visualization,
solve, continuation, optimization, oscillator/analysis, or advanced shooting
panels. Locked selection is the authoritative point; hover is a transient
preview and never replaces it.

One locked selection updates:

- the branch information and schema inspector;
- the working solution used by simulation and visualization;
- solve/noise/prediction state;
- seed-pair and continuation controls;
- oscillator/analysis selection; and
- overlay coordinates resolved through the selected registered axis preset.

The shared overlay controller owns separately addressable layers for locked
selection, perturbed seed, prediction, corrected solution, seed pair, live
continuation predictor, accepted continuation, and rejected points. The
accepted-continuation layer grows incrementally and the terminal result
replaces that same layer in place with the final or stopped partial branch.
Switching a sidebar task changes visibility/presentation state without
changing the underlying branch or duplicating numerical work.

## Solve and continuation progress

The status dock combines timestamped, copyable history with a current stage,
progress gauge, and exact diagnostic text. It remains visible across sidebar
tasks.

`SolveService` publishes GUI-independent `SolveIterationSnapshot` values
through `SolveCallbacks` and stores them in `SolveProgress`/`SolveResult`.
The controller converts those snapshots into status text and a solve overlay;
the solver does not depend on a figure. An already acceptable seed records a
zero-iteration lifecycle rather than inventing an iteration.

Continuation uses the established prediction, accepted, and rejected
snapshots. **Direction** offers `forward`, `backward`, and `both`; registered
labels can explain the physical branch orientation. The quadruped reference
workflow defaults to `both`. Pause/resume/controlled-stop and checkpoint state
remain owned by the existing run context and continuation service.

## Scroll and resize behavior

The window minimum is `900 x 650`. Minimum size is not used as a clipping
workaround: the entire workbench and every dense sidebar panel are hosted in
scrollable viewports. When available space is below the content minimum, the
content retains its usable dimensions and scrollbars expose it. At larger
sizes the branch axes and workspace expand.

Sidebar scroll minima are derived after construction from nested grid tracks
and the controls on every nested tab page. A compact construction floor is not
the content contract: fixed dense control rows drive horizontal extent only
when their controls genuinely need it, while wrapped labels contribute bounded
width and computed line height.

Current automated size contracts cover:

| Window | Contract |
|---|---|
| `900 x 650` | Workbench remains scrollable; enabled sidebar controls stay within their scroll content. |
| `1120 x 740` | Preferred scientific layout; enabled sidebar controls are not clipped. |
| `1460 x 900` | Branch axes and central workspace receive expanded space. |
| `1920 x 1080` | Large-window expansion remains proportional. |

Sidebar and central-view selections, layout profile, and sidebar-width ratio
are persisted. Rebuilding the shell disposes the former component roots and
subscriptions before constructing the selected profile, preventing duplicate
callbacks.

## Capability and registration behavior

Workbench contributions are declarative presentation metadata. The shell
enables task panels from the selected problem's capability descriptor; a
workbench cannot make an unsupported solve, continuation, or optimization
available. A branch-capable registered model can request
`scientific_workbench` without a core model-ID case. Models with no branch
contribution receive the clean `classic_tabs` fallback.

See [registered-workflows.md](registered-workflows.md) for data, workflow, and
workbench registration, and [gui-layout-profiles.md](gui-layout-profiles.md)
for the profile-selection contract.

## Automated versus human evidence

Batch GUI tests construct both profiles, inspect placement/ratios, exercise
profile switching, preserve the branch axes across sidebar tabs, check
scrollable content and clipping at the sizes above, verify one subscription per
component, and exercise the status/progress panel. Automated screenshots, when
generated, must be labeled automated.

The current MATLAB batch process has no interactive desktop. Keyboard order,
focus visibility, screen-reader labeling, platform/DPI appearance, perceived
layout quality, live pointer interaction, and a human source-side-by-side
review remain on [MANUAL_DESKTOP_QA.md](MANUAL_DESKTOP_QA.md). Batch
construction and screenshots are not described as human approval.
