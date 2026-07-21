# Multi-stride planning

Multi-stride execution starts with an explicit `StridePlan`. The plan records
the requested and completed counts, initial state, physical parameters,
per-stride schedules and controls, completion policy, energy policy, failure
policy, and provenance. Missing data is handled by policy; core code never
prompts.

## Native objects

| Object | Purpose |
| --- | --- |
| `StrideSpec` | One stride's sections/sides, schedule, physical/control parameters, overrides, completion status, diagnostics, and lineage |
| `StridePlan` | Appendable authoritative plan with requested/completed counts and policies |
| `MultiStrideRequest` | Validated user request, safety limit, input plan/vector, overrides, declared work, and runtime provider callback |
| `StridePlanBuilder` | Model-specific initial-plan and one-step completion contract |
| `StridePlanCompletionService` | Noninteractive loop, checkpoints, partial failure, and progress |
| `MultiStrideResult` | Completed or partial plan, simulation, checkpoints, failure, legacy vector, and energy diagnostics |

`StridePlanValidator` checks sequential indices, completed/requested counts,
section continuity, finite data, physical-parameter invariance, and policy
consistency.

## Missing-stride policies

`MissingStridePolicy.values()` returns:

| Policy | Behavior |
| --- | --- |
| `error_if_missing` | Fail at the first absent stride |
| `carry_forward` | Copy the last schedule/controls through the model builder |
| `carry_forward_and_solve_timings` | Carry values, then require an explicit model timing corrector |
| `predictor_corrector` | Form a schema-aware secant seed (or recorded carry-forward seed when the chart/prediction is invalid), then require model timing correction before simulation |
| `request_user` | Return `missing_stride_specification` and the missing index; never open UI |
| `provider_callback` | Invoke an explicitly supplied trusted runtime callback; return missing status when absent |

`FailurePolicy='return_partial'` preserves completed strides and failure
diagnostics. `FailurePolicy='error'` rethrows. Neither policy invents data.

## Energy and parameter transition rules

Parameter metadata has two independent dimensions:

```text
Role:         physical | control | schedule | derived
EnergyEffect: invariant | state_dependent | work_input | unknown
```

The conservative transition rules are:

- physical parameters are copied exactly by default;
- schedule variables may change through a named completion/timing policy;
- control changes require a model-specific energy evaluation;
- `unknown` energy effect is rejected; and
- stiffness/rest-length changes are `state_dependent` unless proven otherwise.

For transition state `x`, parameters before/after, and declared work `W`, the
energy-neutral contract is

\[
\left|E(x,p^+)-E(x,p^-)-W\right|\leq\varepsilon_E.
\]

`EnergyConsistencyPolicy` IDs are:

| ID | Contract |
| --- | --- |
| `energy_neutral_only` | Default; with zero declared work, mismatch must be within tolerance |
| `declared_work` | A nonzero change is allowed only when it matches explicit declared work within tolerance |
| `allow_non_neutral` | Explicit opt-out; incompatible with `EnergyNeutralOnly=true` |

All policies still reject an unknown energy effect. Diagnostics record policy,
energy delta, declared work, mismatch, tolerance, known-effect flag, and
acceptance.

```matlab
startup;
policy = lmz.multistride.EnergyConsistencyPolicy( ...
    'Id','declared_work','Tolerance',1e-8);
diagnostics = policy.assess(0.25,0.25,true);
assert(diagnostics.Accepted);
```

## Demonstrate the five-stride quad-load layout

`XAccumPlanAdapter` is the sole bridge between the source layout and native
plans. The exact length remains `44 + 13*(N-1)`; every later block contains
nine event times and four post-swing stiffnesses.

```matlab
catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset = catalog.load(catalog.Manifest.defaultMultiStride);
layoutRequest = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5, ...
    'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','carry_forward', ...
    'EnergyPolicy',lmz.multistride.EnergyConsistencyPolicy(), ...
    'EnergyNeutralOnly',true, ...
    'FailurePolicy','error', ...
    'StartSectionId','apex', ...
    'StopSectionId','apex', ...
    'MaximumStrides',20);
context = lmz.api.RunContext.synchronous(901);
layout = lmzmodels.slip_quad_load.QuadLoadStridePlanBuilder().build( ...
    layoutRequest,context);
xAccum = lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(layout.Plan);
assert(layout.CompletedStrideCount == 5);
assert(numel(xAccum) == 44 + 13*(5-1));
```

For each new quad-load stride the builder carries transition-invariant physical
parameters exactly, maps the previous terminal state into source-local form,
uses previous post-swing stiffness as the next pre-swing stiffness, applies an
explicit post-swing override if present, predicts the schedule, and validates
the parameter/energy transition. With `carry_forward`, the extra event
schedules are copied. The five-stride object above proves plan construction and
codec shape only; it does not prove contact equations or an apex return.

The round trip remains exact:

```matlab
decoded = lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan(xAccum);
roundTrip = lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(decoded);
assert(isequaln(xAccum,roundTrip));
```

## Attempt timing-corrected completion

Plan-layout completion and timing feasibility are separate. The service's
`predictor_corrector` path refuses to manufacture a short-horizon schedule
when correction starts outside its validated trust region. The bundled
two-stride load seed currently returns an honest partial failure at stride 3:

```matlab
model = lmz.registry.ModelRegistry.discover().createModel('slip_quad_load');
correctedRequest = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5,'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','predictor_corrector', ...
    'EnergyNeutralOnly',true,'FailurePolicy','return_partial', ...
    'StartSectionId','apex','StopSectionId','apex');
corrected = lmz.services.MultiStrideSimulationService().simulate( ...
    model,correctedRequest,context);
assert(corrected.Partial && corrected.CompletedStrideCount == 2);
assert(strcmp(corrected.CompletionStatus,'failed'));
assert(isempty(corrected.Simulation));
assert(corrected.Failure.StrideIndex == 3);
assert(strcmp(corrected.Failure.Identifier, ...
    'lmz:MultiStride:TimingSeedOutsideTrustRegion'));
```

The failure preserves the two completed measured strides, requested count,
failed stride, identifier/message, and checkpoints. It is the expected safe
outcome until a physically valid third-stride schedule or a better seed is
provided; it is not reported as five-stride simulation support.

## N-stride problem forms

- `NStrideSimulationProblem` wraps `MultiStrideRequest` and simulates exactly
  the completed request.
- `ContactTimingSequenceProblem` fixes the initial state and physical
  parameters and exposes contact/section rows for every stride without state
  periodicity.
- `NStridePeriodicProblem` exposes every contact row and applies section
  closure only after the final stride.
- `NStrideTransitionProblem` replaces closure with one explicit final target.

An objective must receive a complete plan and either include timing variables
explicitly or hold verified precompleted timings fixed. The bundled load data
contains measurements for two strides. An extended fit must explicitly name a
reference-extension policy, remains experimental, and must not label repeated
reference data as measured or source-equivalent.

## Override a control safely

A changed post-swing stiffness requires the activation state and an energy
decision. Pass overrides by stride and declared work explicitly:

```matlab
overrides = struct('stride3',struct( ...
    'PostSwingStiffness',[20;20;20;20]));
request = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',3, 'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','carry_forward', ...
    'ParameterOverrides',overrides, 'DeclaredWork',[0;0;0], ...
    'EnergyPolicy','energy_neutral_only', 'EnergyNeutralOnly',true);
```

The model builder must receive a physically meaningful transition state before
accepting a changed stiffness. If the stored potential-energy change is not
balanced by declared work, completion fails or returns a partial result. Do not
label the change neutral merely because the continuous state vector is copied.

## Explicit truncation

When fewer strides are requested than supplied, `StridePlanBuilder.build`
calls `StridePlan.truncate` and records provenance. For source vectors, use the
adapter's explicit boundary:

```matlab
[shortVector,truncateDiagnostics] = ...
    lmzmodels.slip_quad_load.XAccumPlanAdapter.truncate(dataset.XAccum,1);
assert(numel(shortVector) == 44);
assert(truncateDiagnostics.ExplicitTruncation);
```

Never silently ignore later blocks.

## Partial completion and checkpoints

`StridePlanCompletionService` creates a plain checkpoint after every appended
stride. A `CheckpointFcn` may persist that plain struct when supplied as
trusted runtime configuration. With `return_partial`, `MultiStrideResult`
retains the last valid plan, failed stride index, identifier/message,
checkpoints, and energy diagnostics. Resume from the validated plan rather than
rerunning completed transitions.

Runtime callbacks (`ProviderCallback`, `CheckpointFcn`, timing correctors) are
not serialized. Artifacts record only whether a callback was configured plus
plain outputs and provenance.

## No prompts in core code

`request_user` is a data-state policy name, not permission to call `input`,
`questdlg`, `uigetfile`, or any GUI function. The completion service returns:

```text
CompletionStatus = missing_stride_specification
MissingStrideIndex
RequestedStrideCount
CompletedStrideCount
Policy
```

A CLI caller can provide another plan/request. The desktop GUI can open its
stride editor and submit explicit values. The scientific core stays
deterministic, headless, cancellable, and testable.

## Optimization boundary

Complete and validate the plan before optimization. Timing variables must be
either explicit decision variables/constraints or pre-completed and fixed.
The Round 9 load problem `n_stride_fit` uses the fixed supplied schedule and
reports `HiddenTimingSolve=false`. A three-stride decision has 70 entries:

```matlab
two = model.createProblem('n_stride_fit',struct());
x3 = [two.SourceDecision; two.SourceDecision(end-12:end)];
fit3 = model.createProblem('n_stride_fit',struct( ...
    'InitialDecision',x3,'NumberOfStrides',3, ...
    'ReferenceExtensionPolicy','repeat_final_reference'));
```

`repeat_final_reference` is a declared synthetic reference policy, not a claim
that the repository contains a measured third stride. The older
`multi_stride_fit` problem remains a separately named, exact two-stride legacy
oracle; it preserves the source timing projection and honestly reports
`HiddenTimingSolve=true`. A new bilevel formulation would need its own name and
validation evidence.

The default two-stride `n_stride_fit` seed is a hash-bound, repository-captured
fixed-timing vector and exposes 18 nonlinear contact/section equalities. The
repeated three-stride vector above exposes 27 equalities and demonstrates the
generalized schema only; it is not a validated third-stride timing seed and
must not be used to claim a successful three-stride fit.

## What to persist

Persist the plan and result's plain representations: section IDs/sides,
schedules, fixed/free masks, per-stride parameters, overrides, completion and
energy policies, diagnostics, checkpoint list, partial/failure status,
requested/completed counts, and source hashes. Never persist executable
callbacks. See [data-format.md](data-format.md).
