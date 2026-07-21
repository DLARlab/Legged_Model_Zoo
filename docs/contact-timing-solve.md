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
| Uses `ContactTimingService` | Uses `SolveService` on a periodic problem |

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

The quadruped, biped, and quad-load providers deliberately remain apex-only so
their timing rows retain the migrated source formulation; they reject other
section pairs before solving. Tutorial named-event endpoints are unsupported.
An apex-to-`height_descending` timing request is also rejected with
`lmz:Timing:UnsupportedSectionOccurrence` because the first descending-height
crossing occurs before impact and does not define the requested cycle endpoint.
Use return/transfer services to inspect such crossings, or use the supported
same-section timing formulation.

The problem constructor checks that the number of free schedule coordinates
matches the number of explicit contact/section residuals. A mismatch is a
configuration error, not permission to add a hidden residual or solve.

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

- `lmz:Timing:DimensionMismatch`: fixed/free mask and residual count disagree.
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
