# ADR 0004: Transactional GUI presentation events

- Status: accepted
- Decision date: 2026-07-19

## Context

The original workbench refreshed tabs through direct callback chains. A model
change selected a problem, loaded a scientific dataset, locked a point, and
invalidated derived results. Listening to each mutable property independently
would therefore redraw the same tab several times and expose intermediate,
incompatible state. Raw MATLAB listeners also make it difficult to prove that
closing and reopening the GUI does not retain callbacks to deleted figures.

The project supports MATLAB R2019b. The synchronization mechanism must not
depend on newer application-framework, weak-reference, or reactive-library
features, and headless controller tests must remain independent of widgets.

## Decision

`AppState` properties are observable, and `AppController` maps their changes to
validated presentation topics through `PresentationEventBus`. Multi-property
controller transitions use nested transactions. A transaction coalesces each
topic to its final payload, orders topics deterministically, and invokes each
interested subscriber once with one final-state batch.

The required topics cover model, problem, datasets, selection, working
solution, simulation, solve result, seed pair, continuation, optimization, run
state, and status. Small view/example/hover topics keep high-frequency or local
presentation changes separate. Numerical services do not depend on the bus.

Every subscription returns a `PresentationSubscription` handle. Tabs own those
tokens and delete them in an idempotent `dispose`/`delete` path. Closing the
application cancels active work, disposes all tabs, removes the application
subscription, clears figure callbacks, and then deletes the figure. Live
continuation callbacks update controller presentation state rather than
capturing a tab or figure in the numerical service.

The bus uses ordinary handle classes, cells, structs, `onCleanup`, and function
handles available in R2019b. It deliberately avoids a third-party reactive
framework and does not require newer typed-event syntax.

## Consequences

- Consumers see a consistent final snapshot and refresh at most once per
  logical transition.
- Event ordering and duplicate suppression are directly testable headlessly.
- Subscription counts make listener leaks observable in lifecycle tests.
- Tabs remain independently testable and `AppController` remains usable with no
  figure.
- Mutating `AppState` outside the controller remains a compatibility escape
  hatch for existing tests, but new application code uses controller methods so
  that transition boundaries and payloads stay explicit.
