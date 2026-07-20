# ADR 0005: Explicit trusted external plugin discovery

- Status: accepted
- Decision date: 2026-07-19

## Context

The framework needs to prove that a fourth model can be installed without a
core source change. Scanning arbitrary MATLAB paths would permit unintended
class shadowing, and a JSON manifest cannot safely grant execution authority.

## Decision

Default discovery remains repository-only. External discovery requires an
explicit root containing validated `plugin.json`, code, and catalog roots.
Registration canonicalizes paths, adds exactly one code root, validates an
isolated namespace, checks that each class resolves uniquely inside that root,
and owns a reference-counted path lease. Registry creation binds catalog
metadata to each model/problem. Removing the registry releases the lease.

External implementations are trusted native MATLAB code. Declarative files do
not become executable and cannot name code outside the registered namespace
and root.

## Consequences

A reviewed plugin can be discovered, solved, continued, visualized, and removed
without modifying `src/+lmz`. Registration is intentionally explicit. This is
containment and lifecycle management, not process isolation; unreviewed plugin
code remains unsafe.
