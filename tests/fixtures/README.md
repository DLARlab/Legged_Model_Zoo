# Regression fixture inputs

Historical fixture extraction is maintainer-only and isolated under
`tools/maintainers/`. Normal tests and built-in demonstrations do not require
sibling repositories.

Repository-contained numerical baselines are now available for all three
scientific models:

- `slip_quadruped_roadmap_baseline.mat`: three RoadMap points with residual,
  duplicate-time trajectory, events, 12 GRF channels, and gait metadata;
- `baselines/slip_biped/source_equivalence.mat`: all six representative gait
  branches plus trajectory-fit objective/constraint evidence;
- `baselines/slip_quad_load/source_baselines.mat`: one- and two-stride
  residual, trajectory, events, GRFs, tugline, per-stride parameters,
  objective terms, and R-squared evidence.

Each fixture stores measured absolute/relative tolerances and source
repository/commit/data hashes. Capture scripts require an explicit immutable
source path and are never called by ordinary tests. Updating a fixture is a
maintainer operation that must re-verify source cleanliness, copied-asset
hashes, dimensions, and the corresponding scientific tests.
