# Testing a model

## Fast generated-model smoke test

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(), 'tools'));
root = fullfile(tempdir, 'example_hopper_plugin');
mkdir(root);
new_model('example_hopper', root);
registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
    root, 'IncludeBuiltIns', false);
results = runtests(fullfile(root, 'tests', 'generated'), ...
    'IncludeSubfolders', true);
assert(~any([results.Failed]));
```

## Contract checklist

1. Discover only after explicit trust registration; verify removal releases the
   path and a fresh default registry does not list the model.
2. Compare implementation identity/version and capabilities with the catalog.
3. Test exact state/parameter/decision schema names, order, defaults, bounds,
   scale, topology, and activity.
4. Run the default simulation; verify increasing time, state dimensions,
   finite values, named outputs, modes, and event/reset records.
5. For a nonlinear problem, perturb a seed and use `SolveService`; test the
   residual and termination. For an advertised continuation capability, run a
   short exact/validated seed pair.
6. For optimization, verify the initial/final objective and each named term;
   retain the complete public decision vector.
7. Save/load solution and run artifacts; verify identity, schemas, values,
   options, source hashes, and lineage.
8. Construct a hidden generic scene, update at least 100 frames, and verify
   graphics-handle count and cleanup.
9. Test malformed JSON/MAT, path traversal, wrong dimensions, stale hashes,
   untrusted implementation roots, handles/objects, and bounded allocation.
10. Run the full repository suite to protect all scientific oracles.

## Repository test commands

```matlab
startup;
focused = runtests({'tests/extensibility','tests/security', ...
    'tests/unit/TestHybridSimulator.m','tests/unit/TestSceneContracts.m', ...
    'tests/gui/TestGenericSceneRenderer.m'}, 'IncludeSubfolders', true);
assert(~any([focused.Failed]));
assert(~any([focused.Incomplete]));

allResults = run_tests;
assert(~any([allResults.Failed]));
assert(~any([allResults.Incomplete]));
```

The authoritative external proof is `TestExternalAnalyticPlugin`: it copies an
inactive fixture to a temporary root, discovers it without core changes,
simulates scheduled hybrid modes, solves, continues, renders, round-trips an
artifact, removes the registration, and confirms clean disappearance.

## Scientific evidence

An analytic plugin test establishes framework extensibility, not scientific
validity. A migrated research problem additionally needs immutable source
provenance, copied-data hashes, explicit tolerances, independent baseline
capture, and source-equivalence tests. Never replace those tests with template
smoke coverage.
