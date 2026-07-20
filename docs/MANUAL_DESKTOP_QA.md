# Manual MATLAB desktop QA

## Round 7 environment

| Field | Recorded value |
|---|---|
| Date | 2026-07-19 |
| MATLAB | R2025b Update 5, Apple silicon |
| Operating system | macOS 26.5.2 (build 25F84), arm64 |
| Desktop session | Unavailable to the automated run (`usejava('desktop')` is false) |
| Screen resolution | Not reported because no display is attached to the run |

## Status

The human walkthrough is **blocked by display availability**. Automated
`uifigure` construction, callbacks, renderers, exports, and batch screenshots
are useful regression evidence but are not recorded as human usability
evidence. A release owner must complete the checklist below in a real MATLAB
desktop before a public desktop-usability claim is made.

## Required human walkthrough

### Shared GUI behavior

- Resize the window across common desktop sizes. Confirm that every tab remains
  usable at the documented 1100-by-700 minimum, that controls do not overlap or
  disappear, and that compact layouts recover when the window is enlarged.
- Traverse the header and every tab using only the keyboard. Confirm a logical
  focus and tab order, visible focus indication, reachable primary and cancel
  actions, and no keyboard traps.
- Enable the high-contrast palette. Confirm selected, hovered, disabled, and
  ordinary data remain distinguishable by shape or state as well as color, and
  that text and controls remain legible on every tab.
- Start each long-running operation that exposes cancellation. Confirm controls
  enter the correct busy state, the cancel or stop action remains available and
  takes precedence, and controls return to a consistent enabled state after
  success, failure, or cancellation.
- Generate representative status entries and a controlled error. Confirm the
  timestamped status history is selectable and copyable, error summaries use
  plain language, technical details can be expanded and hidden, and both status
  and error details can be copied without truncation.
- Change the palette, window placement, and recent data/output folders; close
  and reopen the app and confirm the preferences persist. Use Reset Preferences,
  reopen again, and confirm defaults are restored and no project-root path is
  persisted as a recent folder.
- Close and reopen the app repeatedly after interacting with all tabs. Confirm
  each action causes exactly one visible refresh or status response, closed
  windows receive no updates, and reopen cycles do not accumulate listeners,
  duplicate callbacks, warnings, or stale renderer/player resources.

### SLIP quadruped

- Load every built-in RoadMap branch; verify hover and click-to-lock.
- Edit and restore a solution; run physical simulation and Play/Pause/Stop.
- Record GIF/MP4/keyframes and export plots.
- Refine a solution; create adjacent and generated seeds.
- Run, pause, resume, stop, checkpoint, and resume continuation.
- Run an active-parameter homotopy and branch-family scan.

### SLIP biped

- Load every built-in GaitMap branch and select walk, run, hop, skip, and
  asymmetric-running points.
- Simulate and animate a selected point; inspect events, trajectories, force,
  energy, classification, and provenance.
- Refine a source seed, continue from adjacent points, checkpoint, and resume.
- Fit the built-in observed trajectory; inspect initial/optimized terms and
  save the native result.

### SLIP quadruped with load

- Load the built-in single-stride and transition datasets.
- Simulate the one- and two-stride decisions; inspect contact/event state,
  footfalls, trajectories, all GRF channels, tugline force, and R-squared.
- Start and cancel a fit; rerun it to completion, compare objective terms,
  simulate the optimized decision, and save/reload the result.

## Evidence template

For each model, record the MATLAB release, operating system, actual screen
resolution, exact steps performed, observed problems, and human-captured
screenshots under `docs/screenshots/<model-id>/`. Do not place automated batch
captures in the human-evidence column.
