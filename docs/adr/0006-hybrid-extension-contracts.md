# ADR 0006: Native generic hybrid extension contracts

- Status: accepted
- Decision date: 2026-07-19

## Context

New models need a reusable event/reset simulation path, but rerouting validated
scientific migrations through a new engine would risk changing their numerical
oracles.

## Decision

`HybridSystem`, modes, scheduled/guard policies, events, reset maps, and
`HybridSimulator` form a new stable extension boundary. The simulator owns ODE
integration, RunContext cancellation, deterministic simultaneous-event order,
mode history, named outputs, and standardized pre/post event records. Duplicate
event time is represented once publicly using the final post-state.

The external analytic hopper exercises the new boundary. Existing scientific
biped, quadruped, and load evaluators remain unchanged compatibility oracles.

## Consequences

Authors can implement native hybrid systems without writing orchestration or
event-record plumbing. Compatibility evidence remains stable. Guard callbacks
are trusted code and cannot originate in declarative configuration.
