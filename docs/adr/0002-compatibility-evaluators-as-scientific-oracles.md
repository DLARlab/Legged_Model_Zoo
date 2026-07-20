# ADR 0002: Preserve compatibility evaluators as scientific oracles

- Status: accepted
- Decision date: 2026-07-19

## Context

The three migrated scientific models depend on historical hybrid event,
residual, and objective behavior. Rewriting those functions into a new generic
engine during release preparation would combine architecture work with a
scientific-method change and weaken the source-equivalence evidence.

## Decision

Package-safe compatibility evaluators remain the numerical oracles behind the
validated scientific problems. Named adapters and layouts isolate their raw
arrays. Source fixtures, hashes, residual/trajectory/event comparisons, and
solver regressions protect the boundary. The generic hybrid interfaces added
in Round 7 are used by new models and are not silently substituted into these
oracles.

## Consequences

Some source-preserved code does not follow current style and is identified
separately in coverage and code-quality reports. Scientific changes require a
new explicit validation campaign and documented version migration; an
architecture cleanup alone is not sufficient justification.
