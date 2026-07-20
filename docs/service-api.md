# Service API

Services orchestrate public operations without embedding model equations or UI
widgets. Pass a `RunContext` to every long-running operation.

## RunContext

```matlab
context = lmz.api.RunContext.synchronous(42);
context.ProgressFcn = @(fraction,message) fprintf('%3.0f%% %s\n', ...
    100*fraction, message);
```

`check` cooperatively honors cancellation and pause. `progress`, `log`, and
`checkpoint` call trusted in-process callbacks. Those callbacks are runtime
configuration and must never be deserialized from JSON or MAT data.

## SimulationService

```matlab
result = lmz.services.SimulationService().simulate( ...
    simulationProblem, solution, options, context);
```

The problem must be `SimulationProblem`; the model must advertise simulation;
the result must be `SimulationResult` with strictly increasing time and states
matching its physical schema.

## SolveService

```matlab
result = lmz.services.SolveService().solve( ...
    nonlinearProblem, seed, solverOptions, context);
```

An already valid seed may be accepted without movement. Otherwise the solver
adapter calls `fsolve`. The service returns `SolveResult` containing the solved
solution, final evaluation, exit flag/output, exact options, seed, seed value,
and provenance.

## Seed and continuation services

`SeedService` validates adjacent branch pairs, applies explicit projection or
noise, and can construct a corrected second seed. Continue with:

```matlab
result = lmz.services.ContinuationService().run( ...
    nonlinearProblem, solutionPair, continuationOptions, context);
```

Continuation records accepted/rejected snapshots, checkpoints, step/curvature
diagnostics, controlled-stop state, and a normalized termination reason.
Parameter homotopy accepts active schema parameters only.

## OptimizationService

```matlab
result = lmz.services.OptimizationService().run( ...
    optimizationProblem, seed, options, context);
```

Exact equal bounds are removed from the numerical subproblem and restored in
the full public decision vector. Objective terms, diagnostics, free/fixed
indices, options, termination, and source lineage remain in `OptimizationResult`.

## Data and artifact services

`DataService` reads bounded built-in JSON examples. `BranchService` owns native
and legacy branch boundaries. `ArtifactStore` owns versioned atomic MAT
persistence. `lmz.services.reproduceRun` reconstructs solve, continuation, or
optimization runs from compatible run artifacts and verified source hashes.

## Errors and toolbox availability

Public contract violations use identifiers beginning `lmz:`. Simulation,
schema, registry, artifact, scene, and analytic-hybrid operations are
toolbox-free. Generic numerical solve/continuation/optimization requires the
Optimization Toolbox. Callers should preserve an error's identifier, message,
and cause chain in diagnostics.
