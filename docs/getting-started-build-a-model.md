# Getting started: build a legged model

This guide follows the supported plugin route from an empty model project to
simulation, timing solve, periodic solve, continuation, and multi-stride
planning. Run commands from the Legged Model Zoo repository root. Numerical
solve and continuation steps require MATLAB Optimization Toolbox; schema,
catalog, simulation, and artifact contracts do not.

The built-in `tutorial_hopper` is the executable reference for the advanced
steps. Apply the same contracts to the generated model after its dynamics and
problems are implemented.

## 1. Generate an isolated model project

Generate outside this repository. `new_model` creates an inactive plugin; it
does not modify the built-in catalog.

```matlab
startup;
toolsPath = fullfile(lmz.util.ProjectPaths.root(), 'tools');
addpath(toolsPath);
toolsCleanup = onCleanup(@() rmpath(toolsPath));

pluginRoot = tempname;
mkdir(pluginRoot);
report = new_model('my_hopper', pluginRoot);
assert(strcmp(report.ModelId, 'my_hopper'));
```

Review the generated `plugin.json`, model package, catalog files, generated
tests, and example before registering the root as trusted executable code.

## 2. Define physical state

Integrated state and numerical decisions are different schemas. A planar
hopper can start with position and velocity:

```matlab
stateSchema = lmz.schema.VariableSchema([ ...
    lmz.schema.VariableSpec('x',  'Unit','m',   'Scale',1); ...
    lmz.schema.VariableSpec('vx', 'Unit','m/s', 'Scale',1); ...
    lmz.schema.VariableSpec('y',  'Unit','m',   'Scale',1); ...
    lmz.schema.VariableSpec('vy', 'Unit','m/s', 'Scale',2)]);
assert(isequal(stateSchema.names(), {'x';'vx';'y';'vy'}));
```

The order is a public data contract. Change it only with an explicit adapter
and artifact migration.

## 3. Define parameters and their transition meaning

Units, bounds, scale, activity, role, and energy effect are all explicit.
`unknown` is the safe energy default; it cannot pass an energy-sensitive
transition without a policy decision.

```matlab
parameterSchema = lmz.schema.VariableSchema([ ...
    lmz.schema.VariableSpec('gravity', 'Unit','m/s^2', ...
        'DefaultValue',9.81, 'LowerBound',0.1, 'UpperBound',50, ...
        'Scale',10, 'Topology','bounded', 'Activity','active', ...
        'Role','physical', 'EnergyEffect','state_dependent'); ...
    lmz.schema.VariableSpec('impulse', 'Unit','m/s', ...
        'DefaultValue',8, 'LowerBound',0, 'UpperBound',30, ...
        'Scale',10, 'Topology','bounded', 'Activity','active', ...
        'Role','control', 'EnergyEffect','work_input')]);
```

Roles are `physical`, `control`, `schedule`, and `derived`. Energy effects are
`invariant`, `state_dependent`, `work_input`, and `unknown`. Stiffness and rest
length are normally `state_dependent`, not automatically energy neutral.

## 4. Implement modes and dynamics

Keep equations in the model package. A minimal two-mode sketch uses the state
`[x; vx; y; vy]`:

```matlab
p = struct('gravity',9.81, 'mass',1, 'stiffness',200, ...
    'restLength',1);
flightFlow = @(state) [state(2); 0; state(4); -p.gravity];
stanceFlow = @(state) [state(2); 0; state(4); ...
    -p.gravity + p.stiffness*(p.restLength-state(3))/p.mass];
assert(numel(flightFlow([0;1;1;0])) == 4);
assert(numel(stanceFlow([0;1;0.9;0])) == 4);
```

In the plugin, implement these equations through `lmz.simulation.HybridSystem`
mode callbacks. Never invoke a numerical solver from the model or GUI.

## 5. Implement events and resets

Declare touchdown and liftoff guards in trusted MATLAB code. Preserve both
pre- and post-reset states in event records. A simple impact reset is:

```matlab
impactReset = @(state,impulse) ...
    [state(1); state(2); max(0,state(3)); state(4)+impulse];
pre = [0;1;0;-4];
post = impactReset(pre,8);
assert(post(4) == 4);
```

`HybridSimulator` orders simultaneous events deterministically and publishes a
strictly increasing trajectory while retaining every event's `PreState` and
`PostState`.

## 6. Define Poincaré sections

Use a state-plane section for a descending apex, a named event section for
impact, and another state-plane section for a descending height:

```matlab
apexDescriptor = lmz.poincare.PoincareSectionDescriptor(struct( ...
    'id','apex', 'label','Descending apex', 'kind','state_plane', ...
    'stateName','vy', 'threshold',0, 'crossingDirection',-1, ...
    'stateSide','post', 'minimumReturnTime',1e-6, ...
    'requiredEventSequence',{{'impact'}}, ...
    'coordinateNames',{{'vx','y'}}, 'maturities',{{'tutorial'}}, ...
    'validationStatus','tested'));
apex = lmz.poincare.StateFunctionSection(apexDescriptor,stateSchema);

impactDescriptor = lmz.poincare.PoincareSectionDescriptor(struct( ...
    'id','ground_impact_pre', 'label','Ground impact before reset', ...
    'kind','named_event', 'eventId','impact', ...
    'crossingDirection',-1, 'stateSide','pre', ...
    'minimumReturnTime',1e-6, 'coordinateNames',{{'vx','vy'}}, ...
    'maturities',{{'tutorial'}}, 'validationStatus','tested'));
impact = lmz.poincare.NamedEventSection(impactDescriptor);

heightDescriptor = lmz.poincare.PoincareSectionDescriptor(struct( ...
    'id','height_descending', 'label','Descending height', ...
    'kind','state_plane', 'stateName','y', 'threshold',0.5, ...
    'crossingDirection',-1, 'stateSide','post', ...
    'minimumReturnTime',1e-6, 'coordinateNames',{{'vx','vy'}}, ...
    'maturities',{{'tutorial'}}, 'validationStatus','tested'));
heightDescending = lmz.poincare.StateFunctionSection( ...
    heightDescriptor,stateSchema);
assert(strcmp(impact.StateSide,'pre'));
```

Production descriptors live in `catalog/<model-id>/poincare_sections.json`.
JSON contains data only; nonlinear callbacks require a trusted implementation
class under the registered plugin root.

## 7. Define a stride

A stride specifies section IDs and sides, direction, minimum return time,
required event sequence, return occurrence, and state symmetry. These fields
prevent the initial point on the section from being mistaken for a return.

```matlab
symmetry = lmz.poincare.PlanarTranslationSymmetry( ...
    'planar_translation', {'x'});
stride = lmz.poincare.StrideDefinition.fromSections( ...
    apex, apex, symmetry.Id);
assert(strcmp(stride.StartSectionId,'apex'));
assert(stride.MinimumReturnTime > 0);
```

Use `IdentitySymmetry` when no quotient is needed. Do not silently discard a
translation coordinate.

## 8. Run a one-stride simulation

The built-in tutorial demonstrates the public service boundary:

```matlab
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
simulationProblem = model.createProblem('demo_hop',struct());
context = lmz.api.RunContext.synchronous(101);
simulation = lmz.services.SimulationService().simulate( ...
    simulationProblem, [], struct(), context);
assert(isa(simulation,'lmz.api.SimulationResult'));
assert(all(diff(simulation.Time) > 0));
```

## 9. Solve contact timing only

This operation fixes initial state and physical parameters. It solves only the
free event schedule and selected section-return equation; it does **not**
enforce state periodicity.

```matlab
timingProblem = model.createProblem('section_return_timing',struct());
fixedState = timingProblem.FixedInitialState;
fixedParameters = timingProblem.FixedPhysicalParameters;
timing = lmz.services.ContactTimingService().solve( ...
    timingProblem, timingProblem.InputSchedule, ...
    struct('MultistartCount',1), context);
assert(isequaln(timing.FixedInitialState,fixedState));
assert(isequaln(timing.FixedPhysicalParameters,fixedParameters));
assert(timing.SolverDiagnostics.NoPeriodicityResidual);
```

See [contact-timing-solve.md](contact-timing-solve.md) before changing a
fixed/free mask.

## 10. Solve a periodic orbit

Periodic closure is a separate nonlinear problem and may solve initial-state
and other decision variables:

```matlab
periodicProblem = model.createProblem('periodic_hop',struct());
seed = periodicProblem.makeSolution( ...
    periodicProblem.getDecisionSchema().defaults(), [], []);
solved = lmz.services.SolveService().solve( ...
    periodicProblem, seed, struct(), context);
assert(solved.Evaluation.ScaledResidualNorm < 1e-7);
```

For a regular one-dimensional family, the correct local condition is
`n - rank(J) = 1`; residual row count alone is not the rule.

## 11. Generate a second seed

Use the public seed service so chart scaling and correction remain consistent:

```matlab
pair = lmz.services.SeedService().makeSecondSeed( ...
    periodicProblem, solved.Solution, 0.02, struct(), context);
assert(isa(pair,'lmz.data.SolutionPair'));
```

## 12. Continue the family

```matlab
continuationOptions = struct('MaximumPoints',6, ...
    'BothDirections',false, 'InitialStep',0.02);
continued = lmz.services.ContinuationService().run( ...
    periodicProblem, pair, continuationOptions, context);
assert(continued.Branch.pointCount() >= 2);
```

Persist a continuation run with `continued.toArtifact()` and
`lmz.io.ArtifactStore.save` when an output path is explicitly supplied.

## 13. Build a five-stride layout and attempt timing correction

The quad-load adapter demonstrates an exact legacy-to-native plan boundary.
Missing strides are completed by an explicit policy; no core code prompts.

```matlab
catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset = catalog.load(catalog.Manifest.defaultMultiStride);
layoutRequest = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5, 'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','carry_forward', 'EnergyNeutralOnly',true, ...
    'FailurePolicy','error', 'StartSectionId','apex', ...
    'StopSectionId','apex');
loadModel = registry.createModel('slip_quad_load');
layout = lmzmodels.slip_quad_load.QuadLoadStridePlanBuilder().build( ...
    layoutRequest,lmz.api.RunContext.synchronous(901));
xAccum5 = lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(layout.Plan);
assert(layout.CompletedStrideCount == 5);
assert(numel(xAccum5) == 44 + 13*(5-1));

correctedRequest = lmz.multistride.MultiStrideRequest( ...
    'NumberOfStrides',5, 'InitialDecision',dataset.XAccum, ...
    'CompletionPolicy','predictor_corrector', ...
    'EnergyNeutralOnly',true,'FailurePolicy','return_partial');
corrected = lmz.services.MultiStrideSimulationService().simulate( ...
    loadModel,correctedRequest,lmz.api.RunContext.synchronous(901));
assert(corrected.Partial && corrected.CompletedStrideCount == 2);
assert(isempty(corrected.Simulation));
assert(strcmp(corrected.Failure.Identifier, ...
    'lmz:MultiStride:TimingSeedOutsideTrustRegion'));
```

See [multi-stride-planning.md](multi-stride-planning.md) for completion and
energy policies. The 96-entry object demonstrates copied schedule layout and
exact codec behavior only. The predictor-corrector result is an intentional,
structured failure at stride 3; no five-stride physical simulation or timing
feasibility is claimed.

## 14. Add visualization and configuration

Declare scene frames and primitives in `scene.lmz.json`, then return a
`PlotPlugin` from `getVisualizationPlugin`. Optional
`graphics.lmz.json` profiles bind only validated renderer classes and relative
files. See [visualization-authoring.md](visualization-authoring.md) and
[configuration-reference.md](configuration-reference.md).

## 15. Test and register as a trusted plugin

Run generated tests before discovery, then hold registration only as long as
needed:

```matlab
generatedResults = runtests(fullfile(pluginRoot,'tests','generated'), ...
    'IncludeSubfolders',true);
assert(~any([generatedResults.Failed]));

pluginRegistry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
    pluginRoot,'IncludeBuiltIns',false);
registryCleanup = onCleanup(@() delete(pluginRegistry));
assert(any(strcmp(pluginRegistry.listModels(),'my_hopper')));
clear registryCleanup pluginRegistry
```

For a migrated scientific model, generated smoke tests are insufficient. Add
immutable source provenance, dataset hashes, numerical-oracle tolerances,
section evidence, timing equivalence, energy-transition tests, and artifact
migrations as described in [testing-a-model.md](testing-a-model.md).

## 16. Add optional multiple shooting

Add this only after one direct section-to-section simulation is reliable. Define
a `SectionStateSchema` from named physical-state coordinates, construct
`ShootingNode` and `ShootingSegment` records with explicit sections/sides,
schedules, controls, physical data, and energy/work mode, and join them in a
`ShootingHorizon`. Let `ShootingDecisionSchema` bind free node coordinates,
schedule coordinates, controls, selected physical parameters, targets, and
gauges by name.

The model-owned adapter derives from `lmz.shooting.SectionSimulationAdapter`
and implements `simulateSegment`. One call must directly propagate exactly the
configured segment and return finite `TerminalState`, symmetry-aligned
`TerminalCoordinates`, `ContactResiduals`, `SectionResidual`,
`EnergyResidual`, crossing/event information, simulation, physical validity,
and diagnostics. Do not simulate from an apex and relabel a later crossing, and
do not call an inner solver.

Register a problem factory that returns `MultipleShootingProblem` (or its
periodic/transition specialization) with an inert configuration and a
model-owned adapter. Function-handle evaluators are allowed only for trusted
in-process experiments; their problem contract is non-reproducible and cannot
be saved. Test every advertised section/side/occurrence, residual block,
interface defect, event order, energy/work condition, rank report, artifact
round trip, and reproduction hash. See
[model-author-guide.md](model-author-guide.md),
[multiple-shooting.md](multiple-shooting.md), and
[horizon-feasibility.md](horizon-feasibility.md); use
`tutorial_hopper/multiple_shooting` as the small executable reference.
