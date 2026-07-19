# Architecture

Dependencies point from GUI to application services to model-independent algorithms and problem/model contracts. Persistence consumes plain data objects, while visualization consumes named simulation output. Model-specific layouts are restricted to adapters under `models/+lmzmodels`.

Manifests bind only classes in the approved `lmzmodels.*` namespace. JSON contains no executable expressions. `startup.m` adds only `src` and `models`.

The introductory path delegates GUI simulation to `AppController`, then `SimulationService`, then a `SimulationProblem` and model. The scientific RoadMap path is:

```text
LeggedModelZooApp
  -> AppController
  -> Branch / Evaluation / Solution / Solve / Seed / Continuation services
  -> slip_quadruped.PeriodicApexProblem
  -> LegacyQuadrupedEvaluator (solver-free compatibility boundary)
  -> ProblemEvaluation / SimulationResult
  -> QuadrupedRenderer and named plot providers
```

The GUI never calls model-specific evaluators or numerical algorithms directly. Canonical packages are `lmzmodels.slip_biped`, `lmzmodels.slip_quadruped`, and `lmzmodels.slip_quad_load`.

GUI controls call `AppController`, which owns invalidation and synchronization and delegates to services. Dedicated solver/projector adapters own calls to `fsolve` and `fmincon`; services depend only on problem contracts. `Results29Adapter` and `Results29Layout` alone understand the 29-row legacy layout. Branches store decision and parameter matrices by schema with one explicit parameter column per point and per-point observables, classifications, diagnostics, feasibility, and source lineage.
