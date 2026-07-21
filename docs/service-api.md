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

## ContactTimingService

```matlab
problem = model.createProblem('section_return_timing',configuration);
result = lmz.services.ContactTimingService().solve( ...
    problem,problem.InputSchedule,options,context);
```

The service accepts only `SectionReturnTimingProblem`. It solves explicit free
schedule coordinates while keeping `FixedInitialState` and
`FixedPhysicalParameters` bitwise unchanged. Residuals contain model-provided
contact constraints and stop-section return only; diagnostics explicitly state
`NoPeriodicityResidual=true`. Seeded multistart uses
`RunContext.RandomSeed`. The result is `ContactTimingResult`.

Timing-only solve is not a periodic-orbit solve. Use `SolveService` on a
periodic problem when symmetry-aligned state/section-coordinate closure is
required.

## Poincaré return and section transfer

`PoincareSectionRegistry` loads validated section catalogs and resolves trusted
implementations. `PoincareReturnMap.evaluate` accepts a trusted model-owned
propagator and returns `PoincareReturnResult`, including crossings, trajectory,
symmetry-aligned terminal state, periodic residual, section/stride descriptors,
and diagnostics.

Use the catalog-driven public service when the source is a model solution,
decision vector, or configured default:

```matlab
returned = lmz.services.PoincareReturnService().simulate( ...
    model,sourceSolution,struct('StartSectionId','apex', ...
    'StopSectionId','height_descending'),context);
assert(isa(returned,'lmz.poincare.PoincareReturnResult'));
```

`PoincareReturnService` resolves the registered catalog, simulates the selected
problem, applies section overrides, suppresses the initial root through the
section contract, and delegates crossing/coordinate/symmetry handling to
`PoincareReturnMap`.

Rephase a closed solution through the separate transfer operation:

```matlab
transferred = lmz.services.SectionTransferService().transfer( ...
    model,sourceSolution,'height_descending',context);
assert(isa(transferred,'lmz.data.SectionTransferResult'));
assert(transferred.PhaseInvariantObservablesPreserved);
assert(transferred.DecisionCodecRephased);
```

The result retains the source and transferred solutions, rotated simulation,
target crossing, source return, physical-orbit error, and durable lineage.
The built-in tutorial, quadruped, and biped adapters verify a fresh evaluation
of the target-configured `periodic_orbit` solution before reporting
`DecisionCodecRephased=true`. Unsupported plugin codecs retain `false` until
the model supplies a verified rephasing adapter; trajectory rotation alone is
not treated as proof that every numerical codec was rewritten. Runtime callback
handles remain trusted configuration and are never persisted.

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

## Multi-stride completion and simulation

Model builders derive from `lmz.multistride.StridePlanBuilder` and implement
`initialPlan` and `completeNext`. Calling `builder.build(request,context)`
normalizes requested counts, truncates explicitly when necessary, applies
completion/energy/failure policies, and delegates the noninteractive loop to
`StridePlanCompletionService`.

The result is `MultiStrideResult`, which may be complete, partial, failed, or
`missing_stride_specification`. It retains the authoritative `StridePlan`,
checkpoints, failure details, and energy diagnostics. The core never prompts;
`request_user` is a structured return state for a CLI or GUI caller to handle.

For completion plus an exact requested simulation, use the public service:

```matlab
request = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5,'InitialDecision',xAccum, ...
    'CompletionPolicy','predictor_corrector', ...
    'EnergyNeutralOnly',true,'FailurePolicy','return_partial');
result = lmz.services.MultiStrideSimulationService().simulate( ...
    model,request,context);
```

Callers must branch on `CompletionStatus` and `Partial` before accessing
`Simulation`. For the bundled two-stride quad-load seed, this five-stride
predictor-corrector request currently preserves two completed strides and
returns `failed` at stride 3 with
`lmz:MultiStride:TimingSeedOutsideTrustRegion`; `Simulation` is empty. A
five-stride carry-forward plan can demonstrate the exact 96-entry codec, but
its copied schedules are not validated section returns.

`NStrideSimulationProblem` is the model-facing wrapper around the same request.
`NStridePeriodicProblem`, `NStrideTransitionProblem`, and
`ContactTimingSequenceProblem` own explicit residual layouts: per-stride
contact rows plus final-only closure/target rows, or per-stride contact and
section-return rows with fixed state and physics. Their evaluators must report
`HiddenTimingSolve=false`. A complete plan or explicit timing variables are
required before an N-stride solve or optimization.

For load optimization, use `slip_quad_load/n_stride_fit` when timings are a
complete fixed input. It reports `HiddenTimingSolve=false`; extending beyond
the two measured strides also requires the explicit synthetic policy
`repeat_final_reference`. The validated `multi_stride_fit` problem is a
separate legacy-compatibility oracle and reports its preserved source timing
projection as `HiddenTimingSolve=true`.

## Data and artifact services

`DataService` reads bounded built-in JSON examples. `BranchService` owns native
and legacy branch boundaries. `ArtifactStore` owns versioned atomic MAT
persistence. `lmz.services.reproduceRun` reconstructs solve, continuation,
optimization, contact-timing, section-transfer, N-stride simulation/plan
completion, and N-stride periodic runs from compatible artifacts after version
and source-hash checks.

## Errors and toolbox availability

Public contract violations use identifiers beginning `lmz:`. Simulation,
schema, registry, artifact, scene, and analytic-hybrid operations are
toolbox-free. Generic numerical solve/continuation/optimization requires the
Optimization Toolbox. Callers should preserve an error's identifier, message,
and cause chain in diagnostics.
