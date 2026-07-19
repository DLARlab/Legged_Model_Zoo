# Scientific SLIP biped usage

The default `slip_biped/periodic_apex` problem is the migrated jerboa template
model, not the earlier two-variable stride-closure demonstration. It uses the
published 12-entry periodic decision, two swing-offset parameters, eight
integrated states, and the full 15-entry compatibility residual. The separate
`demo_stride` problem remains available as a tutorial.

Run `startup` once from the repository root before using these APIs.

## Load a published gait branch

```matlab
startup
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
problem = model.createProblem('periodic_apex',struct());

catalog = lmzmodels.slip_biped.GaitMapCatalog.default();
branch = catalog.loadBranch(catalog.defaultBranchPath(),problem,true);
index = catalog.recommendedSeedIndex(catalog.defaultBranchPath());
solution = branch.point(index);
```

`true` requests the repository-contained native artifact. Pass `false` to
decode the unchanged `results` MAT file directly. `catalog.loadAll` loads all
six branches: walking (`W1`), running (`R1`), hopping (`HP1`), skipping
(`SK1`, `SK2`), and asymmetric running (`AR1`).

The native solution preserves the source filename, column, SHA-256 digest,
gait classification, and offsets. Exact legacy export is:

```matlab
results = lmzmodels.slip_biped.Results14Adapter.encode(branch);
```

## Decision, parameters, and states

The periodic decision order is fixed:

```text
dx, y, dy, alphaL, dalphaL, alphaR, dalphaR,
tL_TD, tL_LO, tR_TD, tR_LO, tAPEX
```

The four contact-event times are cyclic times whose period source is `tAPEX`.
The two named parameters are `offset_left` and `offset_right`. Scientific
periodic evaluation fixes `k_leg = 20` and `omega_swing = 6.5`, matching the
source branch evaluator.

Integrated states are ordered as:

```text
x, dx, y, dy, alphaL, dalphaL, alphaR, dalphaR
```

## Evaluate and simulate

```matlab
context = lmz.api.RunContext.synchronous(0);
evaluation = problem.evaluate(solution.DecisionValues, ...
    solution.ParameterValues,context,true);
simulation = evaluation.Simulation;
```

The evaluation contains nine named residual blocks totaling 15 entries. Entry
12 is `legacy_reserved_zero` and intentionally remains zero. No event-time
solve occurs inside evaluation. The simulation provides strictly increasing
public time, eight physical states, five event records with pre/post states,
left/right contact modes, six GRF channels, energy, observables, and physical
kinematics. Raw duplicate event samples remain available through
`problem.Evaluator.evaluate(...)` for source-regression work.

Useful accessors include:

```matlab
height = simulation.state('y');
leftAngle = simulation.state('alphaL');
eventRecords = simulation.EventRecords;
feet = simulation.Kinematics.FootX;
```

## Solve and continue

A published branch point already satisfies the source equations, so the solve
service normally accepts it without unnecessary numerical work:

```matlab
solved = lmz.services.SolveService().solve( ...
    problem,solution,struct(),context);
```

For scientific continuation, use adjacent published points or generate a
second seed:

```matlab
pair = lmz.services.SeedService().adjacentBranchPair( ...
    problem,branch,index,1,struct(),context);

options = struct('MaximumPoints',10,'BothDirections',true, ...
    'InitialStep',pair.AchievedRadius);
continued = lmz.services.ContinuationService().run( ...
    problem,pair,options,context);
```

Set `CheckpointPath` in the continuation options to save resumable native
state. The generic continuation service handles pause, stop, backtracking,
duplicate detection, and checkpoint resume.

## Source-equivalent trajectory fitting

The fit decision has 16 entries: the 12 periodic variables followed by
`k_leg`, `omega_swing`, `offset_left`, and `offset_right`. The default dataset
and fitted seed are stored under `examples/data/slip_biped/trajectory_fit`.

```matlab
fit = model.createProblem('trajectory_fit',struct());
u = fit.sourceSeed();
weights = fit.getParameterSchema().defaults();
[objective,terms,diagnostics] = fit.evaluateObjective(u,weights,context);
[c,ceq] = fit.nonlinearConstraints(u,weights,context);
```

The named weight parameters default to the active source `fms_cost_fun`
values. Returned terms separate position, height, left/right leg-angle,
periodic-residual, and event-timing contributions. The source row-minus-column
event-timing norm is preserved exactly, including its 5-by-5 implicit
expansion. `ceq` is the source-scaled 15-entry residual used by the constrained
source alternative.

The published `Main.m` path uses the penalized objective without separate
equality constraints. Select that reproducibly for a short generic fit:

```matlab
fit = model.createProblem('trajectory_fit', ...
    struct('EnforceConstraints',false));
u0 = fit.sourceSeed();
u0(1) = u0(1) + 0.05;
u0(4) = u0(4) + 0.01;
seed = fit.makeSolution(u0,fit.getParameterSchema().defaults(),[]);
options = struct('Algorithm','sqp','MaxIterations',3, ...
    'MaxFunctionEvaluations',150,'ConstraintTolerance',0.2, ...
    'OptimalityTolerance',1e-3,'StepTolerance',1e-3);
result = lmz.services.OptimizationService().run(fit,seed,options,context);
```

Use `EnforceConstraints=true` to select the alternate source `fmc_cost_fun`
weights (`5, 50, 10, 10`) and expose its scaled residual equality constraints
to `fmincon`. The default is the active `Main.m` penalized `fms_cost_fun` path.

## Visualization and examples

`BipedRenderer` animates the point mass, legs, feet, ground, and contact state.
`BipedPlotProvider` creates body/leg trajectory, GRF, and normalized footfall
plots. Repository examples are:

```text
demo_slip_biped_gaitmap_workflow.m
demo_slip_biped_solve.m
demo_slip_biped_continuation.m
demo_slip_biped_trajectory_fit.m
```

Each example is rerunnable, leaves a structured `output` value in the
workspace, uses only repository-contained data, and prints an exact success
marker.

## Provenance and redistribution

The migration source is
`DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions`, commit
`4595146c5881a5313bc8fe92de85099193ef9be9`. The upstream readme states CC
BY-NC 4.0. Public redistribution remains subject to the repository's recorded
owner review; do not infer broader permission from the presence of these
research assets.
