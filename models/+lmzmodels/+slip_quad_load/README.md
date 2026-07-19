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

## GUI and visualization

Select **SLIP Quadruped with Load** in `legged_model_zoo`. The scientific
dataset selector loads one/all built-ins without a file dialog. The inspector
groups first-stride state/events/parameters/load values and later-stride
events/post-swing values. **Simulate candidate** dispatches to
`QuadLoadRenderer` and `QuadLoadPlotProvider` for footfalls, body/legs, load,
GRFs, tugline, sensitivity, and R-squared views. **Run fit** uses a bounded
responsive configuration; **Cancel fit** requests a controlled stop.

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
```

Each is rerunnable, uses public APIs/repository data, and prints an exact
success marker.

## Provenance and redistribution

The audited source commit is
`19f3133073c988cc0c3424a647b4adbb60a90b99`. Its README claims BSD 3-Clause,
but the linked license file is absent from that commit, and data coverage is
not defined. Public packaging remains blocked pending the owner decision in
`docs/REDISTRIBUTION_STATUS.md`; do not infer a license from the local copy.
