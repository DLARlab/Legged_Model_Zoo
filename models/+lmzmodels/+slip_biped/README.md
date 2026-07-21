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

## Direct mixed-section shooting

Use `section_transition` for distinct biped section IDs. The registered route
supports named-event, descending state-plane, and safe composite endpoints. It
owns the start-section coordinates and schedule, integrates the biped adapter
directly, and compares the terminal node with an explicit target. The source
apex orbit initializes a fresh contract once and is not called during residual
evaluation.

```matlab
transition = model.createProblem('section_transition',struct( ...
    'StartSectionId','left_touchdown', ...
    'StopSectionId','descending_y_0_95', ...
    'StartStateFreeMask',true, ...
    'TargetStateFreeMask',true, ...
    'EventFreeMask',false));
u0 = transition.getDecisionSchema().defaults();
p = transition.getParameterSchema().defaults();
context = lmz.api.RunContext.synchronous(42);
evaluation = transition.evaluate(u0,p,context,false);
direct = transition.evaluateShooting(u0,p,context,false);

assert(strcmp(transition.Formulation,'transition'));
assert(~transition.Horizon.Target.PeriodicClosure);
assert(evaluation.PhysicalValidity);
assert(direct.SegmentResults{1}.Crossing.Accepted);
assert(direct.SegmentResults{1}.Crossing.CrossingDirection == -1);
assert(~direct.SegmentResults{1}.Diagnostics.ApexOracleUsed);
```

The default left-touchdown-to-descending-plane seed is a 13-decision,
14-residual direct transition with scaled residual norm
`1.876276911616515e-14`. The reverse plane-to-right-touchdown path reaches an
accepted transverse crossing but retains contact residual
`0.04299363542136695`; left-to-right touchdown similarly retains
`0.04299360548669684`. Those two are candidates, not root claims. The safe
left-touchdown composite target has residual `1.299946006845806e-13`.

Residual diagnostics keep
`segment_1_contact_constraints`, `segment_1_section_residual`,
`interface_1_defect`, and `final_transition_target` separate. There is no
`final_section_closure`. Use `periodic_orbit` or `multiple_shooting` for a
same-section periodic request. See `docs/scientific-section-shooting.md` for
the full pair matrix, mask semantics, and crossing qualifications.

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

The manifest visualization contract declares `world`, `body`, `foot_left`, and
`foot_right` as named frames and declares no required parameter roots. The
graphics configuration repeats that frame requirement. Registry discovery
binds it to the manifest and validates any declared profile scene before a
renderer can be selected; biped research geometry consumes named states,
contacts, and event metadata at runtime rather than raw state-vector indices in
configuration.

The model owns three declared profiles in
`catalog/slip_biped/graphics.lmz.json`:

| Profile | Default/applicability | Renderer | Meaning |
| --- | --- | --- | --- |
| `research_legacy` | Default for validated `periodic_apex` and `trajectory_fit` | `lmzmodels.slip_biped.ResearchRenderer` | Source-derived compound geometry and camera |
| `clean_generic` | Default for tutorial `demo_stride`; selectable for all maturities | `lmzmodels.slip_biped.BipedRenderer` | Simple point/straight-link presentation; not source-faithful |
| `high_contrast` | Selectable for declared maturities | `lmzmodels.slip_biped.ResearchRenderer` | Compound research geometry with deliberately changed colors/widths |

The GUI resolves this table by problem maturity. In **Physical Simulation**,
choose a **Visual profile**, then optionally change ground visibility and camera
follow. The detailed and force controls have no source overlay to reveal in the
biped research renderer. A profile change safely rebuilds the renderer and the
per-model/problem choice is retained in GUI preferences.

### Research graphics mapping

The source animation path constructs
`SLIP_Model_Graphics_PointFeet_BipedalDemo`, interpolates each display state,
and calls `update(state,eventTimes,time)`. LMZ keeps the interpolation/playback
loop in `AnimationController` and maps the geometry as follows:

| Source graphics behavior | LMZ owner |
| --- | --- |
| Radius-0.2 white circular body, black width-5 outline | `ResearchBodyGeometry` |
| Four alternating radius-0.1 COG sectors | `ResearchCOGGeometry` |
| Left/right spring, upper patch, lower shaped patch, and point foot | `ResearchLegGeometry` |
| Strict wrapped contact and stance length `y/cos(alpha)`; flight length 1 | `ResearchLegGeometry` |
| White ground mask and dense hatch | `ResearchGroundGeometry` |
| Left leg behind ground/body; right leg above body; COG topmost | `ResearchRenderer` handle creation order |
| Equal axes, x-follow half-width 1.5, y `[-0.3,2]` | profile/style plus `ResearchRenderer` |

The blue spring edge is `[0 68 158]/256`; the left leg fill is
`[202 202 202]/256`; the right leg remains white. The research renderer uses
the event schedule when present and the named contact modes as a fallback. It
builds axes children once and updates vertices only.

### Qualified differences

- The old renderer's figure ownership, `pause` loop, second recording figure,
  MPEG-4 writer, and interpolation are intentionally replaced by shared LMZ
  animation/recording services.
- Source patches that inherited MATLAB defaults are assigned explicit black
  outlines/ground styling so output is deterministic across releases.
- Primary leg fixtures use the source post-update geometry. This intentionally
  ignores the transient constructor-only left/right lower-width discrepancy
  that the source setter immediately overwrites.
- The audited source path plots eight state columns and left/right vertical GRF.
  The research plot profile preserves source-style labels and limits the GRF
  view to those two vertical channels. LMZ's normalized footfall, energy, and
  gait views remain useful modern enrichments and are marked as such; the clean
  plot profile retains the broader magnitude/horizontal/vertical GRF view.
- `high_contrast` changes palette and line widths by design and therefore is not
  a source-palette claim.

### Programmatic rendering and recording

The public helper loads the recommended walking branch, simulates
`periodic_apex`, resolves the selected profile, and creates a hidden or visible
classic-axes session:

```matlab
session = lmz.examples.ResearchGraphics.open( ...
    'slip_biped', 'research_legacy', 'off');
cleanup = onCleanup(@() lmz.examples.ResearchGraphics.close(session));
summary = lmz.examples.ResearchGraphics.renderFrames( ...
    session, [0 0.25 0.5 0.75 1]);
```

Record the selected renderer and include the resolved profile in the adjacent
sidecar:

```matlab
target = fullfile(tempdir, 'biped-research.gif');
metadata = struct('schemaVersion', '1.0.0', ...
    'modelId', session.ModelId, 'problemId', session.ProblemId, ...
    'visualizationProfile', session.Profile.toStruct());
lmz.services.RecorderService().recordGif(session.Renderer, target, ...
    struct('FrameCount', 40, 'DelayTime', 1/30, ...
    'Metadata', metadata));
```

The GUI applies profile recording defaults and writes profile sidecars for its
animation, keyframe, plot, and oscillator exports. Direct recorder calls must
pass metadata explicitly.

Numeric body/COG/left-leg/right-leg/contact/ground fixtures live under
`tests/fixtures/graphics/slip_biped`; renderer and geometry tests live under
`tests/visualization`. The detailed source/file/formula record is in
`docs/legacy-graphics-audit.md`. Hidden rendering is not a completed human
side-by-side review. R2019b is a static compatibility target only; graphics
runtime evidence was collected on the documented newer MATLAB release.

Repository examples are:

```text
demo_slip_biped_gaitmap_workflow.m
demo_slip_biped_solve.m
demo_slip_biped_continuation.m
demo_slip_biped_trajectory_fit.m
demo_biped_research_graphics.m
demo_visual_profile_switching.m
demo_research_graphics_recording.m
demo_graphics_comparison_gallery.m
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
