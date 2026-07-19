# Model authoring guide

Create a package under `+lmz/+models/+your_model` with a `LeggedModel` subclass. Define named state and parameter schemas, return structured simulation results, and expose named kinematic frames. Put a manifest, `visual.json`, README, and presets in `assets/models/your_model`. The registry discovers it automatically.

Create task-specific `NonlinearProblem` classes for residuals/objectives. Keep canonicalization explicit and diagnostic. Use scheduled events with pre/post state records; a future guard-triggered simulator can implement the same result contract. Add schema round-trip, finite simulation, residual, event, and persistence tests. Generic solver, continuation, GUI, and visualization files must never gain a model-name switch.
