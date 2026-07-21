# Scientific section-local shooting

This guide describes the validated Round 10 Poincaré-section shooting paths
for `slip_quadruped`, `slip_biped`, and `slip_quad_load`. It distinguishes an
exact source-compatible apex oracle from a genuinely section-local decision,
and it records numerical qualifications instead of treating every small
residual as an isolated physical solution.

For the section object model, crossing rules, and catalog format, see
[Poincaré sections and stride boundaries](poincare-sections.md). For timing
row policies and rectangular systems, see
[contact timing solve](contact-timing-solve.md).

## What “section local” means

A non-apex section-local decision owns all of the following:

- the initial state in the selected section coordinates;
- positive ordered gaps for the contact events inside the return;
- the return time;
- the selected pre/post reset side; and
- the start/stop section and symmetry identifiers in solution lineage.

Residual evaluation decodes that state and schedule, starts the model adapter
at the selected section, applies any required reset, integrates the model
equations to the requested return, and forms periodicity in target-section
coordinates. It does not solve an apex problem and then look up a target event
inside that trajectory.

The immutable apex paths remain regression oracles. Selecting the ordinary
`apex`/`apex`, post/post, planar-translation preset delegates to the same apex
problem, decision schema, residual, and simulation. A non-apex problem does
not retain the source apex phase variable or add a hidden apex gauge.

The adapters implementing this contract are:

```text
lmzmodels.slip_quadruped.QuadrupedSectionSimulationAdapter
lmzmodels.slip_biped.BipedSectionSimulationAdapter
lmzmodels.slip_quad_load.QuadLoadSectionSimulationAdapter
lmzmodels.tutorial_hopper.HopperSectionSimulationAdapter
```

For a pre-impact start, the decision-owned crossing state is the pre-reset
state. The simulator applies the impact reset before continuous propagation,
so the first continuously integrated sample is post-reset. Both sides remain
explicit in crossing diagnostics; this is not a relabeling of a post-impact
state.

## Validated section matrix

“Root found” below means solver termination was accepted, the configured
scaled residual tolerance was met, and the physical crossing checks passed.
“Adapter validated” means the direct propagation and crossing contract passed;
it does not by itself claim that a fixed template is a contact-feasible root.

### Quadruped

| Start → stop | Side | Public formulation | Decision/residual shape | Qualification |
| --- | --- | --- | --- | --- |
| `apex` → `apex` | post → post | `periodic_apex` or default `periodic_orbit` | 22 × 22 | Exact source-compatible oracle |
| `back_left_touchdown` → same | post → post | `periodic_orbit` | 21 × 21 | Root found; direct integration |
| `back_left_touchdown_pre` → same | pre → pre | `periodic_orbit` | 21 × 21 | Root found; explicit reset |
| `front_left_touchdown` → same | post → post | `periodic_orbit` | 21 × 21 | Root found; direct integration |
| `front_left_touchdown_pre` → same | pre → pre | `periodic_orbit` | 21 × 21 | Root found; explicit reset |
| `descending_y_0_9` → same | post → post | `periodic_orbit` | 21 × 21 | Root found; transverse descending plane |
| `back_left_touchdown_descending` → same | post → post | `periodic_orbit` | 21 × 21 | Root found; contact plus `dy < 0` |
| `back_left_touchdown` → same | post → post | `section_return_timing` | 8 × 8 | Physical root found; rank deficient, not a unique parameterization |
| `back_left_touchdown` → `descending_y_0_9` | post → post | `section_transition` | 25 × 30 | Direct mixed-section transition; tolerance-satisfying seed and accepted descending crossing |
| `descending_y_0_9` → `back_left_touchdown` | post → post | `section_transition` | 25 × 27 | Direct accepted physical candidate; residual `6.224672390864328e-7`, so no root claim |
| `back_left_touchdown` → `front_left_touchdown` | post → post | `section_transition` | 26 × 32 | Direct mixed-section transition; tolerance-satisfying seed |
| `back_left_touchdown_descending` → `front_left_touchdown` | post → post | `section_transition` | 26 × 32 | Direct composite start; tolerance-satisfying seed |
| `back_left_touchdown` → `back_left_touchdown_descending` | post → post | `section_transition` | 26 × 31 | Direct composite target; tolerance-satisfying seed and accepted `dy < 0` condition |

The named-event periodic residual contains eight contact rows and thirteen
section-coordinate closure rows. The state-plane residual contains eight
contact rows, one plane row, and twelve coordinate-closure rows.

The quadruped touchdown timing Jacobian is rank deficient at the validated
root. `ContactTimingService` therefore reports all of the following together:

```text
Success=true
RankConditionRequired=false
UniquenessValidated=false
RankQualification=rank_deficient_root_not_a_unique_parameterization
```

This is a root of the physical residual system, but it is not evidence of an
isolated timing vector. Use gauges or a family formulation before claiming a
unique timing solution.

### Biped

| Start → stop | Side | Public formulation | Decision/residual shape | Qualification |
| --- | --- | --- | --- | --- |
| `apex` → `apex` | post → post | `periodic_apex` or default `periodic_orbit` | 12 × 12 | Exact source-compatible oracle |
| `left_touchdown` → same | post → post | `periodic_orbit` | 11 × 11 | Root found; direct integration |
| `left_touchdown_pre` → same | pre → pre | `periodic_orbit` | 11 × 11 | Root found; explicit reset |
| `right_touchdown` → same | post → post | `periodic_orbit` | 11 × 11 | Root found; direct integration |
| `right_touchdown_pre` → same | pre → pre | `periodic_orbit` | 11 × 11 | Root found; explicit reset |
| `descending_y_0_95` → same | post → post | `periodic_orbit` | 11 × 11 | Root found; transverse descending plane |
| `left_touchdown_descending` → same | post → post | `periodic_orbit` | 11 × 11 | Root found; contact plus `dy < 0` |
| `left_touchdown` → same | post → post | `section_return_timing` | 4 × 4 | Root found; rank 4, nullity 0 |
| `left_touchdown` → `descending_y_0_95` | post → post | `section_transition` | 13 × 14 | Direct mixed-section transition; tolerance-satisfying seed and accepted descending crossing |
| `descending_y_0_95` → `right_touchdown` | post → post | `section_transition` | 13 × 16 | Direct accepted physical candidate; residual `0.04299363542136695`, so no root claim |
| `left_touchdown` → `right_touchdown` | post → post | `section_transition` | 14 × 17 | Direct accepted physical candidate; residual `0.04299360548669684`, so no root claim |
| `left_touchdown_descending` → `right_touchdown` | post → post | `section_transition` | 14 × 17 | Direct composite start; accepted physical candidate with residual `0.04299360548669684`, so no root claim |
| `left_touchdown` → `left_touchdown_descending` | post → post | `section_transition` | 14 × 18 | Direct composite target; tolerance-satisfying seed and accepted `dy < 0` condition |

The named-event periodic residual contains four contact rows and seven
section-coordinate closure rows. The state-plane residual contains four
contact rows, one plane row, and six coordinate-closure rows.

### Quadruped with load

The load model exposes direct section adapters and timing routes, but its
validated claims differ from the unloaded periodic problems.

| Start → stop | Side | Validated route | Qualification |
| --- | --- | --- | --- |
| `apex` → `apex` | post → post | Direct adapter smoke | Accepted physical crossing; source apex equation remains active |
| `stride_boundary` → same | post → post | Direct adapter smoke | Accepted integration endpoint; legacy apex slot is return time only |
| `apex` → `stride_boundary` | post → post | `section_return_timing` with `FixReturnTime=true` | Root found; square 8 × 8, rank 8, nullity 0 |
| `back_left_touchdown` → same | post → post | Direct adapter using template `individual_1_tr_to_rl`, stride 2 | Adapter validated; repeated-template contact norm is about 0.149, so no contact-feasible timing-root claim |

For the touchdown initializer only, the source template is inspected once to
obtain the post-event seed and rotated event schedule. Every subsequent
residual evaluation integrates directly touchdown-to-touchdown and performs no
apex trajectory lookup.

## Run a mixed-section transition

`section_transition` is the registered quadruped/biped route for distinct
start and stop section IDs. It constructs one explicit transition segment,
not a periodic orbit. The source apex orbit is used once to initialize the
start chart, event schedule, and terminal target. Each residual evaluation
then starts from the decision-owned section state and integrates the model
adapter directly to the requested stop section.

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quadruped');
problem = model.createProblem('section_transition',struct( ...
    'StartSectionId','back_left_touchdown', ...
    'StopSectionId','descending_y_0_9', ...
    'StartStateFreeMask',true, ...
    'TargetStateFreeMask',true, ...
    'EventFreeMask',false));

u0 = problem.getDecisionSchema().defaults();
p = problem.getParameterSchema().defaults();
context = lmz.api.RunContext.synchronous(1204);
evaluation = problem.evaluate(u0,p,context,false);
shooting = problem.evaluateShooting(u0,p,context,false);

assert(strcmp(problem.Formulation,'transition'));
assert(~problem.Horizon.Target.PeriodicClosure);
assert(evaluation.PhysicalValidity);
assert(shooting.SegmentResults{1}.Crossing.Accepted);
assert(shooting.SegmentResults{1}.Crossing.CrossingDirection == -1);
assert(~shooting.SegmentResults{1}.Diagnostics.ApexOracleUsed);
```

The active block layout is deliberately explicit:

```text
segment_1_contact_constraints
segment_1_section_residual
interface_1_defect
final_transition_target
```

`interface_1_defect` binds direct propagation to the independently stored
terminal node. `final_transition_target` then binds that node to the requested
target section coordinates. Perturbing the terminal node changes these two
blocks with opposite signs; the target is not an alias for the interface.
`final_section_closure` is absent, and `PeriodicClosure=false` is stored in the
horizon target and problem contract.

The tested default-seed evidence is:

| Model and transition | Scaled residual norm | Crossing derivative | Qualification |
| --- | ---: | ---: | --- |
| Quadruped touchdown → descending plane | `4.194775535240182e-12` | `-0.2039514920906454` | Tolerance-satisfying direct transition |
| Quadruped descending plane → touchdown | `6.224672390864328e-7` | `-3.632636649446923` | Accepted physical candidate; no root claim |
| Quadruped touchdown → other touchdown | `8.336144816615438e-12` | `-3.632643443580229` | Tolerance-satisfying direct transition |
| Quadruped touchdown → composite | `4.194775535240182e-12` | `-3.632643443594241` | Tolerance-satisfying direct transition |
| Biped touchdown → descending plane | `1.876276911616515e-14` | `-0.03089704691501132` | Tolerance-satisfying direct transition |
| Biped descending plane → touchdown | `0.04299363542136695` | `-0.1442676631466665` | Accepted physical candidate; no root claim |
| Biped touchdown → other touchdown | `0.04299360548669684` | `-0.1442677302437873` | Accepted physical candidate; no root claim |
| Biped touchdown → composite | `1.299946006845806e-13` | `-0.1442677302433354` | Tolerance-satisfying direct transition |

These values qualify the committed initialization points under their recorded
configuration. They are not global existence results. In particular, an
accepted transverse endpoint only proves that the direct trajectory reaches
the requested section; the contact residual must independently meet the
configured tolerance before the candidate is classified as feasible.

## Solve a quadruped touchdown return

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quadruped');
configuration = struct( ...
    'StartSectionId','back_left_touchdown', ...
    'StopSectionId','back_left_touchdown', ...
    'SymmetryId','planar_translation');
problem = model.createProblem('periodic_orbit',configuration);

u0 = problem.getDecisionSchema().defaults();
p = problem.getParameterSchema().defaults();
seed = problem.makeSolution(u0,p,[]);
context = lmz.api.RunContext.synchronous(1200);
result = lmz.services.SolveService().solve(problem,seed,struct( ...
    'AcceptExistingTolerance',1e-8, ...
    'FunctionTolerance',1e-10, ...
    'StepTolerance',1e-10),context);

assert(result.ExitFlag > 0);
assert(result.Evaluation.ScaledResidualNorm <= 1e-8);
assert(result.Evaluation.PhysicalValidity);
assert(result.Evaluation.Diagnostics.DirectSectionIntegration);
assert(~result.Evaluation.Diagnostics.SourceApexPhaseGaugePreserved);
```

The returned solution contains 21 local variables. Its first thirteen values
are the touchdown section coordinates; the remainder are seven positive
interior event gaps and the return time. The endpoint touchdown is bound to the
return time and is not duplicated as an interior event.

Run the repository-contained example with:

```matlab
run('examples/demo_quadruped_touchdown_periodic_orbit.m');
```

It writes an artifact only under a temporary output directory, returns the
structured variable `output`, and prints:

```text
LMZ_QUADRUPED_TOUCHDOWN_PERIODIC_ORBIT_OK
```

## Solve biped touchdown timing

Timing-only holds the initial section state and physical parameters fixed. It
solves the schedule constraints; it does not add periodic state closure.

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
configuration = struct( ...
    'StartSectionId','left_touchdown', ...
    'StopSectionId','left_touchdown', ...
    'SymmetryId','planar_translation');
problem = model.createProblem('section_return_timing',configuration);
result = lmz.services.ContactTimingService().solve( ...
    problem,problem.InputSchedule, ...
    struct('Solver','fsolve','ResidualTolerance',1e-9), ...
    lmz.api.RunContext.synchronous(1201));

assert(result.SolverDiagnostics.Success);
assert(result.SolverDiagnostics.RankDiagnostics.Rank == 4);
assert(result.SolverDiagnostics.RankDiagnostics.Nullity == 0);
```

The three interior events remain in `InputSchedule`; the next left touchdown
is represented by the return time. `ContactRowBindings` identifies that row as
`Kind='return'`.

The corresponding example is:

```matlab
run('examples/demo_biped_touchdown_timing.m');
```

Its exact marker is `LMZ_BIPED_TOUCHDOWN_TIMING_OK`.

## Solve descending state-plane returns

The validated planes are `y = 0.9` for the quadruped and `y = 0.95` for the
biped, both with descending direction `-1`. They retain every contact event in
the schedule and own an independent return time. A valid solve must have an
accepted, nongrazing crossing and a negative directional derivative.

```matlab
run('examples/demo_scientific_state_plane_shooting.m');
```

The example solves both models, records a separate `root_found` qualification
for each case, and prints
`LMZ_SCIENTIFIC_STATE_PLANE_SHOOTING_OK`.

## Transfer and continue in the target chart

`SectionTransferService` turns an apex solution into a genuine target-section
seed. The target solution stores its local decision, target configuration,
section fingerprints, rotated event schedule, and transfer lineage.

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
context = lmz.api.RunContext.synchronous(1203);
apexProblem = model.createProblem('periodic_apex',struct());
u = apexProblem.getDecisionSchema().defaults();
p = apexProblem.getParameterSchema().defaults();
evaluation = apexProblem.evaluate(u,p,context,true);
source = apexProblem.makeSolution(u,p,evaluation);

transferred = lmz.services.SectionTransferService().transfer( ...
    model,source,'left_touchdown',context);
target = model.createProblem('periodic_orbit', ...
    transferred.Solution.Lineage.Configuration);
reproduced = target.evaluate( ...
    transferred.Solution.DecisionValues, ...
    transferred.Solution.ParameterValues,context,true);
assert(transferred.DecisionCodecRephased);
assert(isequal(reproduced.Simulation.Time,transferred.Simulation.Time));
assert(isequal(reproduced.Simulation.States, ...
    transferred.Simulation.States));
```

Transfer back to `apex` reconstructs the apex-sized decision and reproduces
the same physical orbit.
For continuation, transfer both adjacent seeds, build the target problem from
the stored configuration, and create a fresh `SolutionPair`. Do not reuse an
apex seed pair or checkpoint in the target chart.

## Unsupported combinations and diagnostics

The support matrix is intentionally narrower than the section catalogs.

| Request | Diagnostic | Reason |
| --- | --- | --- |
| Quadruped/biped mixed start and stop in `periodic_orbit` | `lmz:Shooting:TransitionProblemRequired` | Periodic closure requires the same coordinate chart; use `section_transition` |
| Same start and stop ID in `section_transition` | `lmz:Shooting:TransitionDistinctSections` | Same-section closure belongs to `periodic_orbit` or `multiple_shooting` |
| Quadruped/biped mixed timing endpoints | `lmz:Timing:UnsupportedSection` | No validated timing provider for that pair |
| Customized apex side/direction through `periodic_orbit` | `lmz:Shooting:ApexPresetConfiguration` | The source-compatible apex preset is immutable |
| Load touchdown mixed with apex or stride boundary | `lmz:QuadLoad:UnsupportedSectionPair` | Only touchdown-to-same-touchdown is validated |
| Load touchdown pre-event side | `lmz:QuadLoad:UnsupportedSectionSide` | Only the post-reset touchdown chart is validated |
| Other load touchdown IDs | `lmz:QuadLoad:UnsupportedSection` | No validated load section codec for those endpoints |

Named-event → state-plane, state-plane → named-event, named-event → named-event,
and safe composite targets use the explicit `section_transition` problem.
Pairs marked as candidates above retain their measured residual qualification.
No mixed-section result is presented as periodic, and residual rows are never
deleted or padded to manufacture that label.

## Interpreting outcomes

Use the repository-wide qualification vocabulary:

- `root_found`: accepted termination, residual tolerance, and all configured
  physical checks passed;
- `least_squares_feasible`: a rectangular least-squares problem met its
  residual and physical tolerances;
- `best_known_residual`: the best returned candidate without a root claim;
- `local_infeasibility_evidence`: bounded local search failed under the stated
  formulation and bounds;
- `numerical_failure`: the solver did not provide an acceptable result; and
- `physical_validation_failure`: algebraic residuals may be small, but a
  crossing, event order, fixed row, finite-state, or energy check failed.

None of the last three labels proves global nonexistence. In particular, a
rank-deficient root can be physically valid while its timing parameterization
is nonunique.
