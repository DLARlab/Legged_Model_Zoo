# SLIP biped GaitMap data

This directory contains the six published `results` branch matrices used by
the source jerboa gait-map workflow. Each matrix is exactly 14-by-N: rows 1–12
are the periodic decision, and rows 13–14 are the left/right swing offsets.
The files are copied unchanged; their SHA-256 digests and point counts are in
`gaitmap_manifest.json`.

Use the native catalog from MATLAB after running `startup`:

```matlab
catalog = lmzmodels.slip_biped.GaitMapCatalog.default();
branch = catalog.loadBranch([], [], true);       % W1, native when available
solution = branch.point(catalog.recommendedSeedIndex('W1.mat'));
simulation = lmz.registry.ModelRegistry.discover() ...
    .createModel('slip_biped').simulate( ...
    lmz.api.SimulationRequest('slip_biped','periodic_apex',solution,struct()), ...
    lmz.api.RunContext.synchronous(0));
```

`loadAll` returns walking, running, hopping, two skipping branches, and
asymmetric running. `Results14Adapter.encode(branch)` recreates the original
14-row matrix exactly. Ordinary runtime and tests use only this directory;
the sibling source repository is needed only by maintainer import/capture
scripts.

Source: `DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions`,
commit `4595146c5881a5313bc8fe92de85099193ef9be9`, path
`Section2_solution_examples`. The upstream readme states CC BY-NC 4.0.
Redistribution for a public release remains subject to owner review.
