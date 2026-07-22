# SLIP quadruped registered reference workflow

`slip_quadruped/roadmap_root_continuation` is the Round 11 reference for a
complete registered scientific workflow. It binds the repository-contained
RoadMap to the validated apex-periodic problem, source-style axes and graphics,
root refinement, adjacent/generated seed construction, and pseudo-arclength
continuation without calling the legacy GUI or legacy continuation functions.

The equations, scientific tolerances, Results29 codec, and source fixtures are
unchanged. Registration makes an existing validated route discoverable; it is
not a new numerical-parity claim.

## Registered resources

| Resource | Value |
|---|---|
| Model | `slip_quadruped` |
| Workflow | `roadmap_root_continuation` |
| Problem | `periodic_apex` (`validated`, `source-equivalent`) |
| Data source | `roadmap` through `RoadMapDataSourceProvider` |
| Default dataset | `PK_20_2` |
| Default point | `267` |
| RoadMap inventory | 9 branches, 3,443 points |
| Source data SHA-256 | `45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401` |
| Source repository commit | `2c106101383ecee1b2a9d695efe09fbd72d5718a` |
| Axis preset | `roadmap_top`: X=`dx`, Y=`dphi`, Z=`y`, 2-D top view |
| Axis limits | X `[0,10]`, Y `[-0.05,0.15]`, Z `[0.6,1.2]` |
| Visualization | `research_legacy` |
| Layout | `scientific_workbench` |
| First seed | locked RoadMap point |
| Second seed | adjacent next by default; adjacent previous and generated/corrected are available |
| Generated radius | `0.005` in the problem chart |
| Continuation direction | `both` by default |
| Direction labels | backward=`decreasing dx`, forward=`increasing dx` |

The descriptor also enables nearby active-parameter homotopy, a RoadMap family
scan, checkpoints, and the physical/trajectory/GRF/oscillator analysis views.
It records its own source path and digest in addition to the scientific data
provenance.

Two companion descriptors use the same provider:

- `roadmap_explore` limits the workflow to loading, selection, simulation, and
  analysis; and
- `touchdown_root_continuation` transfers the apex solution to the
  `back_left_touchdown` periodic-orbit section before solve and section-local
  seed construction. It is `experimental`/`tested`, not source-equivalent.

## GUI route

1. Run `app = legged_model_zoo;`.
2. Select **SLIP Quadruped**, then choose **RoadMap apex-root continuation** in
   **Workflow**. A fresh application selects the first registered scientific
   root/continuation workflow when available.
3. Keep **Scientific workbench** in **Layout**. The nine RoadMap datasets can
   be loaded from the registered data selector; the workflow initializes
   `PK_20_2`, point 267, with the `roadmap_top` axes.
4. Hover to preview. Click a branch point or use the index/percentage controls
   to lock it. Hover does not replace the locked selection.
5. Inspect **Info / Selection**. The same locked point supplies the working
   solution in Visualization, Solve / Seeds, Continuation, and analysis.
6. In **Solve / Seeds**, evaluate or refine. The published default is already
   below the acceptance tolerance, so the solve lifecycle records
   `seed_selected`, `seed_evaluated`, and `solve_completed` with zero numerical
   iterations. A perturbed seed produces live iteration snapshots. Seed,
   prediction, and corrected-solution markers share the branch axes.
7. Build an **Adjacent next** pair (267/268), **Adjacent previous**, or a
   generated/corrected second seed. Pair validation checks model/problem,
   parameters, finite values, residual, gait policy, and chart separation.
8. In **Continuation**, choose **Both directions** (the registered default), a
   bounded total point count, and optional checkpoint path. The live predictor
   and rejected points remain on the persistent RoadMap canvas; one accepted-
   continuation layer grows during execution and is replaced in place by the
   final or stopped partial branch as the sidebar task changes.
9. Pause/resume or request a controlled stop as needed. Resume a compatible
   atomic checkpoint through the existing continuation service/controller.
10. Save the native result/artifact. Use the model-owned legacy adapter only
    when an exact Results29 export is required.

The status dock remains visible and reports current solve/continuation stage,
progress, residual, step/direction information, output/checkpoint path, and
copyable diagnostics.

## Programmatic route

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
workflowRegistry = lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
descriptor = workflowRegistry.get( ...
    'slip_quadruped', 'roadmap_root_continuation');

context = lmz.api.RunContext.synchronous(1401);
session = lmz.workflow.WorkflowRunner().initialize(descriptor, context);

assert(session.SeedIndex == 267);
initialResidual = session.InitialEvaluation.ScaledResidualNorm;

solveResult = session.solve(struct());
adjacent = session.makeAdjacentSeedPair(+1, struct());

continuationResult = session.continueBranch(struct( ...
    'MaximumPoints', 20, ...
    'DirectionMode', 'both', ...
    'InitialStep', adjacent.AchievedRadius));

workflowResult = session.result();
```

Use `session.makeGeneratedSeedPair([],struct())` to apply the registered
radius and generic correction route. Use `DirectionMode='forward'` or
`'backward'` for a single direction. `MaximumPoints` is the total returned
branch size when both directions are requested.

Atomic checkpoint/resume is explicit:

```matlab
checkpoint = fullfile(tempdir, 'quadruped-reference-checkpoint.lmz.mat');
partial = session.continueBranch(struct( ...
    'MaximumPoints', 6, ...
    'DirectionMode', 'both', ...
    'InitialStep', adjacent.AchievedRadius, ...
    'CheckpointPath', checkpoint));
resumed = session.resumeCheckpoint(checkpoint, struct('MaximumPoints', 7));
```

Do not edit a checkpoint or reuse it with a different problem/configuration.
The service verifies the stored contract and reconstructs lifted timing history
and adaptive continuation state.

Run the public end-to-end example:

```matlab
run('examples/demo_registered_slip_quadruped_workflow.m')
```

## Evidence and interpretation

The pinned default RoadMap point has a scaled residual of approximately
`2.91e-11`. The existing-seed solve is accepted with a positive exit flag and
no numerical iteration. Focused Round 11 tests verify:

- descriptor identity, source commit/hash, axis/graphics/layout bindings, seed
  policies, direction labels, and analysis views;
- initialization at point 267 from the registered provider;
- accepted-existing-seed solve;
- adjacent source indices 267/268;
- a corrected generated seed at the registered radius;
- distinct forward and backward continuation movement in `dx`;
- a six-point both-direction run with accepted callbacks from both signs;
- an atomic checkpoint, resume to seven points, and native artifact round
  trip; and
- touchdown section transfer plus a local adjacent pair.

The source-oriented workflow and layout comparisons are recorded separately in
[quadruped-workflow-parity.md](quadruped-workflow-parity.md) and
[quadruped-gui-layout-map.md](quadruped-gui-layout-map.md). Passing numerical
tests does not imply pixel-identical GUI appearance. Automated layout/image
evidence does not imply human desktop approval.

The historical Round 10 aggregate remains 544/544 at committed HEAD
`5c6a6c100f752ea6ed1fd20114f84800f9b52070`. Round 11 final aggregate,
examples, clean-copy, coverage, quality, static compatibility, performance, and
packaging evidence must be recorded only after those commands complete.
Redistribution authority, remote CI, human desktop QA, and R2019b runtime remain
separate external gates.
