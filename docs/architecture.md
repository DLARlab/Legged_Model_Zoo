# Architecture

Dependencies point from GUI to application services to model-independent algorithms and problem/model contracts. Persistence consumes plain data objects, while visualization consumes named simulation output. Model-specific layouts are restricted to adapters under `models/+lmzmodels`.

Manifests bind only classes in the approved `lmzmodels.*` namespace. JSON contains no executable expressions. `startup.m` adds only `src` and `models`.

The introductory path delegates GUI simulation to `AppController`, then `SimulationService`, then a `SimulationProblem` and model. Scientific paths share the same controller/service/data boundary and select a model problem/adapter at the edge:

```text
LeggedModelZooApp
  -> AppController
  -> Branch / Evaluation / Solution / Solve / Seed / Continuation services
  -> slip_quadruped.PeriodicApexProblem
     | slip_biped.PeriodicApexProblem / TrajectoryFitProblem
     | slip_quad_load.SingleStrideProblem / MultiStrideFitProblem
  -> model-specific legacy evaluator (solver-free compatibility boundary)
  -> ProblemEvaluation / SimulationResult
  -> QuadrupedRenderer and named plot providers
```

The GUI never calls model-specific evaluators or numerical algorithms directly. It dispatches through model/problem capabilities, `AppController`, branch/evaluation/simulation/solve/continuation/optimization services, and named render/plot providers. Canonical packages are `lmzmodels.slip_biped`, `lmzmodels.slip_quadruped`, and `lmzmodels.slip_quad_load`.

GUI controls call `AppController`, which owns invalidation and synchronization and delegates to services. Tab shell classes under `+lmz/+gui/+tabs` and reusable inspector/badge components reduce construction responsibilities in the main app without moving scientific logic into widgets. Dedicated solver/projector adapters own calls to `fsolve` and `fmincon`; services depend only on problem contracts. `FminconSolver` detects exact equal bounds and solves only the free subvector, then reconstructs the full schema vector for every objective/constraint call and returned artifact.

Raw indexing is centralized in `Results29Layout/Adapter`, `Results14Layout/Adapter`, and `FirstStrideLayout`/`LaterStrideLayout`/`XAccumAdapter`. Branches store decision and parameter matrices by schema with one explicit parameter column per point and per-point observables, classifications, diagnostics, feasibility, problem maturity, validation status, and source lineage. Problem descriptors, not model marketing labels, are the authority for scientific maturity and capabilities; the registry derives model-level availability from them.
