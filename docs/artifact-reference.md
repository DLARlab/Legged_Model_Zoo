# Artifact reference

Legged Model Zoo artifacts are MAT files containing exactly one top-level
plain struct named `artifact`. Save and load them with `lmz.io.ArtifactStore`.

```matlab
artifact = solution.toArtifact();
lmz.io.ArtifactStore.save('candidate.lmz.mat', artifact);
restored = lmz.io.ArtifactStore.load('candidate.lmz.mat');
solution = lmz.data.Solution.fromArtifact(restored);
```

## Common identity and version fields

Every artifact records `schemaVersion`, `artifactSchemaVersion`,
`frameworkVersion`, `minimumMatlabRelease`, `artifactType`, `modelId`,
`modelVersion`, `problemId`, and `problemVersion`. It also records ordered
decision/parameter schemas and values, diagnostics, lineage, source commits,
creation/MATLAB/code versions, and random seed. New artifacts use canonical
model IDs.

Supported artifact types are `solution`, `branch`, `simulation`, `solve-run`,
`continuation-run`, `optimization-run`, `checkpoint`, and
`branch-family-report`. Type-specific payloads retain the public data object;
checkpoint artifacts additionally include checkpoint state, algorithm options,
and termination reason.

## Scientific maturity and provenance

When available, `problemMaturity`, `validationStatus`, and `problemMetadata`
must agree. Source artifacts and run results retain source hashes/commits and
configuration. Derived native artifacts inherit the source material's
redistribution status; native conversion does not create new permission.

## Run reproducibility

Solve, continuation, and optimization artifacts record options, source seed or
pair, source artifact identity, source-data hashes, MATLAB release/toolboxes,
elapsed time, function evaluations, termination reason, and warnings.

```matlab
[newResult, report] = lmz.services.reproduceRun('solve-run.lmz.mat');
```

`reproduceRun` verifies framework/model/problem compatibility and available
built-in hashes, reconstructs the options and lineage exactly, and reruns the
public service. Numerical equality uses the documented solver/platform
tolerances.

## Compatibility and trust

The 1.x compatibility policy is documented in `docs/API_STABILITY.md`.
Unsupported future schemas fail before dispatch. Artifact MAT files are input,
not executable configuration: only a plain bounded data graph is allowed, no
function handles or model objects. Do not load arbitrary MAT files outside the
safe project loaders merely to inspect them.
