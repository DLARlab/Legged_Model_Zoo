# Quad-load multiple shooting and horizon continuation

The quad-load Round 10 path replaces the old “append one timing block and
single-shoot the whole prefix” limitation with explicit section nodes,
per-stride schedules, interface defects, optional controls, and energy/work
rows. It also preserves an important negative result: the current documented
search did **not** find a five-stride root. The apex Case A/B candidates fail
physical validation; the separate stride-boundary N=5 candidates remain
physical but fail residual tolerance. No five-stride simulation is published.

## What is proven and what remains qualified

| Result | Status | Evidence |
|---|---|---|
| Complete source-template inventory | Proven | Four hash-bound MAT files, seven stride templates |
| Apex-to-stride-boundary contact timing | Converged | Direct 8-by-8 timing system, rank 8, contact norm `9.346337213132372e-15` |
| N=2 contact/interface feasibility | Root found | Scaled residual norm `7.978014164613411e-13`; all physical, crossing, and event-order checks pass |
| Case A, fixed controls, N=3 | Physical validation failure | Deterministic bounded replay norm `0.7136044533002278`; rank 69/69; third-segment minimum body height `-0.1445449620598354` |
| Case B, four free stride-3 controls with energy-neutral row | Physical validation failure | Deterministic bounded replay norm `0.7217887917287552`; rank 70 with 73 unknowns and nullity 3; energy residual `0.0020976399693009087`; third-segment minimum height `-0.1457310619145955` |
| N=2 periodic multiple shooting | Numerical failure; best recorded candidate, no root | Exit flag 0; 60 rows, 46 unknowns, rank 46; norm `2.8172762892858283`; closure norm `1.7775819258610561`; candidate remains physically finite |
| N=5 stride-boundary, one freed control per later stride, bounded work 100 | Numerical failure; best recorded candidate, no root | Smallest tested control-cardinality family: exit flag 0, 119 rows/unknowns, rank 112, nullity 7; four physical candidates, best norm `0.3086908931991573`, maximum residual `0.11470808666193932` |
| N=3 -> N=4 -> N=5 physical continuation | Not reached | The strongest valid preceding physical horizon is N=2 |
| Five-stride 96-entry legacy layout | Structural codec result only | Exact `44 + 13*(5-1) = 96` round trip; not a contact-feasible horizon |

The validated relaxed alternative remains the N=2 transition-feasibility root.
It removes final periodic closure while retaining both segments' contact rows,
their interface defect, accepted crossings, event order, and finite physical
states. This is a valid two-stride transition (`7.978014164613411e-13`), not a
three- or five-stride solution.

The N=5 experiment is only the **smallest tested control-cardinality family**,
not a globally or minimally relaxed formulation. It simultaneously changes
the homogeneous shooting section from apex to `stride_boundary`, fixes return
time while freeing all eight event times per stride, frees one selected
post-swing coordinate on strides 2–5, and adds four `bounded_work` rows with a
bound of 100. That bound is deliberately loose relative to the best candidate's
largest observed transition-energy magnitude (`3.484910696093294`). All four
control columns were tested with random seed 0 and a cap of 1,200 function
evaluations at each N=1,...,5 stage: 20 primary stage solves, plus five exact
replay stages for persistence. The best N=5 candidate is physical and strictly
time ordered, but its maximum scaled residual is `0.11470808666193932`, above
the `1e-7` acceptance tolerance. Its finite-difference Jacobian has rank 112 of
119 and nullity 7. Because the search name-embedded each best numerical stage
even after unresolved N=2/N=3 stages, this is a structural warm-start ladder,
not a valid physical N=3 -> N=4 -> N=5 continuation. No root or simulation is
claimed.

The exact changed-control reports are also retained. Case B starts from
`[25.881221830170297, 2.38340126126504, 25.567036713177444,
3.5931339636457853]` and ends at `[24.69045793612025,
2.678784161445786, 27.411045742467248, 3.494781052272479]`, a delta of
`[-1.1907638940500469, 0.295382900180746, 1.844009029289804,
-0.09835291137330637]`. Those four Case B coordinates are explicitly
unbounded (`-Inf` to `Inf`) and neither lower nor upper bounds are active.
The N=5 column-3 coordinates start from the schema baseline
`[30.561884547422945, 30.561884547422945, 30.561884547422945,
30.561884547422945]` and end at `[20.085657960824477,
28.580124063894083, 35.643346319276986, 27.824731591251826]`, with delta
`[-10.476226586598468, -1.9817604835288627, 5.081461771854041,
-2.7371529561711192]`. Each N=5 coordinate has the actual schema bounds
`[0, 100]`; no bound is active at the recorded candidate.

These are local numerical search results. This evidence does not prove global
infeasibility. A positive `lsqnonlin` exit flag is never treated as a root by
itself.

## Public facades and model-owned implementation

The provisional public model-specific facades used by the examples are:

- `lmzmodels.slip_quad_load.StrideTemplateLibrary`
- `lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence`
- `lmzmodels.slip_quad_load.QuadLoadMultipleShootingProblem`
- `lmzmodels.slip_quad_load.QuadLoadHorizonContinuation`

Their supporting model-owned implementation consists of:

- `lmzmodels.slip_quad_load.QuadLoadShootingCodec`
- `lmzmodels.slip_quad_load.QuadLoadMultipleShootingEvaluator`
- `lmzmodels.slip_quad_load.QuadLoadHorizonInitializer`
- `lmzmodels.slip_quad_load.QuadLoadSectionDecisionCodec`
- `lmzmodels.slip_quad_load.QuadLoadSectionSimulationAdapter`
- `lmzmodels.slip_quad_load.SectionContactConstraintProvider`

Only the four named facades are provisional public. The supporting
model-specific classes remain internal; prefer the registered problem and
framework services unless a documented facade is required for evidence replay
or horizon-specific orchestration. See [API stability](API_STABILITY.md).

The registered problem ID is `slip_quad_load/multiple_shooting_horizon`.
Its maturity is `experimental`.

Each segment contributes eight foot-contact rows, one apex row when apex is
the active stop condition, and a 14-coordinate interface defect. Energy/work
rows are added only for non-diagnostic energy modes. Intermediate nodes and
event schedules are named decision variables; raw `X_accum` indices stay
inside the load codec.

For homogeneous `stride_boundary` shooting, the apex row is absent and the
interface has 15 coordinates, including `quad_dy`. Mixed
`StartSectionId='apex'` / `StopSectionId='stride_boundary'` configuration is
rejected by this multiple-shooting initializer; the validated mixed-section
route belongs to the separate timing-only problem and is not silently
relabeled as boundary-to-boundary shooting.

Pre-swing stiffness is linked to the preceding stride's post-swing stiffness.
The supported work modes are `energy_neutral`, `prescribed_work`,
`bounded_work`, and `diagnostic_only`.

## Template inventory and provenance

Normal runtime uses repository-contained files under
`examples/data/slip_quad_load/Scientific/Templates/`.

| Template | Strides | SHA-256 |
|---|---:|---|
| `P3_Individual_1_TR.mat` | 1 | `56736cc33ab31a0ab40b3de6783b625a07ebd54f1ae6a561b47aea5e04cd6abe` |
| `P4_TR_RL_Individual_1.mat` | 2 | `d23bd725a353d7cf1b6339699ed813755867b5dd1a0da213193eb24cb3bdad4b` |
| `P4_TR_RL_Individual_1_identical.mat` | 2 | `3212bc7af94bf66f7afb27dad92ae334970aa0a36ac6aa1a4e8251af9e511921` |
| `P4_TR_TL_Individual_1.mat` | 2 | `42f7065fa19b77b9df4de15df508eb5c62156ad0e08001511e69d8c0572e5bf7` |

The pinned source commit is
`19f3133073c988cc0c3424a647b4adbb60a90b99`. The two `Extra_Examples`
files first appear in commit
`1046565048ca4414fe1c507fa6c286cc780ed406`. They are two-stride templates,
not longer horizons. Redistribution authority remains an external release
qualification because the pinned source checkout contains no license file.

## Inspect and select templates

```matlab
startup;
context = lmz.api.RunContext.synchronous(0);
library = lmzmodels.slip_quad_load.StrideTemplateLibrary();

records = library.records();
assert(all(arrayfun(@(r) library.validateHash(r.id), records)));

source = library.load('individual_1_identical_tr_to_rl', context);
candidate = source.Segments(2);
query = struct( ...
    'InitialSectionState', candidate.InitialSectionState, ...
    'EventSchedule', candidate.EventSchedule, ...
    'ControlParameters', candidate.ControlParameters, ...
    'PhysicalParameters', candidate.PhysicalParameters, ...
    'GaitLabel', source.GaitLabel);
[selected, selectionDiagnostics] = library.select(query, context);
```

Selection scores scaled section state, schedule, controls, invariant physics,
gait label, and contact quality. The returned diagnostics record every
candidate score.

## Build and evaluate a horizon

```matlab
configuration = struct( ...
    'NumberOfStrides', 3, ...
    'EnergyMode', 'diagnostic_only', ...
    'ResidualTolerance', 1e-7, ...
    'RequireAcceptedCrossing', true);

problem = lmzmodels.slip_quad_load. ...
    QuadLoadMultipleShootingProblem([], configuration);
decision = problem.Codec.decisionDefaults();
residual = problem.evaluateShooting( ...
    decision, [], lmz.api.RunContext.synchronous(0), false);

disp(residual.Diagnostics.ContactNorms);
disp(residual.Diagnostics.InterfaceDefectNorms);
disp(residual.Feasibility);
```

For the default fixed-control N=3 formulation there are 69 unknowns and 69
active rows. This evaluation is an initialized residual, not a solve claim.

## Replay the actual searches

The complete decisions, residual blocks, ranks, singular values, solver
limits, termination reasons, controls, and physical checks are stored in:

`examples/data/slip_quad_load/Scientific/MultipleShooting/round10_feasibility_evidence.json`

Replay does not rerun the thousand-evaluation searches:

```matlab
evidence = lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
context = lmz.api.RunContext.synchronous(0);

n2 = evidence.replay('n2_transition_feasibility_root', context, false);
caseA = evidence.replay('case_a_fixed_controls_best_known', context, false);
caseB = evidence.replay( ...
    'case_b_energy_neutral_controls_best_known', context, false);
periodic = evidence.replay('n2_periodic_best_known', context, false);
n5 = evidence.replay( ...
    'n5_stride_boundary_bounded_work_best_known', context, false);

assert(n2.RootFound);
assert(strcmp(caseA.Classification,'physical_validation_failure'));
assert(strcmp(caseB.Classification,'physical_validation_failure'));
assert(strcmp(periodic.Classification,'numerical_failure'));
assert(strcmp(n5.Classification,'numerical_failure'));
assert(caseA.StoredBlockNamesMatch && caseA.StoredBlockNormsMatch);
assert(caseB.StoredBlockNamesMatch && caseB.StoredBlockNormsMatch);
assert(periodic.StoredBlockNamesMatch && periodic.StoredBlockNormsMatch);
assert(n5.StoredBlockNamesMatch && n5.StoredBlockNormsMatch);
```

To rerun a search rather than replay it, get the stored problem and decision
and call `solveFeasibility`. Expect this to be substantially slower:

```matlab
record = evidence.caseRecord('case_a_fixed_controls_best_known');
[problem, ~] = evidence.problemFor(record.id);
seed = record.deterministicReplaySeed;
options = struct( ...
    'InitialDecision', seed, ...
    'SolverOptions', struct( ...
        'Algorithm', 'levenberg-marquardt', ...
        'MaxIterations', 10, ...
        'MaxFunctionEvaluations', 800, ...
        'FunctionTolerance', 1e-12, ...
        'StepTolerance', 1e-12, ...
        'OptimalityTolerance', 1e-10, ...
        'Display', 'off'));
[solveResult, feasibilityReport] = problem.solveFeasibility( ...
    options, lmz.api.RunContext.synchronous(0));
```

Always inspect `feasibilityReport.RootFound`, the named residual blocks, and
physical checks. Do not infer success from `solveResult.ExitFlag > 0`.

The two historical Case A/B multistart summaries per case predate exact seed
retention. They live under `historicalExploratoryAttempts`, are explicitly
non-gating, and retain unavailable fields as `unknown_not_retained`. Formal
`attempts` contain two exact deterministic seeds per Case A/B, with solver
options, random seed, exit flag, termination reason, final decision, and
residual norm. The N=5 formal attempt likewise retains its exact 119-entry
seed and final case decision; its four control-column outcomes remain
non-gating `candidateFamilySummaries`.

For constrained energy/work modes, `Energy.Accepted` is part of physical
validity. A loose global residual tolerance cannot override the stricter
configured `EnergyTolerance`. Likewise, a residual-valid rectangular system
is reported as `least_squares_feasible`, not as an isolated `root_found`, and
an unacceptable solver exit is `numerical_failure` even when the stored
candidate is useful as the best recorded residual.

## Energy-neutral control projection

The four stride-3 post-swing stiffnesses can be freed explicitly:

```matlab
mask = false(3,4);
mask(3,:) = true;
configuration = struct( ...
    'NumberOfStrides', 3, ...
    'EnergyMode', {{'diagnostic_only','diagnostic_only','energy_neutral'}}, ...
    'FreeControlMask', mask, ...
    'UnboundedControls', true, ...
    'ExpectedLocalDimension', 3);
problem = lmzmodels.slip_quad_load. ...
    QuadLoadMultipleShootingProblem([], configuration);

continuation = lmzmodels.slip_quad_load.QuadLoadHorizonContinuation();
[decision, projection] = continuation.projectEnergyNeutral( ...
    problem, 3, problem.Codec.decisionDefaults());
assert(projection.ExactWithinTolerance);
```

The explicit local-dimension declaration prevents this underdetermined search
from being presented as a unique point solve. Nullity three at one unresolved
candidate does not establish a regular three-dimensional family: no gauge,
family chart, or continuation of that candidate was executed. The projection
puts the seed on the energy hyperplane. It does not guarantee
that the subsequent contact/interface solve stays on that hyperplane or finds
a physical root. The recorded Case B search ends with post-swing stiffnesses
`[24.69045793612025, 2.678784161445786, 27.411045742467248,
3.494781052272479]` and a nonzero energy residual, so it remains unresolved.

## N to N+1 continuation and checkpoint/resume

```matlab
evidence = lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
[~, n2Decision] = evidence.problemFor('n2_transition_feasibility_root');

configuration = struct( ...
    'StartStrideCount', 2, ...
    'TargetStrideCount', 5, ...
    'EnergyMode', 'diagnostic_only', ...
    'InitialDecisionForContinuation', n2Decision);
continuation = lmzmodels.slip_quad_load.QuadLoadHorizonContinuation();

structural = continuation.continueTo( ...
    configuration, struct('SolveEachHorizon', false, ...
    'InitialCompletedPhysicalStrideCount', 2), ...
    lmz.api.RunContext.synchronous(0));
checkpoint = structural.Checkpoints{1};
resumed = continuation.resume( ...
    checkpoint, struct('SolveEachHorizon', false), ...
    lmz.api.RunContext.synchronous(0));
```

The explicit initial prefix value is justified by the replayed, hash-bound N=2
root evidence; analysis-only evaluation never upgrades a candidate to a root.
This demonstrates explicit dimension embedding and deterministic resume. With
`SolveEachHorizon=false`, N=3, N=4, and N=5 are structural evaluations only.
The evidence status deliberately keeps `completedPhysicalStrideCount = 2`.

With `SolveEachHorizon=true`, the continuation uses the generic anchored
adaptive homotopy: `lambda=0` fixes the name-embedded template, `lambda=1` is
the complete contact/interface/section/energy residual, and rejected steps are
reduced and retried. Checkpoints record lambda and rank/condition diagnostics.
If lambda cannot reach one, `CompletedPhysicalStrideCount` preserves the last
validated prefix even though structural layouts may exist at larger N.
`StopOnUnresolved` defaults to `true` for solved growth, so an unresolved N=3
candidate is never used as the physical predecessor for N=4. Structural
inspection with `SolveEachHorizon=false` may still embed through N=5 without
making a root claim.

## Fixed-dimension N=2 stiffness continuation

The validated N=2 transition root also anchors a nearby continuation over one
declared control stiffness. The setup changes dimension exactly once: it adds
`segment_2_post_swing_1` to the 46-variable root through the explicit
name-bound `HorizonContinuation.embedDecision` map. The corrected seed pair and
all subsequent pseudo-arclength points then remain on the same 47-variable
`MultipleShootingProblem` chart:

```matlab
sourceCaseId = 'n2_transition_feasibility_root';
evidence = lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
[sourceProblem,sourceDecision] = evidence.problemFor(sourceCaseId);
configuration = evidence.configuration(evidence.caseRecord(sourceCaseId));
freeControlMask = false(2,4);
freeControlMask(2,1) = true;
configuration.FreeControlMask = freeControlMask;
configuration.ExpectedLocalDimension = 1;

problem = lmzmodels.slip_quad_load. ...
    QuadLoadMultipleShootingProblem([],configuration);
[decision,embedding] = lmz.shooting.HorizonContinuation(). ...
    embedDecision(sourceProblem.ShootingSchema,sourceDecision, ...
    problem.ShootingSchema);
evaluation = problem.evaluate(decision,[],context,false);
first = problem.makeSolution(decision,[],evaluation);
pair = lmz.services.SeedService().makeSecondSeed( ...
    problem,first,1e-4,struct('ExpectedLocalDimension',1),context);
family = lmz.services.ContinuationService().run(problem,pair,struct( ...
    'MaximumPoints',3,'BothDirections',false, ...
    'InitialStep',pair.AchievedRadius,'MinimumStep',1e-6, ...
    'MaximumStep',pair.AchievedRadius, ...
    'CorrectorTolerance',1e-9,'RequireFeasible',true),context);

assert(embedding.OldDimension == 46 && embedding.NewDimension == 47);
assert(isequal(embedding.AddedNames,{'segment_2_post_swing_1'}));
assert(pair.Diagnostics.JacobianRank == 46);
assert(pair.Diagnostics.LocalDimension == 1);
assert(all(arrayfun(@(k)numel(family.Branch.point(k).DecisionValues) == 47, ...
    1:family.Branch.pointCount())));
```

The executed three-point branch ends with `maximum_points`. Its selected
stiffness values are
`[25.881221830170297, 25.880923234958146, 25.88062464009689]`; the corresponding
maximum scaled residuals are
`[6.021849685566849e-13, 2.388200748271174e-12,
5.657696533489798e-12]`. All three points retain finite physical states,
accepted crossings, valid event order, and the complete N=2 contact/interface
residual tolerance.

`demo_quad_load_horizon_continuation.m` records the selected continuation
parameter and every value, the exact problem configuration, the empty generic
`ParameterValues` vector (load physics are fixed in the shooting horizon), the
chart names/hash and dimension, the 46-to-47 embedding, per-point physical
checks, and continuation snapshots/history. Its saved continuation artifact
stores the same configuration and provenance and hash-binds the feasibility
evidence JSON used for the source root.

This is a local control-stiffness family of the physical N=2
**transition-feasibility** root. It is not the unresolved N=2 periodic search;
both segments retain `EnergyMode='diagnostic_only'`, so it is not an
energy-neutral family; and it supplies no N=3 or N=5 root. The separate N=5
stride-boundary record is qualified residual evidence only and does not alter
that continuation claim.

## Direct non-apex load sections

`QuadLoadSectionSimulationAdapter` supports apex, stride boundary, and a
validated back-left touchdown-to-touchdown path. The touchdown initializer may
inspect a source event once to obtain a post-event seed; every residual
evaluation then integrates directly from that touchdown with a rotated cyclic
schedule. It does not run an apex trajectory and select an interior sample.
The preserved 44-entry source vector accepts initial `load_x` and `load_dx`
only. Accordingly, the source-specific codec keeps `load_y`/`load_dy` in the
full physical state and catalog but excludes them from the local decision and
terminal coordinate charts; diagnostics list both omitted names and their
initial/terminal physical values.

```matlab
context = lmz.api.RunContext.synchronous(0);
[codec, initialization] = lmzmodels.slip_quad_load. ...
    QuadLoadSectionDecisionCodec.fromTemplate( ...
    'back_left_touchdown', 'individual_1_tr_to_rl', 2, context);
adapter = lmzmodels.slip_quad_load.QuadLoadSectionSimulationAdapter(codec);
result = adapter.evaluate(codec.DecisionSchema.defaults(), [], context, true);

assert(result.Diagnostics.DirectSectionIntegration);
assert(~result.Diagnostics.FullApexTrajectoryLookupDuringEvaluation);
assert(strcmp(result.Crossing.SectionId, 'back_left_touchdown'));
```

The separate apex-to-stride-boundary path treats the legacy `tAPEX` slot only
as a return time and excludes the source apex equation from its active section
residual.

It is registered through `section_return_timing` and can be solved directly:

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quad_load');
problem = model.createProblem('section_return_timing', struct( ...
    'StartSectionId', 'apex', ...
    'StopSectionId', 'stride_boundary', ...
    'FixReturnTime', true, ...
    'FixedRowPolicy', 'validate_fixed_rows'));
result = lmz.services.ContactTimingService().solve( ...
    problem, problem.InputSchedule, ...
    struct('Display','off','ResidualTolerance',1e-8), ...
    lmz.api.RunContext.synchronous(1172));
assert(result.SolverDiagnostics.Success);
```

The recorded test run is square (8 active contact rows and 8 free schedule
coordinates), full rank, and converges with contact norm
`9.346337213132372e-15`. Its stop crossing is a true stride-boundary return;
the apex residual remains diagnostic and is not silently included.

## Failure and simulation policy

An unresolved horizon returns residuals, rank diagnostics, checkpoints, and
lineage. It does not return a synthetic physical simulation. A carry-forward
96-entry vector may still be used to test the legacy codec, but it must be
labeled structural and must never replace the failed physical horizon.

For a published physical horizon, every contact row, interface defect,
section condition, energy/work row, crossing, event-order check, finite-state
check, and public-time check must pass its configured tolerance.

## Public examples

- `examples/demo_quad_load_template_library.m`
- `examples/demo_quad_load_three_stride_feasibility.m`
- `examples/demo_quad_load_five_stride_horizon.m`
- `examples/demo_quad_load_horizon_continuation.m`
- `examples/demo_quad_load_n2_periodic_solve.m`

Examples write, when needed, only beneath a caller-supplied
`round10OutputDirectory` or a directory created with `tempname(tempdir)`.
