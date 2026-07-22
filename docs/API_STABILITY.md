# API stability

Legged Model Zoo uses Semantic Versioning. The framework release candidate is
`1.0.0-rc.3`; prerelease status means the documented contract is being frozen,
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

Round 10 adds the following **provisional** public surfaces. Their serialized
meaning is documented and tested, but their signatures may still change before
the final 1.0 release:

- `lmz.shooting.SectionStateSchema`, `SectionSimulationAdapter`,
  `ShootingNode`, `ShootingSegment`,
  `ShootingHorizon`, `ShootingDecisionSchema`, `InterfaceDefect`,
  `MultipleShootingProblem`, its periodic/transition specializations,
  `ShootingResult`, `FeasibilityReport`, `ShootingInitializer`, and
  `HorizonContinuation`;
- `lmz.solvers.RankAwareNonlinearSolver` and `LsqnonlinSolver`;
- `lmz.services.ContactTimingService`, `TimingContinuationService`,
  `MultipleShootingService`, `FeasibilityAnalysisService`, and
  `HorizonContinuationService`;
- `lmz.schedule.TimingResidualPolicy`, `TimingGauge`, and
  `TimingFamilyProblem`; and
- native stride-plan, section-local codec/adapter, horizon-template, and
  shooting/horizon GUI configuration added in Rounds 9 and 10.

Round 11 adds these **provisional** public surfaces:

- `lmz.workflow.WorkflowRegistry`, `WorkflowDescriptor`, `WorkflowRunner`,
  `WorkflowSession`, `WorkflowResult`, `WorkflowStep`, `WorkflowPreset`,
  `DataSourceDescriptor`, `DataSourceProvider`, `BranchCatalogProvider`,
  `LegacyDataAdapterProvider`, `WorkbenchContribution`, `AxisPreset`,
  `SeedPreset`, and `ContinuationPreset`;
- optional model-manifest `dataSources`, `workbench`, and `workflows`
  registrations and their schema-1.0 declarative documents;
- `lmz.data.SolveIterationSnapshot`, `SolveProgress`, and
  `lmz.solvers.SolveCallbacks`; and
- the `scientific_workbench` and `classic_tabs` layout-profile IDs and their
  `AppController.setLayoutProfile`/`layoutProfileId` selection route.

GUI layout/widget classes, concrete overlay/controller implementations, and
model-owned provider implementation classes remain internal. The provisional
contracts are the inert descriptors, provider base interfaces, result values,
registered IDs, and controller selection route—not the location or handle
type of an individual widget.

Four model-owned Round 10 facades are explicit exceptions because the public
quad-load evidence examples instantiate them directly: `lmzmodels.slip_quad_load.StrideTemplateLibrary`,
`QuadLoadFeasibilityEvidence`, `QuadLoadMultipleShootingProblem`, and
`QuadLoadHorizonContinuation`. These four classes are provisional public APIs;
their signatures may change before 1.0, but any such change requires release
notes and an updated example. Other model-specific classes under `lmzmodels`,
including scientific section adapters, evaluators, codecs, and compatibility
oracles, remain internal even when a registered problem, one of these facades,
or a public service delegates to them. Their inert problem configuration,
result, and artifact payloads remain the preferred cross-version boundary.

Legacy evaluator packages, Results14/Results29/X_accum adapters, and deprecated
model IDs are legacy-import-only. They are not model-authoring APIs.

## Artifact compatibility

Artifacts written by framework 1.x, including rc.2 and rc.3, retain
`schemaVersion = 1.0.0`. New
artifacts also record `artifactSchemaVersion`, `frameworkVersion`,
`modelVersion`, `problemVersion`, and `minimumMatlabRelease`. Round 5 and Round
6 schema-1.0 artifacts remain readable. Round 9/10 timing, shooting,
feasibility, and continuation payloads and Round 11 solve-progress/workflow
metadata use additive artifact types and fields; they do not change the schema
version. Extra fields are additive; required
field meaning and array orientation cannot change within schema 1.0.

Readers reject unknown future schema versions instead of guessing. A future
incompatible schema requires an explicit migrator and release-note entry.
Build metadata does not affect Semantic Version precedence.

## Catalog compatibility

Catalog schema 1.0 fixes manifest identity, implementation binding, problem
descriptor, maturity, provenance, validation, and capability semantics. Its
Round 11 data-source, workbench, and workflow references are optional additive
fields; each referenced document also declares schema `1.0.0` and is
hash-frozen during discovery. A reader rejects an unsupported catalog schema.
JSON never contains executable expressions.
