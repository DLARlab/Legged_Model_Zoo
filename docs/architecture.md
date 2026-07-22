# Architecture

Dependencies point from GUI to application services to model-independent algorithms and problem/model contracts. Persistence consumes plain data objects, while visualization consumes named simulation output. Model-specific scientific logic and legacy data layouts are restricted to adapters/providers under `models/+lmzmodels`; registered workbench metadata selects only generic placement profiles and components.

Manifests bind only classes in the approved `lmzmodels.*` namespace. JSON contains no executable expressions. `startup.m` adds only `src` and `models`.

The introductory path delegates GUI simulation to `AppController`, then `SimulationService`, then a `SimulationProblem` and model. Scientific paths share the same controller/service/data boundary and select a model problem/adapter at the edge:

```text
LeggedModelZooApp
  -> AppController
  -> WorkflowRegistry / registered data + workbench + workflow descriptors
  -> Branch / Evaluation / Solution / Solve / Seed / Continuation services
  -> slip_quadruped.PeriodicApexProblem
     | slip_biped.PeriodicApexProblem / TrajectoryFitProblem
     | slip_quad_load.SingleStrideProblem / MultiStrideFitProblem
  -> model-specific legacy evaluator (solver-free compatibility boundary)
  -> ProblemEvaluation / SimulationResult
  -> VisualizationProfileRegistry / RendererFactory
  -> model-owned research renderer or generic SceneRenderer2D
  -> named plot providers / RecorderService
```

The GUI never calls model-specific evaluators or numerical algorithms directly.
It dispatches through model/problem capabilities, `AppController`,
branch/evaluation/simulation/solve/continuation/optimization services, and
named render/plot providers. The scientific packages are
`lmzmodels.slip_biped`, `lmzmodels.slip_quadruped`, and
`lmzmodels.slip_quad_load`; the independent core tutorial is
`lmzmodels.tutorial_hopper`.

GUI controls call `AppController`, which owns invalidation and synchronization
and delegates to services. Six handle-based components under
`+lmz/+gui/+tabs` own their widgets, callbacks, refresh, busy/capability state,
selection, test hooks, and disposal; host-neutral workspace adapters reuse
those components in either `scientific_workbench` or `classic_tabs`.
`LeggedModelZooApp` is limited to lifecycle,
header/model/problem/workflow/layout selection, status aggregation, shell
composition, and close/cancel coordination. A transactional presentation event bus coalesces a
logical state transition and refreshes each subscriber once; subscription
handles make listener disposal and leak tests explicit. No scientific logic is
moved into widgets. Dedicated solver/projector adapters own calls to `fsolve`
and `fmincon`; services depend only on problem contracts. `FminconSolver`
detects exact equal bounds and solves only the free subvector, then reconstructs
the full schema vector for every objective/constraint call and returned
artifact.

Raw indexing is centralized in `Results29Layout/Adapter`, `Results14Layout/Adapter`, and `FirstStrideLayout`/`LaterStrideLayout`/`XAccumAdapter`. Branches store decision and parameter matrices by schema with one explicit parameter column per point and per-point observables, classifications, diagnostics, feasibility, problem maturity, validation status, and source lineage. Problem descriptors, not model marketing labels, are the authority for scientific maturity and capabilities; the registry derives model-level availability from them.

## Dependency and extension boundaries

```text
declarative catalog/data/scene/graphics/style
        | bounded parse + schema/path validation
        v
ModelRegistry --> trusted LeggedModel implementation
        |                |
        |                +--> model problem / schemas
        |                +--> HybridSystem (new native models)
        |                +--> PlotPlugin / KinematicsFrame / pure geometry
        |                +--> trusted Renderer implementation
        +--> GraphicsConfig / VisualizationProfileRegistry
        +--> WorkflowRegistry
             +--> contained DataSourceProvider / legacy adapter
             +--> inert WorkbenchContribution / WorkflowDescriptor
        v
services --> solver / continuation / optimization algorithms
        |
        v
plain results and versioned artifacts --> presentation event state --> tabs
```

Dependencies point inward toward `lmz.api`, schemas, plain data, and services.
External code never becomes a dependency of `src/+lmz`; it implements the
contracts. Scientific compatibility evaluators remain at the model edge and
are not routed through the new generic hybrid engine during the release
candidate round.

## Registered workflow boundary

Round 11 extends model discovery with three optional, additive manifest
references: `dataSources`, `workbench`, and `workflows`. `ModelRegistry`
contains and hashes their catalog paths; `WorkflowRegistry` validates schema,
identity, provider trust, problem capabilities, axis/layout/graphics
references, and frozen digests. A data-source provider is trusted model/plugin
code and must resolve inside its registered package and code root. Workbench and
workflow JSON are inert configuration and cannot contain callbacks.

`WorkflowRunner` creates one `WorkflowSession` from a registry-bound
descriptor and `RunContext`. The session owns runtime selection and delegates
root solve, seed construction, continuation, checkpoint/resume, homotopy, and
family scan to existing generic services. It neither imports a built-in
scientific package directly nor reimplements an algorithm. A model without
optional contributions receives an empty workflow list and generic
`classic_tabs` workbench.

The quadruped RoadMap provider and exact Results29 adapter remain in
`lmzmodels.slip_quadruped`; biped/load/tutorial equivalents remain in their
model packages. Generic code under `src/+lmz/+gui`, `+services`, and
`+workflow` consumes descriptors/providers and does not switch on canonical
built-in model IDs. The external analytic-hopper fixture crosses the same
boundary and proves scoped removal.

The presentation side has a separate placement boundary. `WorkbenchShell`
chooses a layout profile and hosts the same six components. The scientific
layout adds a persistent `BranchCanvas`, shared overlay controller, scrollable
task sidebar, workspace views, and status/progress dock; classic tabs retain
the established placement. The host-neutral `CentralAnalysisWorkspace`, not
the layout, interprets controller state for footfall/classification and live
run diagnostics. Controller state owns datasets, selection, results, progress,
and overlays, so switching layout does not alter scientific state or recompute
a branch.

## Registry and external plugins

Default discovery scans only the repository catalog and resolves classes under
the repository `models` root. `discoverWithPlugins` is an explicit trust action.
Each external root has `plugin.json`, one code root, one catalog root, and an
isolated namespace. Registry validation canonicalizes both roots, rejects
traversal/symlink escape, checks catalog folder/ID equality and descriptor IDs,
rejects duplicate IDs across all roots, and confirms the one resolved class is
inside its approved code root. A registration is a scoped path lease; deletion
removes only paths added by the lease.

`ModelRegistry.createModel` binds immutable catalog context to the model.
`BaseProblem` obtains its descriptor from that context, so an external problem
does not fall back to the built-in catalog. Direct legacy construction retains
a built-in fallback for compatibility.

External MATLAB implementations are trusted executable code and may perform
arbitrary operations. The registration checks provenance and containment; it
is not a sandbox. JSON, scene files, built-in examples, legacy MAT files, and
artifacts remain untrusted data.

## Generic hybrid boundary

`HybridSystem` supplies a state schema, initial state/mode, continuous
`HybridMode` flows, a scheduled or guard event policy, reset maps, and named
outputs. `HybridSimulator` owns integration, RunContext cancellation, stable
event ordering, mode history, and output assembly. Simultaneous events sort by
time, priority, and declaration order. The public `SimulationResult.Time`
remains strictly increasing and keeps the final post-event sample; event
records preserve every pre/post state and transition.

Guard callbacks are possible only in trusted MATLAB implementations. Scene
JSON and problem/catalog JSON cannot declare a callback or expression.

## Visualization profile boundary

`graphics.lmz.json` is model-owned declarative policy. `GraphicsConfig` loads
it through bounded JSON, contains scene/style paths inside the model catalog,
validates profile defaults and maturity applicability, and restricts renderer
classes to the registered namespace/code root. JSON cannot contain state-vector
indices, constructor expressions, or callbacks. A model without graphics JSON
receives a synthesized `clean_generic` profile over its declarative scene.

The runtime selection flow is:

```text
problem descriptor maturity
        + per-model/problem GUI preference
        v
VisualizationProfileRegistry.resolve
        v
RendererFactory
  |-- SceneRenderer2D + model PlotPlugin + validated SceneSpec
  `-- trusted model renderer(axes, SimulationResult, profile, options)
```

All validated built-in scientific problems resolve to `research_legacy` by
default. Their tutorial `demo_stride` problems and both tutorial-hopper
problems resolve to `clean_generic`. `high_contrast` is an explicit applicable
alternative, not an implicit global palette. The header application palette
and model visual profile are separate preferences.

`Renderer` defines the stable lifecycle: `initialize`, `updateFrame`,
`setOptions`, `setProfile`, `frameCount`, `captureFrame`, `resetCamera`, `clear`,
and `delete`. The renderer owns only children of the axes supplied to it. It
builds handles once and mutates numeric graphics properties; it does not own a
figure, playback loop, interpolation, output path, or video writer.

`SceneSpec` is a validated declarative graph. `KinematicsFrame` supplies named
finite frame poses/vectors for a simulation index. `SceneRenderer2D` maps the
allowlisted primitive set to reused graphics handles. `PlotPlugin` supplies the
scene, kinematics frames, and named plots. The tutorial hopper, generated-model
template, external analytic-hopper fixture, and the quadruped clean fallback use
this generic boundary. The biped/load clean profiles use model-owned simple
renderers behind the same factory/lifecycle contract.

Source-derived scientific renderers derive from `ResearchRenderer` and consume
pure model geometry. `PatchGeometry`, `PolylineGeometry`, and
`LayeredGeometry` keep vertices/faces/paths independent of MATLAB handles. The
quadruped owns compound body/leg/COM/ground/phase geometry; the biped owns its
body/COG/point-foot geometry; the load renderer composes quadruped geometry with
load/rope geometry and per-stride parameter selection. Source checkouts are
maintainer-only references and are not runtime dependencies.

`research_legacy` means that audited source geometry, layer order, named camera
behavior, and deterministic style constants are implemented and fixture-gated.
It does not import source figure/path/playback ownership. `clean_generic` is a
deliberately simplified view and is never called source-faithful.
`high_contrast` retains compound research geometry for scientific profiles but
deliberately changes colors and widths. Source-default color stabilization,
the prompt-required equal quadruped aspect, generalized N-stride load selection,
and modern analysis views are recorded deviations rather than hidden as pixel
equivalence.

Plot selection remains model-owned. `RendererFactory.renderPlots` passes the
resolved profile to `plotSimulation` or the generic plugin. Models must
distinguish audited source plot behavior from clean views and modern
enrichments; animation fidelity does not automatically establish plot fidelity.

## Animation and recording boundary

```text
SimulationResult --> AnimationController --> renderer.updateFrame(index)
                                           --> renderer.captureFrame()
selected profile --> GUI recording options/metadata --> RecorderService
                                                   |--> target artifact
                                                   `--> target.lmz.json
```

`AnimationController` owns normalized-time/index mapping, play/pause/stop,
speed/FPS, and looping. `RecorderService` owns frame selection for export,
cooperative cancellation, temporary files, GIF/MP4/keyframe/static encoding,
resource cleanup, and restoration of the original renderer frame.

The GUI maps the resolved profile's recording defaults into applicable
requests, adds artifact-kind/model/problem/profile-descriptor/timestamp metadata,
and writes a sidecar for animation GIF, MP4, keyframes, plots, and the
oscillator GIF. The profile value is the resolved `VisualizationProfile`
descriptor, including style path rather than an inline copy of the style JSON.
Explicit request values override profile defaults. Direct service callers must
pass both operational options and metadata because the service does not resolve
model/profile configuration; omitted operational values use service defaults.

This graphics architecture is written to the R2019b static target and routes
release-sensitive export/video operations through compatibility adapters.
R2019b graphics runtime is not verified; current runtime/hidden-render evidence
comes from the recorded newer MATLAB environment, and desktop human approval is
a separate manual gate.

## Artifact and RunContext lifecycle

Services receive a RunContext, check cancellation/pause at bounded intervals,
report progress/log/checkpoints, and return plain result objects. Run artifacts
record framework/artifact/model/problem versions, source lineage/hashes,
options, seed/pair, MATLAB/toolboxes, timing, evaluations, termination, and
warnings. `reproduceRun` verifies compatible versions and hashes before
reconstructing the service call.

Callbacks in RunContext are trusted in-memory control flow. They are never
accepted from persisted artifacts. Artifacts written by 1.x follow the policy
in `docs/API_STABILITY.md` and reject unsupported future schemas before type
dispatch.

## File trust boundary

`SafeJson` bounds bytes, depth, decoded item count, and allowed primitive data.
`SafeMat` preflights top-level names/classes/dimensions/bytes, loads only
requested variables, and recursively rejects function handles, arbitrary
objects, complex data, excessive nesting, and allocation bombs before the
application consumes the value. MATLAB may deserialize a nested object while
performing `load` and before recursive validation can reject it; the loader is
therefore a strict application-data boundary, not a sandbox for a deliberately
hostile MAT serialization. Use an isolated process for forensic inspection of
unknown MAT files. `PathGuard` resolves canonical paths and enforces
containment. Model catalog loaders and legacy adapters use these boundaries
before their scientific dimension/hash checks.

The design reduces accidental execution but cannot make MATLAB's general
`load`, `addpath`, or third-party code safe. Users must not register unreviewed
plugins or bypass safe loaders for untrusted files.

## Architecture decisions

Decisions are recorded under `docs/adr/`, including per-problem maturity,
scientific compatibility oracles, mixed-license release profiles, GUI event
synchronization, external plugin discovery, generic hybrid contracts, and the
generic scene format.
