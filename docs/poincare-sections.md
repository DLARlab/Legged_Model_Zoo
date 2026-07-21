# Poincaré sections and stride boundaries

A Poincaré section defines *where* a hybrid trajectory is sampled. A stride
adds start/stop sides, return filtering, event-sequence requirements, and a
symmetry convention. These choices are part of the numerical problem, not a
plotting preference.

## Core objects

| Object | Responsibility |
| --- | --- |
| `PoincareSectionDescriptor` | Validated declarative identity, crossing, coordinate, maturity, and implementation metadata |
| `NamedEventSection` | Select an existing hybrid event record and its pre/post state |
| `StateFunctionSection` | Detect a named-state threshold crossing |
| `CompositeSection` | Combine one scalar crossing with nonempty safe declarative acceptance conditions |
| `SectionCrossing` | Store time, value, derivative, direction, modes/events, pre/post states, and acceptance diagnostics |
| `PoincareSectionRegistry` | Validate a catalog and instantiate trusted sections/symmetries |
| `StrideDefinition` | Bind start and stop sections, sides, return rules, hashes, and symmetry |
| `PoincareReturnMap` | Propagate between sections and compute symmetry-aligned return coordinates |

## Section kinds

`named_event` selects an event already emitted by the hybrid simulator. Its
descriptor must name `eventId`; `stateSide` is `pre` or `post`. Both states
remain in `SectionCrossing`, so an impact section never loses reset semantics.

`state_plane` is the safe declarative form

\[
h(x)=x_i-c=0.
\]

It names `stateName`, `threshold`, direction `-1`, `0`, or `1`, and an optional
`modeRestriction`. `StateFunctionSection.detectCrossing` reports the
directional derivative and grazing status.

`composite` uses a primary scalar section plus a nonempty list of safe
declarative conditions. Supported kinds compare a named state with a finite
threshold (`gt`, `ge`, `lt`, or `le`), require a named mode, or require a named
event in history. JSON cannot contain MATLAB expressions or callbacks. A custom
implementation remains possible only through an explicitly trusted class.

## Load a catalog

Built-in catalogs are stored at `catalog/<model-id>/poincare_sections.json`.
The following code resolves the tutorial catalog without executing data as
code:

```matlab
startup;
model = lmzmodels.tutorial_hopper.Model();
path = fullfile(lmz.util.ProjectPaths.catalog(), ...
    'tutorial_hopper','poincare_sections.json');
sections = lmz.poincare.PoincareSectionRegistry.fromJson(path, ...
    'ModelId','tutorial_hopper', ...
    'StateSchema',model.getPhysicalStateSchema());
ids = sections.listSections();
assert(all(ismember({'apex','ground_impact_pre', ...
    'ground_impact_post','height_descending'},ids)));
apex = sections.section('apex');
symmetry = sections.symmetryFor('apex');
```

For an external catalog that names custom classes, also supply its canonical
`TrustedCodeRoot` and exact `TrustedNamespace`. Resolution must be unique and
inside that root. Catalog data never grants trust by itself.

## Catalog schema

The root contains only:

```text
schemaVersion
defaultSectionByProblem
sections
```

Each section declares `id`, `label`, `kind`, direction, side, minimum return
time, required event sequence, occurrence, coordinate names, symmetry,
maturities, and validation status. A named event adds `eventId`; a state plane
adds `stateName`, `threshold`, and optional `modeRestriction`; a declarative
composite adds `parameters.primarySectionId` and nonempty
`parameters.conditions`; custom sections use trusted implementation metadata.

`defaultSectionByProblem` is explicit. Absence is an error; the registry does
not silently choose the first section.

## A complete stride definition

```matlab
startSection = sections.section('apex');
stopSection = sections.section('height_descending');
stopSymmetry = sections.symmetryFor('height_descending');
stride = lmz.poincare.StrideDefinition.fromSections( ...
    startSection,stopSection,stopSymmetry.Id);
stored = stride.toStruct();
assert(strcmp(stored.StartSectionId,'apex'));
assert(strcmp(stored.StopSectionId,'height_descending'));
assert(numel(stored.StartSectionHash) == 64);
```

The section fingerprints are configuration identity. Changing a threshold,
direction, side, coordinate list, return rule, or implementation invalidates
seed pairs, checkpoints, and solver state created for the old definition.

## Crossing acceptance

A candidate return is accepted only after all applicable checks:

1. time is at least `MinimumReturnTime`, suppressing the root at `t=0`;
2. it is the requested `ReturnOccurrence`;
3. `RequiredEventSequence` appears in order in event history;
4. crossing direction matches when nonzero;
5. the selected mode and composite conditions accept it; and
6. the directional derivative is transverse within the configured tolerance.

Grazing is never silently treated as an ordinary return. The crossing records
the section value, derivative, direction, `Grazing`, event and modes, time,
pre/post state, selected side, acceptance, and rejection reason.

## Return maps and symmetry

Construct a return map from concrete section objects, a state schema, and an
explicit `StateSymmetry`:

```matlab
stateSchema = model.getPhysicalStateSchema();
stride = lmz.poincare.StrideDefinition.fromSections( ...
    apex,apex,symmetry.Id);
returnMap = lmz.poincare.PoincareReturnMap( ...
    apex,apex,symmetry,stateSchema,stride);
```

`returnMap.evaluate(initialState,parameters,propagationFcn,context)` invokes a
trusted model-owned propagator. It returns `PoincareReturnResult` with initial,
terminal, aligned-terminal, section-coordinate and residual vectors, crossings,
trajectory, stride descriptor, section descriptors, symmetry descriptor, and
diagnostics. The callback is runtime configuration and is never deserialized.

For planar translation, `PlanarTranslationSymmetry` aligns named position
states. This replaces the unsafe convention of dropping a state-vector index.

## Periodic residual and branch dimension

For section coordinates `pi` and symmetry `G`, periodic closure is

\[
F(z)=\pi\!\left(G^{-1}P_\Sigma(x_0)\right)-\pi(x_0).
\]

A regular one-dimensional solution family requires

\[
n-\operatorname{rank}(J_F)=1.
\]

Do not replace this rank condition with a generic `residual count = n-1` rule.
Redundant residual rows and formulation-specific variables make row count
insufficient.

## Timing-only is not periodicity

A timing-only section-return problem holds `x0` and physical parameters fixed,
then solves schedule variables so explicit contact equations and the stop
section are satisfied. It does not require the returned section coordinates to
equal the initial coordinates. A periodic-orbit problem adds that closure
residual and may solve initial-state variables. See
[contact-timing-solve.md](contact-timing-solve.md).

## Rephasing an existing orbit

Changing from apex to another section is a problem-configuration change. The
safe rephasing procedure is:

1. simulate the source orbit and retain event records;
2. locate an accepted target crossing with the target section object;
3. choose its declared pre/post state;
4. shift the time origin and rotate cyclic event times;
5. apply the declared state symmetry;
6. construct a new solution with lineage containing both section fingerprints;
7. solve/evaluate under the target-section problem before continuation.

The public transfer service performs that sequence and returns typed lineage:

```matlab
transferred = lmz.services.SectionTransferService().transfer( ...
    model,sourceSolution,'height_descending',context);
assert(transferred.PhaseInvariantObservablesPreserved);
assert(transferred.PhysicalOrbitMaxError <= 1e-12);
assert(strcmp(transferred.Lineage.TargetSectionId,'height_descending'));
assert(transferred.DecisionCodecRephased);
```

`SectionTransferResult` stores both solutions, the target crossing, rotated
simulation, source return, symmetry displacement, and the physical-orbit error.
For the built-in tutorial, quadruped, and biped codecs, the service constructs
a target-configured `periodic_orbit` solution and verifies that a fresh
evaluation reproduces the transferred trajectory before recording
`DecisionCodecRephased=true`. An unsupported plugin codec retains `false` and
must provide its own verified adapter. Always solve under the target-section
problem and create a new seed pair before continuation. Do not emulate transfer
by relabeling an old solution or reusing an old continuation checkpoint.

## Modify the tutorial safely

`tutorial_hopper` already declares `height_descending`. To experiment, copy the
catalog to an isolated plugin, change its threshold or add another unique ID,
load it through `PoincareSectionRegistry`, detect the crossing, rephase through
`SectionTransferService`, run one simulation, solve timing only, solve periodic
closure, generate a new seed pair, and continue a short family. Compare apex
and descending-height results only through phase-invariant observables and
symmetry-aligned closed trajectories.

For a source-equivalent scientific model, a new section is not automatically
source-equivalent. Preserve the existing apex oracle, assign the new section
its own maturity/validation status, add transversality and rephasing evidence,
and rerun residual, trajectory, force, artifact, and continuation regressions.
