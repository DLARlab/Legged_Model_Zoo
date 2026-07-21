# Periodic orbit and continuation tutorial

This tutorial solves and continues the built-in analytic `tutorial_hopper`.
It also shows why contact timing and periodic closure are separate operations.
Run from the repository root. Solve and continuation require Optimization
Toolbox.

## 1. Start from a registered problem

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
problem = model.createProblem('periodic_hop',struct());
context = lmz.api.RunContext.synchronous(2026);
```

The decision schema contains initial/observable family values, schedule,
control, and a derived stride length. The physical parameter schema contains
gravity. Inspect roles before deciding what a continuation or transition may
change:

```matlab
decisionMetadata = problem.getDecisionSchema().metadataTable();
parameterMetadata = problem.getParameterSchema().metadataTable();
assert(any(strcmp(decisionMetadata.Role,'schedule')));
assert(all(strcmp(parameterMetadata.Role,'physical')));
```

## 2. Evaluate the seed

```matlab
u0 = problem.getDecisionSchema().defaults();
p0 = problem.getParameterSchema().defaults();
seedEvaluation = problem.evaluate(u0,p0,context,false);
seed = problem.makeSolution(u0,p0,seedEvaluation);
fprintf('seed residual norm: %.3e\n',seedEvaluation.ScaledResidualNorm);
```

Residual blocks name the formulation constraints. A solution family is not
defined by residual row count alone. If `n` is the number of decisions, a
regular one-dimensional branch requires

\[
n-\operatorname{rank}(J_F)=1.
\]

Redundant rows may be present; rank is the relevant local condition.

## 3. Solve periodic closure

```matlab
solveOptions = struct('FunctionTolerance',1e-10, ...
    'StepTolerance',1e-10,'Display','off');
solved = lmz.services.SolveService().solve( ...
    problem,seed,solveOptions,context);
orbit = solved.Solution;
assert(solved.Evaluation.ScaledResidualNorm < 1e-7);
```

`SolveService` accepts an already-valid seed without unnecessary movement; the
result still records evaluation, options, seed, random seed, and provenance.

## 4. Simulate the solved orbit

The model owns the periodic simulation. Use its public request boundary:

```matlab
request = lmz.api.SimulationRequest( ...
    'tutorial_hopper','periodic_hop',orbit,struct());
simulation = model.simulate(request,context);
assert(all(diff(simulation.Time) > 0));
assert(~isempty(simulation.EventRecords));
```

## 5. Compare with timing-only solve

```matlab
timingProblem = model.createProblem('section_return_timing',struct());
fixedState = timingProblem.FixedInitialState;
fixedParameters = timingProblem.FixedPhysicalParameters;
timing = lmz.services.ContactTimingService().solve( ...
    timingProblem,timingProblem.InputSchedule, ...
    struct('MultistartCount',1),context);
assert(isequaln(timing.FixedInitialState,fixedState));
assert(isequaln(timing.FixedPhysicalParameters,fixedParameters));
assert(timing.SolverDiagnostics.NoPeriodicityResidual);
```

The timing result reaches the apex section and satisfies impact geometry. It
does not assert that the terminal section coordinates equal the initial ones.
The periodic problem adds closure and is therefore the input to continuation.

## 6. Construct a corrected second seed

```matlab
seedRadius = 0.02;
pair = lmz.services.SeedService().makeSecondSeed( ...
    problem,orbit,seedRadius,struct(),context);
assert(pair.AchievedRadius > 0);
assert(pair.First.DecisionSchema.count() == ...
    pair.Second.DecisionSchema.count());
```

`SeedService` obtains the Jacobian or a finite-difference Jacobian, finds a
null direction, scales it with the decision schema, predicts, and corrects onto
the solution set. Hand-perturbing one raw vector entry is not an equivalent
seed construction.

## 7. Continue one direction

```matlab
options = struct('MaximumPoints',8,'BothDirections',false, ...
    'InitialStep',0.02,'MinimumStep',1e-4, ...
    'MaximumStep',0.05,'CorrectorTolerance',1e-9);
continued = lmz.services.ContinuationService().run( ...
    problem,pair,options,context);
branch = continued.Branch;
assert(branch.pointCount() >= 2);
fprintf('termination: %s, points: %d\n', ...
    continued.TerminationReason,branch.pointCount());
```

The result retains prediction/accept/reject snapshots, step and curvature
diagnostics, options, source pair, random seed, provenance, and normalized
termination reason.

## 8. Save the continuation run

Choose an explicit writable location:

```matlab
outputRoot = tempname;
mkdir(outputRoot);
artifactPath = fullfile(outputRoot,'tutorial_hopper_branch.lmz.mat');
lmz.io.ArtifactStore.save(artifactPath,continued.toArtifact());
loaded = lmz.io.ArtifactStore.load(artifactPath);
assert(strcmp(loaded.artifactType,'continuation-run'));
```

Callback fields are not restored from artifacts. Resume or reproduce only
after verifying model/problem versions, source hashes, and configuration.

## 9. Inspect the section catalog

```matlab
catalogPath = fullfile(lmz.util.ProjectPaths.catalog(), ...
    'tutorial_hopper','poincare_sections.json');
sections = lmz.poincare.PoincareSectionRegistry.fromJson( ...
    catalogPath,'ModelId','tutorial_hopper', ...
    'StateSchema',model.getPhysicalStateSchema());
apex = sections.section('apex');
descending = sections.section('height_descending');
defaultSection = sections.defaultSection('periodic_orbit');
assert(strcmp(defaultSection.Id,'apex'));
```

The built-in catalog also exposes impact pre/post sections. Section sides and
fingerprints are part of the numerical configuration.

## 10. Rephase to a descending-height section

Section rephasing is more than changing an ID. Simulate the apex orbit, detect
the accepted descending-height crossing, select its declared side, shift time,
rotate cyclic event times, apply planar-translation symmetry, and construct a
new solution with lineage linking both section hashes. Then evaluate and solve
under a problem configured for the descending section before building a new
seed pair.

Use the public transfer service, then create the target-section problem from
the transferred solution:

```matlab
transferred = lmz.services.SectionTransferService().transfer( ...
    model,orbit,'height_descending',context);
descendingProblem = model.createProblem('periodic_orbit',struct( ...
    'StartSectionId','height_descending', ...
    'StopSectionId','height_descending'));
descendingEvaluation = descendingProblem.evaluate( ...
    transferred.Solution.DecisionValues, ...
    transferred.Solution.ParameterValues,context,true);
assert(transferred.PhaseInvariantObservablesPreserved);
assert(transferred.DecisionCodecRephased);
assert(max(abs(descendingEvaluation.Simulation.States(:) - ...
    transferred.Simulation.States(:))) <= 1e-12);
assert(~descendingEvaluation.Diagnostics.HiddenTimingSolve);
```

Never rename the old solution or reuse its apex seed pair/checkpoint. The
built-in tutorial, quadruped, and biped adapters construct a target-configured
`periodic_orbit` solution and re-evaluate it before the service records
`DecisionCodecRephased=true`. A plugin or unsupported decision codec retains
`false`; that model must provide and verify its own codec rephasing before the
transferred solution can seed continuation. In either case, the configured
target problem remains the authority, and a new solved seed pair is required.

## 11. Compare apex and descending branches

Compare only phase-invariant quantities and symmetry-aligned closed
trajectories:

- period, speed, stride length, and mechanical-energy summaries;
- the same physical orbit after cyclic time shift;
- section transversality and event sequence; and
- continuation topology after mapping both branches into common observables.

Different coordinate values at different phase origins are expected. A new
section does not inherit the apex formulation's validation status.

## 12. Choose same-dimension or horizon continuation

Round 10 exposes two additional continuation routes; they solve different
objects and are not aliases for the branch above:

- `TimingContinuationService` traces a declared nullity-one
  `TimingFamilyProblem`. It verifies the measured nullity and gauge
  independence before delegating to pseudo-arclength continuation.
- `HorizonContinuationService` grows a registered
  `MultipleShootingProblem` through an explicit configuration sequence, such as
  two, three, then five segments. Each step maps retained decision values by
  name, initializes newly added variables, and records the embedding and exact
  feasibility report.

For a fixed two-segment analytic horizon:

```matlab
shootingProblem = model.createProblem('multiple_shooting',struct( ...
    'HorizonLength',2,'Formulation','periodic'));
shootingSeed = shootingProblem.ShootingSchema.defaults();
shooting = lmz.services.MultipleShootingService().solve( ...
    shootingProblem,shootingSeed,struct('Solver','auto', ...
    'ResidualTolerance',1e-8),context);
assert(shooting.FeasibilityReport.Success);
```

Use ordinary `ContinuationService` when the problem dimension stays fixed and
the target is a regular solution family. Use `HorizonContinuationService` only
when the registered problem is deliberately rebuilt at each horizon length.
The latter stops at qualified failure by default and retains partial evidence;
it does not synthesize missing segments. See
[multiple-shooting.md](multiple-shooting.md) and
[horizon-feasibility.md](horizon-feasibility.md) for residual layout,
classification, checkpoint, and artifact details.

## 13. Troubleshooting

- `lmz:Seed:*`: the solved seed is not sufficiently regular, separated, or
  residual-small for pair construction.
- `lmz:Continuation:*`: reduce initial/maximum step, inspect rejected
  snapshots, and check section configuration identity.
- `lmz:Poincare:ReturnNotFound`: verify direction, minimum return time, mode,
  event sequence, and occurrence.
- grazing diagnostics: change section or operating point; do not suppress the
  transversality check.
- timing residual small but orbit does not close: expected for timing-only;
  solve the periodic problem.

See [poincare-sections.md](poincare-sections.md),
[contact-timing-solve.md](contact-timing-solve.md), and
[continuation.md](continuation.md) for the detailed contracts. Timing-family
and changing-dimension horizon continuation are covered by
[multiple-shooting.md](multiple-shooting.md) and
[horizon-feasibility.md](horizon-feasibility.md).
