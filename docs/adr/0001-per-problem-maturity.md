# ADR 0001: Maturity belongs to each problem

- Status: accepted
- Decision date: 2026-07-19

## Context

A model can expose an analytic tutorial, a source-equivalent scientific
problem, and an experimental optimization at the same time. A single maturity
label on the model would either overstate the weak problem or hide the evidence
for the strong one.

## Decision

Catalog problem descriptors carry `maturity`, `validationStatus`, provenance,
and per-problem capabilities. Registry and GUI summaries derive claims from the
selected problem. Supported maturity values are tutorial, compatibility,
validated, and experimental; validation status is separate.

## Consequences

Documentation and artifacts can describe evidence without promoting every
problem equally. Adding a problem requires an explicit maturity decision and
tests. Model-level capabilities are an aggregate convenience, not scientific
validation evidence.
