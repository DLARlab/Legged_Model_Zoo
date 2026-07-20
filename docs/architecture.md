# Architecture

Dependencies point from GUI to application services to model-independent algorithms and problem/model contracts. Persistence consumes plain data objects, while visualization consumes named simulation output. Model-specific layouts are restricted to adapters under `models/+lmzmodels`.

Manifests bind only classes in the approved `lmzmodels.*` namespace. JSON contains no executable expressions. `startup.m` adds only `src` and `models`.

The introductory path delegates GUI simulation to `AppController`, then `SimulationService`, then a `SimulationProblem` and model. Scientific paths share the same controller/service/data boundary and select a model problem/adapter at the edge:

```text
LeggedModelZooApp
  -> AppController
  -> Branch / Evaluation / Solution / Solve / Seed / Continuation services
  -> slip_quadruped.PeriodicApexProblem
     | slip_biped.PeriodicApexProblem / TrajectoryFitProblem
     | slip_quad_load.SingleStrideProblem / MultiStrideFitProblem
  -> model-specific legacy evaluator (solver-free compatibility boundary)
  -> ProblemEvaluation / SimulationResult
  -> QuadrupedRenderer and named plot providers
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
selection, test hooks, and disposal. `LeggedModelZooApp` is limited to lifecycle,
header/model/problem selection, status aggregation, tab composition, and
close/cancel coordination. A transactional presentation event bus coalesces a
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
declarative catalog/data/scene
        | bounded parse + schema/path validation
        v
ModelRegistry --> trusted LeggedModel implementation
        |                |
        |                +--> model problem / schemas
        |                +--> HybridSystem (new native models)
        |                +--> PlotPlugin / KinematicsFrame
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

## Generic visualization boundary

`SceneSpec` is a validated declarative graph. `KinematicsFrame` supplies named
finite frame poses/vectors for a simulation index. `SceneRenderer2D` maps the
allowlisted primitive set to reused graphics handles and implements the same
`updateFrame(index)` contract as scientific renderers. `PlotPlugin` supplies
the scene, kinematics frames, and named plots. The built-in tutorial hopper and
one quadruped tutorial use this path, while the quadruped model-specific
scientific renderer remains a regression oracle.

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
