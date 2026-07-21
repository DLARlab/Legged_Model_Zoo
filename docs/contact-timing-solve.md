# Contact-timing solve

Contact timing is an explicit section-return solve with a fixed initial state
and fixed physical parameters. It adjusts selected event times and optionally
the return time. It is not a periodic-orbit solve.

## Contract at a glance

| Timing-only solve | Periodic-orbit solve |
| --- | --- |
| Unknowns are free schedule coordinates | Unknowns may include initial state, schedule, controls, and continuation-family directions |
| Initial state is bitwise unchanged | Initial-state variables may change |
| Physical parameters are bitwise unchanged | Parameters change only when the problem explicitly includes them |
| Residuals are contact consistency plus stop-section return | Residuals include symmetry-aligned state/section-coordinate closure |
| Does not require `x(T)=x0` | Enforces periodic closure after the selected return |
| Uses `ContactTimingService` with rank-aware solver routing | Uses `SolveService` or `MultipleShootingService` on a periodic problem |

The built-in source-compatible apex blocks are eight contact equations plus one
section equation for quadruped and quad-load, and four contact equations plus
one section equation for biped. Periodicity rows are deliberately absent.

## Schedule representation

`EventOccurrence` names one event, its time, fixed flag, and plain metadata.
`EventSchedule` stores occurrences in strict chronological order, a positive
return time, a minimum gap, fixed/free masks, and start/stop section IDs.
`EventScheduleChart` encodes only free entries into unconstrained coordinates
while preserving event order and positive gaps.

Construct a simple cyclic schedule as follows:

```matlab
startup;
names = {'touchdown','liftoff'};
schedule = lmz.schedule.EventSchedule.fromCyclic( ...
    names,[0.2;0.6],1.0, 'FixedMask',[false;true], ...
    'ReturnTimeFixed',false, 'MinimumGap',1e-4, ...
    'StartSectionId','apex', 'StopSectionId','apex');
assert(isequal(schedule.freeMask(),[true;false]));
times = schedule.times();
assert(schedule.ReturnTime > times(end));
```

## Configure a built-in timing problem

Every supported model exposes `section_return_timing` through
`Model.createProblem`, but the timing provider—not the mere presence of a
catalog section—defines which start/stop pairs are supported. Configuration
fields are:

| Field | Meaning |
| --- | --- |
| `InitialState` | Fixed state vector; never a timing decision |
| `PhysicalParameters` | Fixed model parameter vector |
| `EventSchedule` | Complete `EventSchedule` or serialized schedule |
| `FixedEventMask` | Logical mask in provider event-name order |
| `FreeEvents` | Event-name list, or `all` |
| `FixedEvents` | Event-name list forced fixed |
| `FreeReturnTime` | Logical inverse of return-time fixed status |
| `FixReturnTime` | Explicit return-time fixed status |
| `MinimumGap` | Nonnegative strict-gap floor |
| `StartSectionId`, `StopSectionId` | Section identity recorded with the schedule |
| `FixedRowPolicy` | `validate_fixed_rows` (default), `include_fixed_rows_in_least_squares`, or `diagnostic_only` |
| `FixedRowTolerance` | Physical validation tolerance for rows bound to fixed events or a fixed return |

An explicit `EventSchedule` takes precedence over the mask fields.

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
configuration = struct('FreeEvents','all', ...
    'FreeReturnTime',true, 'MinimumGap',1e-8, ...
    'StartSectionId','apex', 'StopSectionId','apex');
problem = model.createProblem('section_return_timing',configuration);
assert(isa(problem,'lmz.schedule.SectionReturnTimingProblem'));
```

The tutorial supports both apex-to-apex and a true state-plane return from one
descending-height crossing to the next:

```matlab
descendingProblem = model.createProblem('section_return_timing',struct( ...
    'StartSectionId','height_descending', ...
    'StopSectionId','height_descending'));
descending = lmz.services.ContactTimingService().solve( ...
    descendingProblem,descendingProblem.InputSchedule, ...
    struct('MultistartCount',1,'Display','off'), ...
    lmz.api.RunContext.synchronous(315));
assert(strcmp(descending.SectionCrossing.SectionId,'height_descending'));
assert(descending.SectionCrossing.Accepted);
assert(descending.FixedInitialState(3) == 0.1);
assert(descending.FixedInitialState(4) < 0);
assert(norm([descending.ContactResiduals;descending.SectionResidual]) < 1e-9);
```

The quadruped and biped registered providers also expose direct section-local
timing for validated same-touchdown returns, including
`back_left_touchdown` and `left_touchdown`, respectively. Their endpoint
contact row is bound to the return boundary through `ContactRowBindings`; it is
not duplicated as a fictitious interior event. Supported combinations are
model-declared. A catalog label alone does not imply that timing equations or a
direct adapter exist for that pair.

Tutorial named-event endpoints remain unsupported. An apex-to-
`height_descending` tutorial request is rejected with
`lmz:Timing:UnsupportedSectionOccurrence` because the first descending-height
crossing occurs before impact and does not define the requested cycle endpoint.
Use return/transfer services to inspect that crossing, or use the supported
same-section timing formulation.

The problem no longer requires the number of active residual rows `m` to equal
the number of free schedule coordinates `n`. It preserves every configured
row and delegates an admissible square or overdetermined system to the
rank-aware solver. An underdetermined point request is rejected until the user
adds independent gauges/fixed variables or declares a one-dimensional family.

## Solve and inspect the result

```matlab
context = lmz.api.RunContext.synchronous(314);
fixedState = problem.FixedInitialState;
fixedParameters = problem.FixedPhysicalParameters;
result = lmz.services.ContactTimingService().solve( ...
    problem,problem.InputSchedule, ...
    struct('MultistartCount',1),context);

assert(isa(result,'lmz.data.ContactTimingResult'));
assert(isequaln(result.FixedInitialState,fixedState));
assert(isequaln(result.FixedPhysicalParameters,fixedParameters));
assert(result.SolverDiagnostics.NoPeriodicityResidual);
assert(result.SolverDiagnostics.InitialStateBitwiseUnchanged);
```

`ContactTimingResult` records input/solved schedules, fixed and free masks,
contact residuals, section residual, terminal state, section crossing,
simulation, solver attempts/options, random seed, and provenance. A small
section residual says only that the selected section was reached; compare the
terminal state with the initial state only in a separate periodic problem.

`SolverDiagnostics.Success` is true only when solver termination, active
residual tolerance, fixed-row tolerance, accepted nongrazing crossing, event
order/minimum gaps, finite data, and energy/work validity pass. Expected
nullity and gauge independence are additional required conditions for a
`TimingFamilyProblem` or a configuration that explicitly sets
`RequireRankCondition=true`. `Status` is `converged`, `infeasible`, `invalid`,
or `numerical_failure`. Here `infeasible` means this returned candidate failed
configured physical validation; it is not proof that no solution exists.

## Rectangular timing systems

`RankAwareNonlinearSolver` computes `m` and `n` from the actual scaled residual
and decision vector. With `Solver='auto'` it selects:

| Dimension | Solver |
| --- | --- |
| `m == n`, no finite decision bounds | `fsolve` |
| `m == n`, finite decision bounds | bounded `lsqnonlin` (`trust-region-reflective`) |
| `m > n` | `lsqnonlin` |
| `m < n` | Error `lmz:Timing:GaugeRequired` for a point solve |

`fmincon_feasibility` is an explicit alternative; it is never selected
silently. The recorded rank diagnostics contain `M`, `N`, rank, nullity,
singular values, rank tolerance, condition estimates, scaled norm, unscaled
blocks, active bounds, first-order optimality, Jacobian, and Jacobian source.

Rank is not silently promoted into an existence test. An ordinary square timing
problem may satisfy its residual and physical contract even when the finite-
difference Jacobian is rank deficient. In that case diagnostics record
`RankConditionRequired=false`, `UniquenessValidated=false`, and
`RankQualification='rank_deficient_root_not_a_unique_parameterization'`.
The candidate can be reported as a root, but not as a locally unique timing
parameterization. Timing-family configurations remain stricter: their declared
expected nullity and gauge independence must pass before success.

This built-in tutorial configuration includes one fixed contact row in the
least-squares objective, producing two rows and one return-time unknown:

```matlab
rectangular = model.createProblem('section_return_timing',struct( ...
    'FixedEventMask',true,'FreeReturnTime',true, ...
    'FixedRowPolicy','include_fixed_rows_in_least_squares'));
fit = lmz.services.ContactTimingService().solve( ...
    rectangular,rectangular.InputSchedule, ...
    struct('Solver','lsqnonlin','Display','off'),context);
rank = fit.SolverDiagnostics.RankDiagnostics;
assert(isequal([rank.M rank.N rank.Rank],[2 1 1]));
assert(fit.SolverDiagnostics.Success);
```

See `examples/demo_rectangular_contact_timing.m` for the executed artifact.

## Fixed-row semantics

A fixed event removes its time from the decision vector; it does not make its
physical equation optional. The three policies are:

| Policy | Active objective rows | Physical validation |
| --- | --- | --- |
| `validate_fixed_rows` | Free-bound and always-active rows | Fixed-bound rows must meet `FixedRowTolerance` |
| `include_fixed_rows_in_least_squares` | Free, fixed, and always-active rows | Fixed-bound rows must still meet `FixedRowTolerance` |
| `diagnostic_only` | Free-bound and always-active rows | Inconsistent fixed rows still prevent `converged` |

The default is `validate_fixed_rows`. `ContactRowBindings` may bind each
provider contact row to an `event`, the `return` boundary, or `always`; without
bindings there must be exactly one contact row per scheduled event.

## Gauges and one-dimensional timing families

Wrap a base timing problem in `TimingFamilyProblem`. Declarative `TimingGauge`
objects can fix one named event, fix the return time, or impose a linear phase
condition:

```matlab
gauge = lmz.schedule.TimingGauge.fixedReturnTime(1.0);
pointProblem = lmz.schedule.TimingFamilyProblem( ...
    baseProblem,gauge,struct('ExpectedLocalDimension',0));
point = lmz.services.ContactTimingService().solve( ...
    pointProblem,pointProblem.InputSchedule,struct(),context);
assert(point.SolverDiagnostics.GaugeDiagnostics.Independent);
```

For an ungauged regular family, construct `TimingFamilyProblem` with
`ExpectedLocalDimension=1`. `TimingContinuationService.run` verifies measured
Jacobian nullity one, constructs or accepts a `SolutionPair`, and delegates the
trace to the generic pseudo-arclength continuation service. It refuses a family
whose measured nullity is not one. See
`examples/demo_timing_family_continuation.m` for a complete public extension
example.

## Reproducible multistart

`MultistartCount` and `MultistartScale` are service options. Additional seeds
use the `RunContext.RandomSeed`; attempts and residual norms are returned in
diagnostics.

```matlab
options = struct('MultistartCount',3,'MultistartScale',0.01, ...
    'MaxIterations',100,'Display','off');
first = lmz.services.ContactTimingService().solve( ...
    problem,problem.InputSchedule,options, ...
    lmz.api.RunContext.synchronous(99));
second = lmz.services.ContactTimingService().solve( ...
    problem,problem.InputSchedule,options, ...
    lmz.api.RunContext.synchronous(99));
assert(isequaln(first.SolvedSchedule.toStruct(), ...
    second.SolvedSchedule.toStruct()));
```

The best residual is selected deterministically. Cancellation is cooperative:
the service checks `RunContext` before and during attempts and propagates
`lmz:Cancelled`.

## Model author boundary

A model implements `lmz.schedule.ContactConstraintProvider`:

- `eventNames()` returns its ordered named events;
- `evaluate(initialState,physicalParameters,schedule,context,includeSimulation)`
  returns `ContactResidual`, `SectionResidual`, `TerminalState`,
  `SectionCrossing`, `Simulation`, and `Diagnostics`.

When contact rows do not map one-to-one to interior scheduled events, the
provider also returns one `ContactRowBindings` record per contact row:

```matlab
struct('Kind','event','EventName','L_TD')
struct('Kind','return','EventName','')
struct('Kind','always','EventName','')
```

The provider must evaluate one supplied schedule. It must not run `fsolve`,
project another schedule, mutate fixed data, or insert periodicity rows. The
generic `SectionReturnTimingProblem` owns chart decode/encode and named residual
blocks; `ContactTimingService` owns solver orchestration.

## Scientific compatibility checks

For migrated apex formulations:

1. start from the published/default fixed state and physical parameters;
2. compare contact and section rows with the immutable source evaluator;
3. verify fixed vectors with `isequaln`, not only a norm tolerance;
4. verify `PeriodicityRowsIncluded=false` and
   `NoPeriodicityResidual=true` diagnostics;
5. compare solved times with the existing explicit event projection within a
   measured tolerance;
6. retain residual, trajectory, event-order, and force regressions; and
7. record model/dataset provenance and random seed.

Do not describe a new non-apex timing formulation as source-equivalent without
separate evidence. The tutorial descending-height formulation is a native
analytic-model feature, not a new source-equivalence claim for any scientific
model.

## Failure modes

- `lmz:Timing:GaugeRequired`: a point solve has fewer residual rows than unknowns.
- `lmz:Solver:DimensionModeMismatch`: an explicitly selected solver is
  incompatible with the residual/decision dimensions.
- `lmz:Timing:FixedRowPolicy`: the fixed-row policy is unknown.
- `lmz:Timing:ContactRowBindings`: provider bindings do not match its contact
  residual rows.
- `lmz:Schedule:EventOrder`: supplied events are not strictly ordered above the
  minimum gap.
- `lmz:Timing:FixedDataMutated`: a provider or service changed fixed data.
- `lmz:Timing:ProviderContract`: a model omitted required result fields.
- `lmz:Timing:UnsupportedSection`: the provider does not implement the selected
  start/stop section pair.
- `lmz:Timing:UnsupportedSectionOccurrence`: the section exists, but the
  requested occurrence does not define a supported timing endpoint.
- `lmz:Timing:SectionEventMissing`: the selected return event was not emitted.

Fix the model/configuration contract. Do not weaken chart validation or add an
interactive question inside the provider.
