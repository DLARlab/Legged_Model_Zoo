# API stability

Legged Model Zoo uses Semantic Versioning. The framework release candidate is
`1.0.0-rc.1`; prerelease status means the documented contract is being frozen,
not that public redistribution has been authorized.

## Stability classes

| Class | Promise |
|---|---|
| Stable | Backward-compatible within framework major version 1. Removal requires the deprecation process. |
| Provisional | May change in a minor release, but every change must appear in release notes with a migration example. |
| Internal | No compatibility promise. Code outside the repository must not depend on it. |
| Legacy-import-only | Retained only to read or translate historical identifiers and data. New output never uses it. |

## Stable public surface

- Entry points: `startup`, `legged_model_zoo`.
- Registry and model contracts: `lmz.registry.ModelRegistry`,
  `lmz.api.LeggedModel`, `lmz.api.BaseProblem`,
  `lmz.api.NonlinearEquationProblem`, `lmz.api.OptimizationProblem`, and
  `lmz.api.SimulationProblem`.
- Results: `lmz.api.SimulationResult`, `lmz.data.Solution`, and
  `lmz.data.SolutionBranch`.
- Persistence: `lmz.io.ArtifactStore`, artifact schema `1.0.0`, and catalog
  schema `1.0.0`.
- Services: `lmz.services.SimulationService`, `SolveService`,
  `ContinuationService`, `OptimizationService`, and `reproduceRun`.
- Execution: `lmz.api.RunContext` and its cooperative cancellation contract.
- Native hybrid authoring: `lmz.simulation.HybridSystem`, `HybridMode`,
  `HybridEvent`, `ScheduledEventPolicy`, `GuardEventPolicy`, `ResetMap`, and
  `HybridSimulator`.
- Declarative visualization: `lmz.viz.SceneSpec`, `SceneValidator`,
  `SceneRenderer2D`, `KinematicsFrame`, and `PlotPlugin`.
- Explicit external discovery through
  `lmz.registry.ModelRegistry.discoverWithPlugins` and its scoped trust
  lifecycle.
- Canonical model IDs: `slip_biped`, `slip_quadruped`, `slip_quad_load`, and
  the non-scientific `tutorial_hopper`.

Stable refers to signatures and serialized meaning, not numerical equality
across MATLAB releases. Scientific tolerance evidence is recorded separately.

## Provisional and internal surfaces

Variable-schema details, continuation extension options, the model-template
generator, and GUI widget internals remain provisional. `lmz.gui`,
`lmz.solvers`, `lmz.optimization`, model implementation classes under
`lmzmodels`, maintainer tools, and private helpers are internal unless a public
document explicitly says otherwise. The stable hybrid/scene surfaces above
are protected by the built-in and external analytic-hopper contract tests;
appearance defaults and non-documented helper methods remain internal.

Legacy evaluator packages, Results14/Results29/X_accum adapters, and deprecated
model IDs are legacy-import-only. They are not model-authoring APIs.

## Artifact compatibility

Artifacts written by framework 1.x retain `schemaVersion = 1.0.0`. New
artifacts also record `artifactSchemaVersion`, `frameworkVersion`,
`modelVersion`, `problemVersion`, and `minimumMatlabRelease`. Round 5 and Round
6 schema-1.0 artifacts remain readable. Extra fields are additive; required
field meaning and array orientation cannot change within schema 1.0.

Readers reject unknown future schema versions instead of guessing. A future
incompatible schema requires an explicit migrator and release-note entry.
Build metadata does not affect Semantic Version precedence.

## Catalog compatibility

Catalog schema 1.0 fixes manifest identity, implementation binding, problem
descriptor, maturity, provenance, validation, and capability semantics. A
reader rejects an unsupported catalog schema. JSON never contains executable
expressions.
