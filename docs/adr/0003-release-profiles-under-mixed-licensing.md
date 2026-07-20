# ADR 0003: Fail-closed release profiles under mixed licensing

- Status: accepted
- Decision date: 2026-07-19

## Context

Framework code, tutorials, migrated scientific code, source datasets, and
derived artifacts do not currently have complete owner-supplied redistribution
decisions. Repository visibility and permission to perform a local migration
are not redistribution grants.

## Decision

The release inventory records every candidate file, hash, source, decision,
notice, and derivation. `legged-model-zoo-core` and
`legged-model-zoo-scientific` are independent profiles, but both final public
builds remain blocked until every included entry is explicitly authorized. A
temporary technical-validation mode may exercise staging, deterministic ZIP,
toolbox, install, and verification mechanics; it must not leave or label a
public artifact. Scientific/full staging fails before final archive creation
when any inherited decision is unresolved.

No root `LICENSE` is synthesized. Exact owner decisions are the only mechanism
that can change a release entry from unresolved to permitted.

## Consequences

Packaging mechanics can be tested without making a legal claim. The honest
Round 7 recommendation can be an internal release candidate while public
release remains blocked. Maintainers must synchronize notices, README status,
the machine-readable inventory, and the release-candidate report after each
owner decision.
