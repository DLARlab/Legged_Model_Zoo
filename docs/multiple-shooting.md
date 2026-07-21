# Multiple shooting

Multiple shooting represents a long hybrid trajectory as independently
simulated section-to-section segments joined by explicit interface defects.
It lets a solver adjust intermediate section states, event schedules, allowed
controls, and selected physical or target variables together. This is distinct
from single shooting, which propagates one initial state through the complete
horizon before evaluating final closure.

## Mathematical contract

For an `N`-segment horizon, the decision may contain section states
`xi_0,...,xi_N`, schedules `tau_1,...,tau_N`, and declared free controls or
parameters. A model-owned `SectionSimulationAdapter` propagates segment `k`
once and returns symmetry-aligned terminal section coordinates. The generic
interface row is

\[
d_k = \widehat{\Phi}_k(\xi_{k-1},\tau_k,c_k,\theta)-\xi_k.
\]

The model adapter is responsible for applying the selected section side,
world/local translation, and symmetry before returning
`TerminalCoordinates`. `InterfaceDefect` then computes the named, scaled
difference from the next `ShootingNode`.

A residual evaluation can contain these blocks, without deleting rows to make
the system square:

```text
segment_k_contact_constraints
segment_k_section_residual
interface_k_defect
segment_k_energy_work
final_section_closure | final_transition_target | final_feasibility_target
```

Intermediate nodes are joined by defects. Periodic closure is imposed only by
`final_section_closure`; it is not imposed independently on every segment.

## Public objects

| Object | Responsibility |
| --- | --- |
| `SectionStateSchema` | Named projection between a full physical state and section coordinates |
| `ShootingNode` | Section identity/hash, pre/post side, full and section state, free mask, translation, symmetry, and lineage |
| `ShootingSegment` | Endpoint nodes, event schedule, contact constraints, physical/control data, energy/work mode, simulation options, and lineage |
| `ShootingHorizon` | Ordered `N+1` nodes and `N` segments with `periodic`, `transition`, or `feasibility` formulation |
| `ShootingDecisionSchema` | Named bindings for free node coordinates, schedule coordinates, controls, selected physical parameters, targets, and gauges |
| `SectionSimulationAdapter` | Model-owned direct propagation of exactly one configured segment |
| `MultipleShootingProblem` | Generic nonlinear problem exposing the complete residual layout |
| `PeriodicMultipleShootingProblem` | Periodic specialization with final section closure |
| `TransitionMultipleShootingProblem` | Transition specialization with an explicit terminal target |
| `ShootingResult` | Solve result, horizon, feasibility report, segment results, histories, checkpoints, and diagnostics |

All durable contracts contain inert data. A runtime function-handle segment
evaluator is accepted for trusted in-process experimentation, but it is marked
non-reproducible and cannot be serialized as a problem contract. Registered
workflows should use a model-owned `SectionSimulationAdapter`.

## Registered tutorial solve

The analytic hopper exposes a two-segment periodic problem through the normal
model registry:

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
problem = model.createProblem('multiple_shooting',struct( ...
    'HorizonLength',2,'Formulation','periodic', ...
    'ResidualTolerance',1e-8));
seed = problem.ShootingSchema.defaults();
context = lmz.api.RunContext.synchronous(1017);
result = lmz.services.MultipleShootingService().solve( ...
    problem,seed,struct('Solver','auto','Display','off', ...
    'ResidualTolerance',1e-8),context);

assert(result.FeasibilityReport.Success);
assert(strcmp(result.FeasibilityReport.Classification,'root_found'));
assert(result.Horizon.segmentCount() == 2);
assert(max(result.SolveResult.Evaluation.Diagnostics. ...
    InterfaceDefectNorms) <= 1e-8);
```

See `examples/demo_multiple_shooting_tutorial.m` for the executed version and
artifact save.

## Registered scientific two-segment evidence

The quadruped and biped now register `multiple_shooting` as an experimental,
tested problem. Their default `HorizonLength=2` construction uses the model's
touchdown-section codec and direct section adapter. A source-periodic solution
initializes the node coordinates and fixed schedule, but it is not used as a
segment oracle: every residual call directly evaluates two segments, two sets
of contact rows, two interface defects, and final section closure.

```matlab
registry = lmz.registry.ModelRegistry.discover();
ids = {'slip_quadruped','slip_biped'};
for k = 1:numel(ids)
    model = registry.createModel(ids{k});
    problem = model.createProblem('multiple_shooting',struct( ...
        'HorizonLength',2,'ResidualTolerance',1e-7));
    result = lmz.services.MultipleShootingService().solve( ...
        problem,problem.getDecisionSchema().defaults(),struct( ...
        'Solver','auto','Display','off','ResidualTolerance',1e-7, ...
        'MaxIterations',30,'MaxFunctionEvaluations',500), ...
        lmz.api.RunContext.synchronous(7200+k));
    assert(result.Horizon.segmentCount() == 2);
    assert(result.FeasibilityReport.Success);
    assert(strcmp(result.FeasibilityReport.Classification, ...
        'least_squares_feasible'));
    assert(all(cellfun(@(segment) ...
        ~segment.Diagnostics.ApexOracleUsed,result.SegmentResults)));
end
```

The committed focused solve records the following local numerical evidence:

| Model | Residual rows `m` | Decisions `n` | Rank | Nullity | Maximum scaled residual |
| --- | ---: | ---: | ---: | ---: | ---: |
| `slip_quadruped` | 55 | 13 | 13 | 0 | `1.318856135412716e-11` |
| `slip_biped` | 29 | 7 | 7 | 0 | `3.979039320256561e-13` |

Both systems are rectangular and full-column-rank at the returned point, so the
correct classification is `least_squares_feasible`, not `root_found`. This is
qualified local evidence for the configured homogeneous N=2 horizon; it is not
a global existence certificate and is not trajectory repetition.

The factory also consumes the generic configuration fields instead of silently
hardcoding them:

- `InterfaceStateMask` may be a scalar, one section-coordinate vector, or a
  coordinate-by-`(N+1)` matrix;
- `EventFreeMask` may be a scalar, `[all_events return_time]`, or one value per
  interior occurrence plus return time; and
- `EnergyWorkMode` must be one of `diagnostic_only`, `energy_neutral`,
  `bounded_work`, or `prescribed_work` and is stored on every segment.

These section adapters expose no control decision coordinates. Therefore any
true value in `ControlFreeMask` is rejected with
`lmz:Shooting:ScientificControlDecisionsUnavailable`; fixed controls remain a
model configuration, not a fictitious solver variable. The verified evidence
above uses fixed schedules, fixed endpoint nodes, free interior-node
coordinates, and `EnergyWorkMode='diagnostic_only'`. The biped adapter exposes
its measured end-minus-start total energy for an active energy/work row. The
quadruped source exposes no total-energy channel, so selecting a nondiagnostic
mode fails explicitly with `lmz:Shooting:ScientificEnergyResidualUnavailable`
instead of silently omitting the requested constraint.

## Registered scientific transition shooting

`slip_quadruped` and `slip_biped` also register `section_transition` for
distinct start and stop section IDs. This is a one-segment
`TransitionMultipleShootingProblem` with two different section charts and an
explicit terminal target. It is the supported route for named-event → named-
event, named-event → descending state-plane, descending state-plane → named-
event, and the catalog's safe composite endpoints.

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
problem = model.createProblem('section_transition',struct( ...
    'StartSectionId','left_touchdown', ...
    'StopSectionId','descending_y_0_95', ...
    'StartStateFreeMask',true, ...
    'TargetStateFreeMask',true, ...
    'EventFreeMask',false));

u0 = problem.ShootingSchema.defaults();
p = problem.getParameterSchema().defaults();
residual = problem.evaluateShooting(u0,p, ...
    lmz.api.RunContext.synchronous(1020),false);

assert(strcmp(problem.Formulation,'transition'));
assert(~problem.Horizon.Target.PeriodicClosure);
assert(strcmp(problem.Horizon.Target.ResidualName, ...
    'final_transition_target'));
assert(residual.SegmentResults{1}.Crossing.Accepted);
assert(residual.SegmentResults{1}.Diagnostics.DirectSectionIntegration);
assert(~residual.SegmentResults{1}.Diagnostics.ApexOracleUsed);
```

Fresh construction may rephase the immutable apex solution once to obtain an
initial state, schedule, and explicit target. The resulting
`TransitionSeed`, horizon, and named decision schema are stored in the problem
contract. Residual evaluation never calls the source orbit: the model-owned
transition codec decodes the start chart and event schedule, and the model-
owned adapter performs direct propagation.

The residual blocks remain independent:

```text
segment_1_contact_constraints
segment_1_section_residual
interface_1_defect
final_transition_target
```

The terminal node is not periodic closure. `interface_1_defect` compares the
directly propagated endpoint with that node, while `final_transition_target`
compares the node with the configured stop-chart target. Same-section requests
are rejected by this route and continue to use `periodic_orbit` or
`multiple_shooting`, whose final block remains `final_section_closure`.

The committed numerical matrix and the distinction between a tolerance-
satisfying transition and an accepted-crossing candidate are in
[scientific-section-shooting.md](scientific-section-shooting.md). In
particular, reaching a nongrazing endpoint does not erase a nonzero contact
residual and never creates a periodic-root claim.

## Rank-aware solver selection

`MultipleShootingService` delegates to `RankAwareNonlinearSolver` and records
the requested and selected solver. `Solver='auto'` has only these validated
dimension rules:

| Residual rows `m` and unknowns `n` | Automatic mode |
| --- | --- |
| `m == n`, no finite decision bounds | `fsolve` |
| `m == n`, finite decision bounds | bounded `lsqnonlin` (`trust-region-reflective`) |
| `m > n` | `lsqnonlin` |
| `m < n` | Rejected with `lmz:Timing:GaugeRequired` |

`fmincon_feasibility` is available only when explicitly requested. An
underdetermined point problem needs independent fixed variables or gauges. A
regular continuation family must instead declare its family formulation and
satisfy `n-rank(J)=1`.

Rank diagnostics include `M`, `N`, rank, nullity, singular values, rank
tolerance, effective and full-column condition estimates, scaled residual
norm, unscaled blocks, active bounds, first-order optimality, and Jacobian
source. A small residual does not establish an isolated solution when the
reported nullity is nonzero.

## Physical success

Numerical termination alone is insufficient. `FeasibilityReport.Success` also
requires every configured scaled residual to meet tolerance and the evaluator
to report finite states, valid event order, accepted nongrazing crossings, and
valid physical and energy/work conditions. The report then classifies a
successful square system as `root_found` and another successful rectangular
system as `least_squares_feasible`.

Always inspect rank and physical diagnostics in addition to classification.
The complete vocabulary and the limits of local numerical evidence are in
[horizon-feasibility.md](horizon-feasibility.md).

## Energy/work rows

Each `ShootingSegment` declares one of:

```text
energy_neutral
bounded_work
prescribed_work
diagnostic_only
```

For active modes, a model adapter returns `EnergyResidual`; the evaluator adds
the named `segment_k_energy_work` block using the declared tolerance as its
scale. `diagnostic_only` retains the measured residual without adding an active
equation. A control change is not energy-neutral merely because its continuous
state was copied.

## Evaluation and caching boundary

Within one residual call, `MultipleShootingEvaluator` simulates each segment
exactly once and reuses that result for contact, section, interface, energy,
physical-validity, and optional trajectory output. Diagnostics record
`SegmentEvaluationCount` and `SingleEvaluationCache=true`. No mutable result is
reused across a changed decision, so finite-difference Jacobians cannot receive
stale simulations.

## Initialization and horizon growth

`ShootingInitializer` records the attempted ordered strategies: exact source
horizon, nearest compatible template, phase-compatible repetition,
section-state interpolation, schema-scaled secant prediction, and optional
deterministic multistart.

`HorizonContinuation.embedDecision` maps decisions by variable name when a
problem grows from `N` to `N+1`; new names take the new schema defaults. This
explicit embedding prevents a continuation step from silently interpreting an
old vector under a new dimension. `HorizonContinuation.traceHomotopy` then
blends an anchor equation at `lambda=0` into the complete new-horizon residual
at `lambda=1`. It records adaptive step growth, rejection/backtracking, rank,
condition estimates, accepted checkpoints, and the last reached lambda. An
intermediate-lambda point is never classified as a physical horizon.

`HorizonContinuationService.run` applies a declared sequence of model
configurations and uses this adaptive homotopy by default after each dimension
embedding. If the minimum step is reached, it records the failed target and
returns the last completed horizon rather than fabricating later segments. Set
`UseAdaptiveHomotopy=false` only to request the explicit direct-correction
path. Completed-step checkpoints bind the full problem contract, and adaptive
checkpoints also bind the anchor, accepted lambda, next step, and attempt
history. Use `HorizonContinuationService.resumeHomotopy` to continue an
interrupted adaptive step; changed same-size problems and changed anchors are
rejected. See [horizon-feasibility.md](horizon-feasibility.md) for the service
and checkpoint contracts.

## Fixed-dimension quantity continuation

Use ordinary chart-aware `ContinuationService` after a shooting formulation
has declared a regular one-dimensional family. The quad-load example frees one
named N=2 post-swing stiffness while leaving every contact, interface, and
section residual active:

```matlab
evidence = lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
[sourceProblem,sourceDecision] = evidence.problemFor( ...
    'n2_transition_feasibility_root');
configuration = evidence.configuration(evidence.caseRecord( ...
    'n2_transition_feasibility_root'));
configuration.FreeControlMask = logical([0 0 0 0;1 0 0 0]);
configuration.ExpectedLocalDimension = 1;
problem = lmzmodels.slip_quad_load. ...
    QuadLoadMultipleShootingProblem([],configuration);
[decision,embedding] = lmz.shooting.HorizonContinuation(). ...
    embedDecision(sourceProblem.ShootingSchema,sourceDecision, ...
    problem.ShootingSchema);
first = problem.makeSolution(decision,[], ...
    problem.evaluate(decision,[],context,false));
pair = lmz.services.SeedService().makeSecondSeed( ...
    problem,first,1e-4,struct('ExpectedLocalDimension',1),context);
continued = lmz.services.ContinuationService().run( ...
    problem,pair,struct('MaximumPoints',3,'BothDirections',false, ...
    'InitialStep',pair.AchievedRadius, ...
    'MaximumStep',pair.AchievedRadius,'RequireFeasible',true),context);

assert(isequal(embedding.AddedNames,{'segment_2_post_swing_1'}));
assert(embedding.OldDimension == 46 && embedding.NewDimension == 47);
assert(pair.Diagnostics.LocalDimension == 1);
assert(all(arrayfun(@(k)numel(continued.Branch.point(k).DecisionValues) ...
    == 47,1:continued.Branch.pointCount())));
```

The first 46-to-47 change is explicit and adds exactly the selected control.
`SeedService` measures rank 46 and nullity one before constructing the second
seed. `ContinuationService`, its predictor, and its corrector then use the
problem's `VariableChart` operations while every accepted branch decision
remains 47-dimensional. The public example records the selected value, fixed
configuration, parameter vector, chart hash, physical checks, and continuation
history/provenance.

This local branch is anchored at the physical N=2 transition-feasibility root.
It is not the unresolved load periodic search, it retains
`EnergyMode='diagnostic_only'`, and it does not establish N=3 or N=5
feasibility. See
[quad-load-horizon-continuation.md](quad-load-horizon-continuation.md) for the
executed values and residuals.

## Artifacts and reproduction

`ShootingResult.toArtifact()` stores the horizon, problem contract, decision
schema, residual/rank/feasibility diagnostics, initializer and continuation
history, and source hashes. `lmz.services.reproduceRun` verifies the stored
horizon and problem-contract hashes before reconstructing a
`multiple-shooting-run`. Runtime callbacks are never deserialized.

Related guides:

- [Contact-timing solve](contact-timing-solve.md)
- [Horizon feasibility](horizon-feasibility.md)
- [Multi-stride planning](multi-stride-planning.md)
- [Poincare sections](poincare-sections.md)
