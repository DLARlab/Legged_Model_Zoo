# Legged Model Zoo 1.0 release-candidate notes

## 1.0.0-rc.1

This release candidate freezes the initial public API and persistent-format
contract. It is numerically verified on MATLAB R2025b Update 5. It is designed
for R2019b compatibility, but no R2019b runtime execution is claimed.

Highlights:

- Semantic framework versioning through `lmz.util.Version` and root `VERSION`.
- Additive artifact provenance fields while preserving schema 1.0 and Round
  5/6 artifact readability.
- Stable/provisional/internal/legacy-import-only API classifications.
- Machine-readable, hash-checked redistribution inventory.
- Deterministic ZIP staging and verification with authorization gates.
- Reproducible MATLAB toolbox build support and a clean-install ZIP fallback.
- Six owned GUI tab components, transactional presentation events, persistent
  versioned preferences, high-contrast presentation, and leak-tested disposal.
- Per-problem `research_legacy`, `clean_generic`, and `high_contrast` graphics
  profiles, source-audited compound geometry for all three scientific models,
  source-style analysis plots, live profile switching, and profile-aware
  GIF/MP4/keyframe metadata.
- A built-in analytic hopper tutorial plus an independently registered
  external analytic plugin exercising the stable hybrid and scene contracts.
- Model-template generation, safe input boundaries, run reproduction,
  benchmarks, measured coverage policy, CI definitions, and governance files.

The closing R2025b suite passed 275/275 and all 31 public examples passed. The
18-case headless source-comparison matrix and numeric geometry gates pass, and
the clean-copy process renders all three research profiles without source
repository paths. These are geometry-tested and image-metric-tested results;
human desktop side-by-side approval remains blocked and is not claimed.
The closing coverage run also passed all 275 tests and covered 9,601/12,546
runtime statements (76.5264%) across 204 files while enforcing the existing
stable-package floors.

This is not a public release. No root project license or owner authorization
record is present. Public core and scientific packages therefore remain
blocked. Technical-validation packages are temporary, labeled
`NOT_FOR_REDISTRIBUTION`, and deleted by their tests.

No scientific equation or regression tolerance is changed. The quadruped
catalog version is corrected to match its already-versioned implementation;
artifact compatibility tests retain the Round 5/6 readers.
