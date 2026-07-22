# Continuation

The generic engine traces a one-dimensional solution set without assuming a particular residual shape. `SecantPredictor` uses problem chart differences and a schema diagonal metric. `PseudoArclengthCorrector` solves the scaled residual plus the metric arclength hyperplane.

Current behavior includes:

- direct adjacent RoadMap pairs or a generated second seed;
- a transient lifted branch-history chart for cyclic timing values plus schema-provided scales;
- prediction, accepted, and rejected callbacks;
- retry/backtracking, bounded growth, and curvature-based shrinkage;
- duplicate checks against the lifted history and historical-segment loop-closure checks;
- deterministic `duplicate`, `loop_closure`, `stagnation`, `minimum_step`, `maximum_backtracks`, `controlled_stop`, and `maximum_points` termination reasons;
- feasibility and optional acceptance-policy hooks;
- cooperative pause, resume, cancellation/controlled stop, and partial branch preservation;
- atomically replaced checkpoint artifacts and resume from the last two accepted points while retaining the prior lifted history and adaptive step;
- bidirectional tracing whose `MaximumPoints` is the total returned branch size.

The default RoadMap seed pair is PK columns 267/268. Their parameters match exactly, their gait is PF, and their chart distance is stored in `SolutionPair.Diagnostics`. A three-point scientific run accepted its first corrected point at residual `2.05e-11` with no rejection.

Round 11 registers that route as
`slip_quadruped/roadmap_root_continuation`. Its continuation preset defaults to
`DirectionMode='both'`, labels backward as `decreasing dx` and forward as
`increasing dx`, enables checkpoints, and supplies conservative step/
corrector defaults. Run it without a model-specific catalog call:

```matlab
registry = lmz.registry.ModelRegistry.discover();
workflows = lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
descriptor = workflows.get( ...
    'slip_quadruped','roadmap_root_continuation');
session = lmz.workflow.WorkflowRunner().initialize( ...
    descriptor,lmz.api.RunContext.synchronous(1401));
session.solve(struct());
pair = session.makeAdjacentSeedPair(+1,struct());
result = session.continueBranch(struct( ...
    'DirectionMode','both','MaximumPoints',20, ...
    'InitialStep',pair.AchievedRadius));
```

`DirectionMode` is `forward`, `backward`, or `both`; it is translated to the
generic engine's pair orientation and `BothDirections` option. `MaximumPoints`
remains the total returned branch size. Registered direction labels are
presentation metadata and do not redefine the continuation coordinate or
acceptance policy. The GUI exposes all three modes and uses the same persistent
branch canvas for predictor, accepted, rejected, temporary, and completed
layers.

Each accepted/rejected `ContinuationSnapshot` normalizes predictor, corrected decision, residual norm, step, curvature, corrector iterations, backtracking count, feasibility, gait, termination candidate, checkpoint path, exit flag, failure, direction, and achieved step. `ContinuationResult.Diagnostics` and continuation/checkpoint artifacts retain accepted/rejected counts, direction summaries, final step, and termination reason; the GUI exposes the live subset relevant to the active run.

Parameter homotopy requires a schema variable whose `Activity` is exactly `active`. Inactive compatibility fields and derived quantities are omitted from parameter selectors and rejected by the transport service. `phi_neutral` remains in Results29 for compatibility but is rejected because the source dynamics do not use it. The active quadruped regression transports `k_leg` from the default RoadMap seed to a nearby target, first verifies the raw residual changes, then verifies the corrected residual. A branch-family scan transports the seed and repeats one-dimensional continuation at target values; it is not two-dimensional continuation.

Biped scientific continuation uses adjacent published GaitMap columns for stable branch/checkpoint tests; generated second-seed coverage uses a small schema-scaled radius. Analytic fixtures deterministically force rejection/backtracking, minimum-step exit, curvature shrinkage, stagnation, and historical segment loop closure without weakening the quadruped or biped scientific tests.

The lift is numerical run state rather than serialized as a second public branch coordinate matrix. Checkpoints reconstruct it from stored decisions on resume. Very long branches crossing many timing wraps remain a cross-release stress-test item.

Registered homotopy and family-scan presets select the same existing services;
they do not make JSON executable. The complete provider/runner contract is in
[registered-workflows.md](registered-workflows.md), and the pinned quadruped
route/checkpoint example is in
[quadruped-reference-workflow.md](quadruped-reference-workflow.md).
