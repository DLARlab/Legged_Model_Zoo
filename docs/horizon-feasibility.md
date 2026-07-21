# Horizon feasibility and evidence

Horizon feasibility is a physical and numerical classification of one
configured multiple-shooting problem. It is not a claim about every possible
seed, control bound, section choice, or model parameter. Unless a rigorous
certificate is available, failed local searches are never described as proof
of global nonexistence.

## Classification vocabulary

`FeasibilityReport.Classification` uses this exact vocabulary:

| Classification | Meaning |
| --- | --- |
| `root_found` | A square configured system met residual tolerance, physical validation, and acceptable solver termination. Inspect rank/nullity before claiming the root is isolated. |
| `least_squares_feasible` | A rectangular configured system met every active residual tolerance and physical condition with acceptable termination. This is stronger than merely reaching a least-squares stationary point. |
| `best_known_residual` | The best recorded candidate still violates a configured condition or tolerance. It is local evidence, not an infeasibility proof. |
| `local_infeasibility_evidence` | A bounded, explicitly described local search or rank/constraint analysis found no accepted candidate. Scope and search domain must accompany the claim. |
| `numerical_failure` | The solver did not terminate acceptably; no physical existence conclusion follows. |
| `physical_validation_failure` | Numerical output exists, but a non-residual physical condition such as crossing acceptance, event order, or finite-state validation failed. An otherwise physical candidate whose active residual or energy/work equation remains above tolerance is `best_known_residual`. |

Avoid using the bare word “infeasible” in reports. State the classification,
problem configuration, solver, bounds, seeds, tolerance, and whether a global
certificate exists. The supplied multistart service always reports
`GlobalInfeasibilityProven=false`.

## What success checks

A successful shooting result requires all of the following:

```text
acceptable solver termination
maximum scaled active residual <= configured tolerance
finite terminal state for every segment
accepted nongrazing section crossing for every required segment
valid event order and minimum gaps
valid physical conditions from every model adapter
valid active energy/work constraints
```

The report preserves residual and decision dimensions, Jacobian rank/nullity,
singular values, condition estimate, active bounds, first-order optimality,
named unscaled residual blocks, termination reason, qualifications, and
provenance. A low residual paired with a failed physical condition is
`physical_validation_failure`, not success.

## Analyze one candidate

Use `FeasibilityAnalysisService.analyze` when the goal is to characterize a
specified decision without presenting it as a solver-discovered root:

```matlab
parameters = problem.getParameterSchema().defaults();
decision = problem.ShootingSchema.defaults();
context = lmz.api.RunContext.synchronous(44);
report = lmz.services.FeasibilityAnalysisService().analyze( ...
    problem,decision,parameters,struct('ResidualTolerance',1e-7),context);

fprintf('class=%s residual=%.3g rank=%d nullity=%d\n', ...
    report.Classification,report.ScaledResidualNorm, ...
    report.JacobianRank,report.Nullity);
```

An already valid candidate may receive a successful classification because its
residual and physical contract were directly verified. A failed analysis is
recorded as `best_known_residual` with termination reason
`analysis-only-no-existence-certificate`.

## Reproducible multistart evidence

`FeasibilityAnalysisService.multistart` accepts an explicit cell array of
seeds. It records each exit flag, score, report, or caught error and returns the
lowest residual candidate:

```matlab
evidence = lmz.services.FeasibilityAnalysisService().multistart( ...
    problem,seeds,parameters,struct('Solver','lsqnonlin', ...
    'ResidualTolerance',1e-7),context);
assert(~evidence.GlobalInfeasibilityProven);
```

Every attempt retains its exact inert input seed and hash, derivation label,
random seed, exit/termination data, score, final decision when available, and
feasibility report when evaluation is reached. Aggregate metadata binds the
exact parameters, solver options, and problem configuration by hash. A
score-only list is not
reproducible search evidence. Report the distribution of residuals and
termination reasons, not only the best value. Repeated local failure may justify
`local_infeasibility_evidence` over the stated bounds; it still does not prove
global nonexistence. Local numerical failure does not prove global nonexistence.
An attempt rejected before evaluation retains its exception identifier and
message instead of inventing a feasibility report.

## Solve a horizon

`MultipleShootingService.solve(problem,seed,options,context)` performs the
rank-aware solve, re-evaluates the physical trajectory, and returns a
`ShootingResult` with a `FeasibilityReport`. Do not access a supposed complete
simulation based only on `ExitFlag`; branch on `FeasibilityReport.Success`.

```matlab
result = lmz.services.MultipleShootingService().solve( ...
    problem,seed,struct('Solver','auto', ...
    'ResidualTolerance',1e-7),context);
if result.FeasibilityReport.Success
    segmentResults = result.SegmentResults;
else
    evidence = result.FeasibilityReport.toStruct();
end
```

An unsuccessful `ShootingResult` retains the evaluated segment results and the
first failing physical facts. It must not be replaced by a synthetic
carry-forward trajectory.

## Continue from `N` to `N+1`

The public continuation service takes an explicit list of configurations. Each
configuration must create a registered `MultipleShootingProblem`:

```matlab
configurations = { ...
    struct('HorizonLength',1,'Formulation','periodic'), ...
    struct('HorizonLength',2,'Formulation','periodic')};
first = model.createProblem('multiple_shooting',configurations{1});
seed = first.ShootingSchema.defaults();
options = struct('SolverOptions',struct('Solver','auto', ...
    'ResidualTolerance',1e-8), ...
    'ContinueOnQualifiedFailure',false);
result = lmz.services.HorizonContinuationService().run( ...
    model,'multiple_shooting',configurations,seed,options,context);
```

After the first step, `HorizonContinuation.embedDecision` maps retained values
by decision name and initializes only added names from the new schema. Each
larger step then uses an anchored homotopy: at `lambda=0` the embedded decision
is an exact anchor, while at `lambda=1` the residual is exactly the complete
new-horizon residual. The adaptive trace grows successful steps, reduces and
retries rejected steps, and records every attempt's lambda interval, rank,
nullity, condition estimate, residual, termination reason, and accepted
checkpoint. Intermediate-lambda points are never classified as physical
horizon solutions.

Each history entry records old/new dimension, mapped/added/removed names,
source and solved decisions, segment count, configuration, homotopy trace, and
feasibility report. If the trace cannot reach `lambda=1`, the service stops by
default and preserves the strongest previously completed physical result; it
does not synthesize the requested longer simulation. `UseAdaptiveHomotopy=false`
is an explicit diagnostic opt-out, not the default continuation protocol.

## Checkpoint and resume

The low-level `HorizonContinuation.checkpoint` stores a plain problem contract,
its SHA-256 hash, decision, segment count, history, status, framework version,
and timestamp. `resume` validates the framework compatibility, exact problem
contract and contract hash, decision schema, and segment dimension before it
restores the decision and history. A same-size problem with different physical
parameters is therefore rejected. To change dimension, resume the original
problem first and then call `embedDecision` explicitly.

Adaptive homotopy also emits inert checkpoints. Each one binds the full target
problem contract and the exact anchor decision, and records the accepted
lambda, decision, next step, attempt history, residual, and status. Continue an
interrupted adaptive step with:

```matlab
trace = lmz.services.HorizonContinuationService().resumeHomotopy( ...
    model,problemId,targetConfiguration,anchor,checkpoint, ...
    homotopyOptions,context);
```

Resume rejects a changed problem, anchor, future or incompatible framework,
out-of-policy next step, malformed decision, and recomputed or stale hash. It
continues the recorded attempt numbering and may only report a completed
physical target after reaching `lambda=1` and satisfying the normal shooting
feasibility contract.

`HorizonContinuationService.toArtifact` stores the complete configuration
protocol and embedding history. `lmz.services.reproduceRun` verifies the
hash-bound final horizon and reconstructed shooting problem contract for
`horizon-continuation-run` artifacts.

## Reporting checklist

For a successful or unsuccessful physical horizon, report:

1. model/problem IDs, sections and sides, horizon length, and source hashes;
2. free/fixed interface, schedule, control, physical, target, and gauge masks;
3. solver/algorithm, bounds, tolerances, random seed, and initializer history;
4. per-segment contact, section, interface, and energy/work residuals;
5. crossing acceptance, event order, finite-state, and energy/work status;
6. residual/decision dimensions, rank/nullity, singular values, condition
   estimate, active bounds, and first-order optimality;
7. exact classification and termination reason; and
8. the explicit scope of any local nonexistence evidence.

Related guides:

- [Multiple shooting](multiple-shooting.md)
- [Contact-timing solve](contact-timing-solve.md)
- [Multi-stride planning](multi-stride-planning.md)
