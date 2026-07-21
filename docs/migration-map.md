# Migration map

| Legacy concept | Native boundary |
|---|---|
| Quadruped 29-row `results` | `lmzmodels.slip_quadruped.Results29Adapter` |
| Legacy zero functions | namespaced model compatibility evaluators behind `lmz.api.Problem` contracts |
| Numerical solvers | `lmz.solvers.FsolveSolver` and `lmz.optimization.FminconSolver`, orchestrated by solve/optimization services |
| Continuation routines | `lmz.continuation.PseudoArclengthContinuation` coordinated by `lmz.services.ContinuationService` |
| MAT workspace variables | `lmz.io.ArtifactStore` plain `artifact` struct |
| GUI callbacks | `lmz.gui.AppController`, owned tab/components, typed presentation events, and service calls |
