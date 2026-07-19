# Native data format

`Solution` owns model/problem identity, ordered schemas, decision/parameter values, residual blocks, diagnostics, feasibility, lineage, provenance, and creation time. `SolutionBranch` stores decision and parameter values as `nVariable`-by-`nPoint` matrices; constant parameters are repeated per point. Public access is named and point-oriented.

Native MAT files contain one top-level plain struct named `artifact`. Current artifact types include solution, branch, solve-run, continuation-run, optimization-run, simulation, checkpoint, and branch-family-report. `ArtifactStore` validates common schema/dimension/finite-value metadata and saves atomically.
