# Migration map

| Legacy concept | Native boundary |
|---|---|
| Quadruped 29-row `results` | `lmzmodels.slip_quadruped.Results29Adapter` |
| Legacy zero functions | model-specific evaluators (not yet vendored) |
| Numerical solvers | future `lmz.solvers` implementations consuming problem contracts |
| Continuation routines | future chart-aware generic continuation engine |
| MAT workspace variables | `lmz.io.ArtifactStore` plain `artifact` struct |
| GUI callbacks | future service/controller layer |
