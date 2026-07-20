# Deprecation policy

Stable APIs are deprecated before removal. A deprecation must include a
warning identifier, replacement, migration example, first-deprecated version,
and earliest removal version in release notes.

- Stable source APIs remain available for at least one complete minor-release
  cycle and six months, whichever is longer, and are removed only in a major
  release.
- Provisional changes require release notes but not a major-version change.
- Internal APIs may change without notice.
- Deprecated model IDs remain import aliases through the following major
  release. Writers always emit the canonical ID.
- Schema-1.0 artifacts written by framework 1.x remain readable throughout
  framework 1.x. Removal of an artifact migrator is a major change.
- Catalog/schema fields are never silently reinterpreted.

Current legacy-import aliases are:

| Deprecated ID | Canonical ID |
|---|---|
| `jerboa.biped.offset` | `slip_biped` |
| `slip.quadruped.planar.v2` | `slip_quadruped` |
| `slip.quadruped.load` | `slip_quad_load` |

Deprecation warnings must be actionable and must not prevent a valid legacy
artifact from loading. New artifacts using a deprecated ID are rejected after
canonicalization identifies the replacement.
