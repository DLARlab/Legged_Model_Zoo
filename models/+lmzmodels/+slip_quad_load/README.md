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

## GUI and visualization

Select **SLIP Quadruped with Load** in `legged_model_zoo`. The scientific
dataset selector loads one/all built-ins without a file dialog. The inspector
groups first-stride state/events/parameters/load values and later-stride
events/post-swing values. **Simulate candidate** dispatches through
`RendererFactory` and `QuadLoadPlotProvider` for animation, footfalls,
body/legs, load, GRFs, and tugline views. **Run fit** uses a bounded responsive
configuration; **Cancel fit** requests a controlled stop.

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
