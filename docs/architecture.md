# Architecture

Dependencies point from GUI to application services to model-independent algorithms and problem/model contracts. Persistence consumes plain data objects, while visualization consumes named simulation output. Model-specific layouts are restricted to adapters under `models/+lmzmodels`.

Manifests bind only classes in the approved `lmzmodels.*` namespace. JSON contains no executable expressions. `startup.m` adds only `src` and `models`.

The GUI delegates simulation to `AppController`, then `SimulationService`, then a `SimulationProblem` and model. It never calls model-specific evaluators or numerical algorithms directly. Canonical packages are `lmzmodels.slip_biped`, `lmzmodels.slip_quadruped`, and `lmzmodels.slip_quad_load`.
