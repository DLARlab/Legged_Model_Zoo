# GUI layout profiles

Layout profiles choose where reusable GUI components are placed. They do not
choose a model equation, problem formulation, solver, tolerance, or data
adapter. Round 11 provides two provisional profile IDs:

| ID | User label | Intended use |
|---|---|---|
| `scientific_workbench` | Scientific workbench | Branch/data investigations where selection, solve, and continuation should share a persistent canvas. |
| `classic_tabs` | Classic tabs | The established six-tab organization and the fallback for models without a branch workbench contribution. |

Both profiles use the same controller state, services, events, component
implementations, and capability checks.

## Select in the application

1. Launch with `app = legged_model_zoo;`.
2. Choose **Scientific workbench** or **Classic tabs** from **Layout** in the
   header.
3. Continue working with the current model/problem/selection. The shell is
   rebuilt, but the controller and scientific state are retained.

The application stores the choice in `PreferencesStore`. It also stores the
scientific sidebar tab, central workspace view, and sidebar width ratio.
Invalid or obsolete stored values use safe defaults. **Reset preferences**
returns to the currently registered/default layout.

## Select programmatically

```matlab
controller = lmz.gui.AppController();
controller.setLayoutProfile('classic_tabs');
assert(strcmp(controller.layoutProfileId(), 'classic_tabs'));

ids = lmz.gui.layout.LayoutProfileRegistry.list();
scientific = lmz.gui.layout.LayoutProfileRegistry.get( ...
    'scientific_workbench');
```

The GUI classes under `lmz.gui.layout` are internal. The IDs and their
controller selection route are provisional public contracts in
`1.0.0-rc.3`.

## Automatic and workflow selection

When no explicit preference overrides it, a continuation-capable model with
registered branch data can use `scientific_workbench`; the clean fallback is
`classic_tabs`. A registered workflow may declare `layoutProfileId`, and
selecting that workflow updates the controller layout state. The layout menu
remains available so the user can compare or return to classic tabs.

The quadruped workflows `roadmap_explore`, `roadmap_root_continuation`, and
`touchdown_root_continuation` declare `scientific_workbench`. A minimal model
or external plugin can omit workbench and workflow resources entirely; it then
receives a generic contribution and `classic_tabs` without core edits.

## Model contribution

Add an optional `workbench.lmz.json` and reference it from the model manifest:

```json
{
  "schemaVersion": "1.0.0",
  "id": "scientific_workbench",
  "label": "My model scientific workbench",
  "layoutProfileId": "scientific_workbench",
  "centralViews": ["branch_state", "run_overlay"],
  "sidebarPanels": [
    "info_selection",
    "visualization",
    "solve_seeds",
    "continuation"
  ],
  "axisPresets": [
    {
      "id": "reference_branch",
      "label": "Reference branch",
      "x": "speed",
      "y": "height",
      "z": "period",
      "dimension": "2-D",
      "azimuth": 0,
      "elevation": 90
    }
  ]
}
```

The contribution can also declare parameter filters, analysis plugin IDs,
direction labels, and default solve/continuation options. It cannot declare
executable callbacks. Axis coordinate names must exist in the loaded branch;
problem capabilities remain authoritative for enabled panels.

A workflow that uses the contribution names its `axisPresetId` and
`layoutProfileId`. Registry construction rejects unknown profiles or presets.
See [registered-workflows.md](registered-workflows.md) for the complete
registration sequence.

## Layout invariants

`scientific_workbench` retains the branch canvas while sidebar tasks switch,
keeps status/progress visible, provides scrollable dense panels, and expands at
larger window sizes. Its preferred size is `1120 x 740`, minimum content size
is `880 x 570`, and nominal left/right weight is `3.35:1.85`; the application
minimum window is `900 x 650`.

`classic_tabs` retains the top-level Simulation, Branches/Data, Solution,
Solve, Continuation, and Optimization components plus the status dock. It is a
non-regression profile, not a deprecated compatibility shim.

Profile switching must dispose the previous hosts and their subscriptions.
Scientific state and datasets live in `AppController`/`AppState`, not in the
layout object, so a placement change does not recompute a branch or change a
root.

## Verification boundary

Automated tests cover profile discovery, preference round trip, classic
fallback, component lifecycle/subscription count, scientific hierarchy,
persistent branch axes, scrollability, clipping checks at `900 x 650` and
`1120 x 740`, and expansion at `1460 x 900` and `1920 x 1080`.

These batch checks do not replace the human desktop checklist. See
[scientific-workbench-layout.md](scientific-workbench-layout.md) and
[MANUAL_DESKTOP_QA.md](MANUAL_DESKTOP_QA.md).
