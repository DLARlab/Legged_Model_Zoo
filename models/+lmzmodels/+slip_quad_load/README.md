# Scientific SLIP quadruped-with-load usage

`slip_quad_load/single_stride` and `slip_quad_load/multi_stride_fit` are the
source-equivalent load-pulling problems. The separate `demo_stride` problem is
an analytic tutorial and is labeled `tutorial • tested` in the registry/GUI.
Run `startup` once from the repository root before using these APIs.

## Built-in data

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quad_load');
catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();

singleData = catalog.load('individual_1_tr_single');
multiData = catalog.load('individual_1_tr_to_rl');
```

The single-stride file contains 44 decisions. The transition contains 57
decisions (two strides). `dataset_manifest.json` records their source paths,
commit, SHA-256 digests, stride counts, dimensions, and native artifact paths.
Normal runtime and tests use only this repository.

## Exact decision layout

The first stride is always:

```text
1:13   quadruped state
        dx, y, dy, phi, dphi,
        alphaBL, dalphaBL, alphaFL, dalphaFL,
        alphaBR, dalphaBR, alphaFR, dalphaFR
14:22  tBL_TD, tBL_LO, tFL_TD, tFL_LO,
        tBR_TD, tBR_LO, tFR_TD, tFR_LO, tAPEX
23:36  leg stiffness; four pre- and four post-contact swing stiffnesses;
        torso inertia, leg length, swing-neutral angle,
        back attachment ratio, back/front stiffness ratio
37:38  load x, load dx
39:44  load height, mass, friction, tugline rest length/stiffness, slope
```

Every later stride adds nine event times and four post-contact swing
stiffnesses. Therefore:

```matlab
expectedLength = 44 + 13 * (strideCount - 1);
decoded = lmzmodels.slip_quad_load.XAccumAdapter.decode(multiData.XAccum);
assert(decoded.StrideCount == 2);
assert(isequal(lmzmodels.slip_quad_load.XAccumAdapter.encode(decoded), ...
    multiData.XAccum));
```

The simulation state is separate and contains 18 named values: 14 quadruped
states followed by load `x`, `dx`, `y`, and `dy`.

## Single-stride simulation

```matlab
context = lmz.api.RunContext.synchronous(0);
single = model.createProblem('single_stride', ...
    struct('DatasetPath', catalog.defaultSinglePath()));
evaluation = single.evaluate(singleData.XAccum, ...
    single.getParameterSchema().defaults(), context, true);
simulation = evaluation.Simulation;
```

The evaluation has 27 residual entries grouped as contact geometry, apex,
tugline/load periodicity, and quadruped periodicity. The simulation contains
strictly increasing time, nine event records, contact modes, all 12 GRF
channels, tugline force, per-stride parameters, and physical kinematics.

## Multi-stride simulation and objective

```matlab
fit = model.createProblem('multi_stride_fit', ...
    struct('DatasetPath', catalog.defaultMultiPath(), ...
    'InitialPerturbation', 0));
simulation = fit.simulateDecision(multiData.XAccum, context);
[objective, terms, diagnostics] = fit.evaluateObjective( ...
    multiData.XAccum, fit.getParameterSchema().defaults(), context);
```

The named terms are stride-duration mismatch, footfall-timing mismatch, and
normalized loading-force mismatch. Diagnostics retain the composite,
per-stride parameters, residuals, and R-squared values. Constant target/source
series and zero total weight are handled explicitly and reported in
`R2Diagnostics`, so degenerate cases remain finite and auditable.

## Bounded fitting

The full 57-entry decision is the public schema and artifact format. For the
built-in transition, only later-stride post-contact swing stiffnesses (indices
54–57) are free; exact equal bounds fix every other source-prescribed entry.
The generic `FminconSolver` automatically solves the four-entry free subvector
and reconstructs the full vector for each objective/constraint call.

```matlab
seed = fit.makeSolution(fit.sourceSeed(), ...
    fit.getParameterSchema().defaults(), []);
options = struct('Algorithm','sqp','MaxIterations',1, ...
    'MaxFunctionEvaluations',30,'OptimalityTolerance',1e-5, ...
    'StepTolerance',1e-5);
result = lmz.services.OptimizationService().run( ...
    fit, seed, options, context);
assert(numel(result.Solution.DecisionValues) == 57);
assert(isequal(result.Output.freeVariableIndices, (54:57).'));
```

This short configuration is a deterministic objective-decrease regression,
not a global-optimum claim. Increase the iteration/evaluation limits for an
actual fitting study and retain the resulting options/seed in the artifact.

## Round 9 fixed-schedule and requested-N workflows

`multi_stride_fit` above is the exact two-stride legacy oracle. Its preserved
source timing projection is explicit in diagnostics as
`TimingMode='legacy_source_timing_projection'` and `HiddenTimingSolve=true`.
Use the separate experimental `n_stride_fit` problem when timing must remain a
fixed input to the objective:

```matlab
fixed = model.createProblem('n_stride_fit',struct());
u = fixed.getDecisionSchema().defaults();
p = fixed.getParameterSchema().defaults();
[objective,fixedTerms,fixedDiagnostics] = ...
    fixed.evaluateObjective(u,p,context);
[c,ceq] = fixed.nonlinearConstraints(u,p,context);
assert(isfinite(objective));
assert(isempty(c) && numel(ceq) == 18);
assert(~fixedDiagnostics.HiddenTimingSolve);
```

The default is a hash-bound corrected two-stride timing seed captured in this
repository; no timing service runs inside the objective. For `N>2`, supply a
complete `44 + 13*(N-1)` vector/plan and explicitly set
`ReferenceExtensionPolicy='repeat_final_reference'`. The repeated reference is
synthetic. Repeating the final 13-entry block gives a 70-decision,
27-constraint three-stride schema demonstration, not a validated timing seed
or source-equivalent fit.

A five-stride `carry_forward` plan similarly demonstrates the exact 96-entry
layout only. With the bundled two-stride seed, public predictor-corrector
simulation returns a structured partial `2/5` failure at stride 3 with
`lmz:MultiStride:TimingSeedOutsideTrustRegion` and no simulation. See
[`demo_quad_load_extend_to_five_strides.m`](../../../examples/demo_quad_load_extend_to_five_strides.m),
[`demo_quad_load_n_stride_fit.m`](../../../examples/demo_quad_load_n_stride_fit.m),
and [`docs/multi-stride-planning.md`](../../../docs/multi-stride-planning.md).

## Round 10 multiple shooting and horizon feasibility

Use `multiple_shooting_horizon` when schedules and intermediate section states
must be corrected jointly. Unlike the legacy requested-N path, this problem
simulates each stride separately and retains named contact, interface-defect,
section, and energy/work residual blocks.

Inspect the repository-contained, hash-bound template library first:

```matlab
library = lmzmodels.slip_quad_load.StrideTemplateLibrary();
records = library.records();
assert(numel(records) == 4);
assert(all(arrayfun(@(item)library.validateHash(item.id), records)));

template = library.load('individual_1_tr_to_rl', context);
assert(template.StrideCount == 2);
```

The inventory contains one 44-entry single-stride template and three 57-entry
two-stride transition templates. `template_manifest.json` stores each SHA-256,
source path, byte count, gait label, pinned source commit, and the unresolved
redistribution qualification.

Construct and inspect a three-stride shooting problem through the public model
route:

```matlab
configuration = struct( ...
    'NumberOfStrides', 3, ...
    'Formulation', 'feasibility', ...
    'EnergyMode', {{'diagnostic_only','diagnostic_only','diagnostic_only'}}, ...
    'FreeControlMask', false(3,4));
problem = model.createProblem('multiple_shooting_horizon', configuration);
decision = problem.getDecisionSchema().defaults();
report = problem.analyze(decision, context, struct('ComputeJacobian', false));
```

For a new numerical study, call `problem.solveFeasibility(options,context)` and
archive the seed, bounds, solver options, residual blocks, rank diagnostics,
and termination reason. A solver exit by itself is not a physical-root claim;
`report.RootFound` also requires every configured residual tolerance, accepted
crossings, event ordering, and finite physical states.

The frozen Round 10 searches can be replayed without rerunning the expensive
multistarts:

```matlab
evidence = lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
n2 = evidence.replay('n2_transition_feasibility_root', context, false);
fixed = evidence.replay('case_a_fixed_controls_best_known', context, false);
neutral = evidence.replay( ...
    'case_b_energy_neutral_controls_best_known', context, false);
periodic = evidence.replay('n2_periodic_best_known', context, false);
relaxedFive = evidence.replay( ...
    'n5_stride_boundary_bounded_work_best_known', context, false);

assert(n2.RootFound);
assert(~fixed.RootFound && ~neutral.RootFound && ...
    ~periodic.RootFound && ~relaxedFive.RootFound);
```

The recorded scaled norms are:

| Search | Scaled residual norm | Qualification |
| --- | ---: | --- |
| N=2 transition/contact-interface solve | `7.978014164613411e-13` | `root_found`; 46 rows/46 unknowns, rank 46/nullity 0; periodic closure is not present |
| Case A, N=3 fixed controls | `0.7136044533002278` | `physical_validation_failure`; 69/69, rank 69/nullity 0; third-segment minimum quadruped height is `-0.1445449620598354` |
| Case B, N=3 four free post-swing controls with energy-neutral row | `0.7217887917287552` | `physical_validation_failure`; 70/73, rank 70/nullity 3; third-segment minimum quadruped height is `-0.1457310619145955` |
| Distinct N=2 periodic solve | `2.8172762892858283` | `numerical_failure`; exit 0/evaluation limit; 60/46, rank 46/nullity 0; not a periodic root |
| Separate N=5 stride-boundary bounded-work search | `0.3086908931991573` (maximum `0.11470808666193932`) | `numerical_failure`; exit 0/evaluation limit; 119/119, rank 112/nullity 7; physical candidate, no root or simulation |

These searches do not prove global nonexistence. Because neither N=3 apex
search found a physically valid root, the requested physical 2 -> 3 -> 4 -> 5
continuation stopped at N=3; its N=4/N=5 layouts remain structural
initializations only. No failed case publishes a synthetic simulation. The
Case B nullity is a diagnostic at one unresolved candidate, not evidence of a
regular three-dimensional solution family; no gauge, family chart, or
continuation was run for it.

The separate N=5 relaxation changed the stop section to `stride_boundary`,
used bounded work with an absolute bound of 100, and tested exactly one freed
post-swing control column per transition. All four final candidates passed the
recorded finite-state, crossing, and event-order checks, with norms
`[0.5020299292493873, 0.5264091136970379, 0.3086908931991573,
0.39091176213603607]`; none met residual tolerance or acceptable solver
termination. “Minimal” here means the smallest tested control-cardinality,
not a proven globally minimal relaxation. This search is not physical
continuation from validated N=3/N=4 roots and publishes no simulation.

Continue a known decision across explicit dimension changes with the
model-owned continuation helper:

```matlab
[~, n2Decision] = evidence.problemFor('n2_transition_feasibility_root');
continuation = lmzmodels.slip_quad_load.QuadLoadHorizonContinuation();
configuration = struct( ...
    'StartStrideCount', 2, ...
    'TargetStrideCount', 5, ...
    'InitialCompletedPhysicalStrideCount', 2, ...
    'EnergyMode', 'diagnostic_only', ...
    'InitialDecisionForContinuation', n2Decision);
structural = continuation.continueTo(configuration, ...
    struct('SolveEachHorizon', false), context);

assert(structural.CompletedStrideCount == 5);
assert(structural.CompletedPhysicalStrideCount == 2); % replayed valid N=2 seed
checkpoint = structural.Checkpoints{1};
resumed = continuation.resume(checkpoint, ...
    struct('SolveEachHorizon', false), context);
```

Set `SolveEachHorizon=true` for anchored adaptive homotopy and supply solver
limits through `FeasibilityOptions`. The continuation records accepted and
rejected lambda attempts, backtracking, rank/condition diagnostics, embedding
maps, checkpoints, and the last physically validated horizon. Stopping or
resuming never silently changes the decision dimension.

For a fixed-dimension local family, start from the same physical N=2 transition
root, explicitly embed its 46 decisions into a problem that frees only
`segment_2_post_swing_1`, and declare `ExpectedLocalDimension=1`. The measured
Jacobian rank is 46, and the corrected three-point branch stays on one
47-variable multiple-shooting chart. The executed stiffness values are
`[25.881221830170297, 25.880923234958146, 25.88062464009689]`, with maximum
scaled residuals no larger than `5.657696533489798e-12`. Run
[`demo_quad_load_horizon_continuation.m`](../../../examples/demo_quad_load_horizon_continuation.m)
for the recorded configuration, embedding, chart hash, physical checks,
history, and reproducible artifact.

This is a nearby local family of the N=2 transition root under
`EnergyMode='diagnostic_only'`. It is not an N=2 periodic result, an
energy-neutral family, or evidence that a physical N=3 or N=5 horizon exists.

## Direct load section timing

The load model supports direct apex, stride-boundary, and post-event back-left
touchdown-to-touchdown propagation. The residual evaluator starts at the
selected section state; it does not simulate apex-to-apex and relabel an
interior sample. Mixed touchdown/apex pairs, pre-touchdown states, and other
touchdown identities reject explicitly.

```matlab
timingProblem = model.createProblem('section_return_timing', struct( ...
    'StartSectionId', 'apex', ...
    'StopSectionId', 'stride_boundary', ...
    'FixReturnTime', true, ...
    'FixedRowPolicy', 'validate_fixed_rows'));
timing = lmz.services.ContactTimingService().solve( ...
    timingProblem, timingProblem.InputSchedule, ...
    struct('Display','off','ResidualTolerance',1e-8), context);
assert(timing.SolverDiagnostics.Success);
assert(timing.SolverDiagnostics.RankDiagnostics.Rank == 8);
```

The preserved 44-entry source decision accepts initial `load_x` and `load_dx`
but not initial `load_y` or `load_dy`. The section codec therefore keeps all
four values in the full physical state and catalog while exposing only the two
source-supported load coordinates as decision/terminal chart entries. The
omitted names and their initial/terminal values are explicit in adapter
diagnostics under `SourceFixedCoordinateNames`,
`SourceFixedInitialCoordinates`, and `SourceFixedTerminalCoordinates`.

Complete equations, classifications, evidence, and continuation usage are in
[`docs/quad-load-horizon-continuation.md`](../../../docs/quad-load-horizon-continuation.md)
and [`docs/horizon-feasibility.md`](../../../docs/horizon-feasibility.md).

## GUI and visualization

Select **SLIP Quadruped with Load** in `legged_model_zoo`. The scientific
dataset selector loads one/all built-ins without a file dialog. The inspector
groups first-stride state/events/parameters/load values and later-stride
events/post-swing values. **Simulate candidate** dispatches through
`RendererFactory` and `QuadLoadPlotProvider` for animation, footfalls,
body/legs, load, GRFs, and tugline views. **Run fit** uses a bounded responsive
configuration; **Cancel fit** requests a controlled stop.

For the separate Round 10 shooting workflow, choose
`multiple_shooting_horizon` in the header and open **Solve / Seeds**. Use
**Multiple shooting** or **Horizon feasibility**, then set the horizon,
residual tolerance, solver, event/return rows, interface/control masks, energy
mode, and initializer. The shooting section must be homogeneous:
apex-to-apex uses a 14-coordinate interface mask, while
stride-boundary-to-stride-boundary uses 15 coordinates because `quad_dy` is
present. **Interfaces** and **Controls** accept `all`, `none`, or comma-/space-
separated `0/1` values; load controls have four post-swing stiffness entries
per stride. Apex-to-stride-boundary belongs to **Contact timings only** and is
explicitly unsupported as a relabeled homogeneous shooting horizon.

The initializer menu exposes the source-backed IDs
`individual_1_tr_to_rl`, `individual_1_identical_tr_to_rl`,
`individual_1_tr_to_tl`, and `individual_1_tr_single`, plus the derived
`phase_compatible_repeat` strategy. Source files are SHA-256 checked before
use, and saved shooting artifacts bind the selected template path/hash, any
evidence path/hash declared by a replay configuration, initializer lineage,
and the full problem configuration. Inspect the
classification, rank/nullity, physical checks, residual table, and horizon
profiles after **Solve/refine**; a positive exit flag is insufficient.
**Simulate solved** remains disabled because this experimental problem declares
`simulate=false` and never fabricates a complete trajectory from a failed or
partial horizon. The main [Round 10 GUI and programmatic usage
guide](../../../README.md#use-multiple-shooting-in-the-gui) includes exact
mask coordinates, energy-mode semantics, artifact reproduction, checkpoint
resume, and error interpretation.

The manifest visualization contract declares the semantic frames `world`,
`quadruped_center_of_mass`, `load_center`, and `ground_contact`. Its required
parameter roots are exactly `per_stride_parameters`, `quadruped`, and `load`;
the same root names appear in `graphics.lmz.json.requiredParameters`. They are
top-level `SimulationResult.Parameters` containers, not nested scalar names.
Registry discovery binds both required-name lists to the manifest before any
profile is used, while the custom renderers/providers remain responsible for
validating the runtime contents of those containers.

The model owns three visual profiles:

| Profile | Default/applicability | Renderer | Meaning |
| --- | --- | --- | --- |
| `research_legacy` | Default for validated `single_stride` and `multi_stride_fit` | `lmzmodels.slip_quad_load.ResearchRenderer` | Source-derived quadruped/load animation and research plot profile |
| `clean_generic` | Default for tutorial `demo_stride`; selectable for all maturities | `lmzmodels.slip_quad_load.QuadLoadRenderer` | Simple body/legs/load/line-rope view; not source-faithful |
| `high_contrast` | Selectable for validated problems | `lmzmodels.slip_quad_load.ResearchRenderer` | Compound research geometry with deliberately changed palette/widths |

In **Physical Simulation**, choose **Visual profile** before recording. The
preference is stored for `slip_quad_load/<problem-id>`. Ground visibility and
camera follow apply to the research renderer. Its source animation has no force
arrows or quadruped phase diagram, so **Forces** and **Detailed** do not add
those overlays. **Reset camera** restores the profile framing.

## Research graphics mapping

The load renderer composes the quadruped source geometry instead of copying it:

| Source graphics behavior | LMZ owner |
| --- | --- |
| Compound quadruped body, four six-part legs, COM, and hatched ground | `lmzmodels.slip_quadruped.Research*Geometry` |
| Load patch `[x-y,x+y,x+y,x-y]` by `[0,0,2y,2y]` | `ResearchLoadGeometry` |
| Four-vertex zero-area rope patch with duplicated body/load endpoints | `ResearchRopeGeometry` |
| Per-frame stride row and exact-boundary-later selection | `ActiveStrideParameterSelector` |
| Left legs, ground, body/COM, right legs, load, rope | `ResearchRenderer` handle order |

The source load and rope are black with alpha `0.3`, black edge, and line width
2. The rope remains visible even when unilateral tugline force is zero; its
appearance is geometry, not a tension indicator. The camera follows quadruped
x with offsets `[-3,1.5]`, fixes y to `[-0.1,2]`, uses plot-box aspect
`[2,1,1]`, hides rulers, and retains the title `SLIP Quad-Load Animation`.

For a transition, the source caller switches from row 1 to row 2 exactly at the
first apex boundary. LMZ preserves that later-row-at-boundary behavior and
generalizes it to N rows using cumulative stride ends. The selected row's event
times are offset by all preceding durations; rest length and back attachment
ratio used by geometry therefore change at the same frame as the active stride.

## Research analysis plots

`QuadLoadPlotProvider` accepts the resolved profile. The research plot profile
provides:

- normalized-stride leg angular velocities in BL, FL, FR, BR ordering;
- source-style footfall patches and optional experimental event ranges;
- simulated tugline force plus optional experimental mean/deviation data;
- relative sensitivity curves and the optional sorted percentage bar view; and
- source-style numeric R-squared readouts.

The source footfall implementation's actual simulated patch colors disagree
with its dummy legend. LMZ preserves and annotates that observed behavior rather
than silently calling both mappings equivalent. A one-axes sensitivity call
omits and annotates the source's second sorted-bar axes. The consolidated
R-squared readout is an LMZ layout adaptation because the source stores numeric
fields rather than a reusable R-squared plot class. Clean-profile plots retain
the modern broader views.

## Qualified source differences

- Old global figure construction, axes-position handling, playback loops, and
  output ownership are replaced by shared axes/animation/recording services.
- The literal two-stride source switch is generalized to N strides while
  retaining its boundary convention.
- The compound quadruped provider freezes release-dependent dark edges as
  explicit black.
- `high_contrast` deliberately changes load/rope and quadruped colors/widths;
  it is not a source-palette claim.
- `clean_generic` uses a marker-like load and simple line rope by design and is
  not a source geometry reference.

## Programmatic rendering and recording

The public helper loads the repository transition, simulates
`multi_stride_fit`, resolves the profile, and renders through the factory:

```matlab
session = lmz.examples.ResearchGraphics.open( ...
    'slip_quad_load', 'research_legacy', 'off');
cleanup = onCleanup(@() lmz.examples.ResearchGraphics.close(session));
summary = lmz.examples.ResearchGraphics.renderFrames( ...
    session, [0 0.33 0.5 0.67 1]);
```

Record the selected renderer with an adjacent metadata sidecar:

```matlab
target = fullfile(tempdir, 'quad-load-research.gif');
metadata = struct('schemaVersion', '1.0.0', ...
    'modelId', session.ModelId, 'problemId', session.ProblemId, ...
    'visualizationProfile', session.Profile.toStruct());
lmz.services.RecorderService().recordGif(session.Renderer, target, ...
    struct('FrameCount', 40, 'DelayTime', 1/20, ...
    'Metadata', metadata));
```

The GUI seeds applicable frame-count/FPS/DPI options from the profile and writes
profile sidecars for animation, keyframe, plot, and oscillator exports. Direct
service calls must provide profile metadata explicitly; operational options may
be supplied or left to service defaults. The recorder restores the original
frame and cleans temporary files; the renderer never owns an animation or
recording loop.

Numeric quadruped-composition, load, rope, and stride-boundary fixtures live
under `tests/fixtures/graphics/slip_quad_load`; the geometry, renderer, plot,
and profile tests are under `tests/visualization`. The exact audited mapping and
qualifications are in `docs/legacy-graphics-audit.md` and
`docs/graphics-fidelity-map.csv`. Hidden rendering is not human approval, and
the desktop side-by-side review remains a separate manual gate. R2019b remains
a static compatibility target; graphics runtime evidence comes from the
documented newer MATLAB release.

## Save and exact export

```matlab
lmz.io.ArtifactStore.save('load-fit.lmz.mat', result.toArtifact());
restored = lmz.io.ArtifactStore.load('load-fit.lmz.mat');
lmzmodels.slip_quad_load.XAccumAdapter.exportLegacy( ...
    'load-source.mat', multiData);
```

Native artifacts retain dataset/model/problem identity, maturity and
validation status, exact schemas, source commit, objective/R-squared
diagnostics, solver options, and free/fixed indices. Legacy export recreates
`X_accum` and the source dataset fields managed by the adapter.

## Executable examples

```text
demo_slip_quad_load_single_stride.m
demo_slip_quad_load_multi_stride.m
demo_slip_quad_load_fit.m
demo_slip_quad_load_scientific.m
demo_quad_load_research_graphics.m
demo_quad_load_extend_to_five_strides.m
demo_quad_load_n_stride_fit.m
demo_quad_load_template_library.m
demo_quad_load_three_stride_feasibility.m
demo_quad_load_five_stride_horizon.m
demo_quad_load_horizon_continuation.m
demo_quad_load_n2_periodic_solve.m
demo_n_stride_periodic_orbit.m
demo_visual_profile_switching.m
demo_research_graphics_recording.m
demo_graphics_comparison_gallery.m
```

Each is rerunnable, uses public APIs/repository data, and prints an exact
success marker.

## Provenance and redistribution

The audited source commit is
`19f3133073c988cc0c3424a647b4adbb60a90b99`. Its README claims BSD 3-Clause,
but the linked license file is absent from that commit, and data coverage is
not defined. Public packaging remains blocked pending the owner decision in
`docs/REDISTRIBUTION_STATUS.md`; do not infer a license from the local copy.
