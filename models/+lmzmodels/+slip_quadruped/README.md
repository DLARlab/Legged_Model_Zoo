# Scientific SLIP quadruped usage

`slip_quadruped/periodic_apex` is the validated RoadMap problem. It preserves
the 29-row Results29 import/export contract as 22 named decisions plus seven
named parameters. `slip_quadruped/demo_stride` is a separate analytic tutorial
and does not make the RoadMap scientific-reproduction claim.

Run `startup` once from the repository root before using these APIs.

## Load and simulate a RoadMap point

```matlab
startup;
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quadruped');
problem = model.createProblem('periodic_apex', struct());

catalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
branch = catalog.loadBranch(catalog.defaultBranchPath(), problem, true);
index = catalog.recommendedSeedIndex(catalog.defaultBranchPath());
solution = branch.point(index);

context = lmz.api.RunContext.synchronous(0);
evaluation = problem.evaluate(solution.DecisionValues, ...
    solution.ParameterValues, context, true);
simulation = evaluation.Simulation;
```

The repository-contained native branch retains source file/column/hash and
classification metadata. Pass `false` to `loadBranch` to decode the unchanged
legacy MAT data. Exact Results29 reconstruction is:

```matlab
results = lmzmodels.slip_quadruped.Results29Adapter.encode(branch);
```

Simulation output uses named states, event records, contact modes, four feet,
all available GRF channels, observables, and physical parameters. Visualization
code consumes those names; it does not embed Results29 row indices.

## Direct mixed-section shooting

Use `section_transition` when the start and stop section IDs differ. The route
accepts the catalog's named-event, descending state-plane, and safe composite
endpoints. It builds a `TransitionMultipleShootingProblem` with one direct
segment and an explicit terminal target; it does not reinterpret the request as
a periodic orbit.

```matlab
configuration = struct( ...
    'StartSectionId','back_left_touchdown', ...
    'StopSectionId','descending_y_0_9', ...
    'StartStateFreeMask',true, ...
    'TargetStateFreeMask',true, ...
    'EventFreeMask',false);
transition = model.createProblem('section_transition',configuration);
u0 = transition.getDecisionSchema().defaults();
p = transition.getParameterSchema().defaults();
context = lmz.api.RunContext.synchronous(41);
evaluation = transition.evaluate(u0,p,context,false);
direct = transition.evaluateShooting(u0,p,context,false);

assert(strcmp(transition.Formulation,'transition'));
assert(strcmp(transition.Horizon.Target.SectionId, ...
    'descending_y_0_9'));
assert(~transition.Horizon.Target.PeriodicClosure);
assert(evaluation.PhysicalValidity);
assert(direct.SegmentResults{1}.Crossing.Accepted);
assert(direct.SegmentResults{1}.Crossing.CrossingDirection == -1);
assert(~direct.SegmentResults{1}.Diagnostics.ApexOracleUsed);
```

`StartStateFreeMask` and `TargetStateFreeMask` may be scalar logical values or
vectors matching their respective section-coordinate schemas.
`EventFreeMask` may be scalar, `[interior_events return_time]`, or one logical
entry per active schedule coordinate. With the default fixed schedule, the
tested touchdown-to-descending-plane seed has scaled residual norm
`4.194775535240182e-12`. The reverse plane-to-touchdown path reaches an
accepted transverse crossing but retains residual `6.224672390864328e-7`, so
it is an explicitly qualified candidate rather than a claimed root.

Inspect `evaluation.ResidualBlocks` for
`segment_1_contact_constraints`, `segment_1_section_residual`,
`interface_1_defect`, and `final_transition_target`. A transition never emits
`final_section_closure`. Same-section periodic work remains on
`periodic_orbit` or `multiple_shooting`. The complete pair matrix and
qualifications are in `docs/scientific-section-shooting.md`.

## Visualization profiles

The model manifest declares the visualization contract frames `world`, `body`,
`foot_bl`, `foot_fl`, `foot_br`, and `foot_fr`, plus the top-level parameter
roots `l_leg` and `l_b`. `graphics.lmz.json.requiredFrames` and
`.requiredParameters` repeat those requirements. Registry discovery binds the
graphics names to the manifest contract and validates the declarative profile
scene; the research geometry then retrieves `l_leg` and `l_b` by name at
runtime rather than using state/parameter positions.

The model owns `catalog/slip_quadruped/graphics.lmz.json` and three profiles:

| Profile | Default/applicability | Renderer | Meaning |
| --- | --- | --- | --- |
| `research_legacy` | Default for validated `periodic_apex` | `lmzmodels.slip_quadruped.ResearchRenderer` | Source-derived compound animation and research plot profile |
| `clean_generic` | Default for tutorial `demo_stride`; selectable for all maturities | `lmz.viz.SceneRenderer2D` | Declarative straight-link scene; intentionally not source-faithful |
| `high_contrast` | Selectable for validated problems | `lmzmodels.slip_quadruped.ResearchRenderer` | Same compound geometry with an accessibility palette/heavier widths |

In the GUI, open **Physical Simulation** and choose **Visual profile**. The
choice is stored for `slip_quadruped/<problem-id>`. **Detailed** controls the
source title/phase diagram; **Ground** selects hatched, line-only, or hidden;
**Forces** controls LMZ force arrows; **Follow** and **Reset camera** control the
profile camera. Switching profile replaces the renderer without changing the
simulation data.

## Research animation mapping

The audited source path constructs `SLIP_Animation_Quad`, then updates it with
interpolated state, time, and model parameters. LMZ leaves interpolation and
playback in `AnimationController` and maps source graphics to pure geometry:

| Source graphics behavior | LMZ owner |
| --- | --- |
| Nominal 1.2-by-0.4 body, asymmetric `l_b` skew/offset, shading, outline | `ResearchBodyGeometry` |
| Six layered parts per leg: two spring groups, upper background/shading/outline, lower point-foot patch | `ResearchLegGeometry` |
| Hip attachments, absolute angle, strict wrapped contact, compression/rest-length scaling | `ResearchLegGeometry.frame` |
| Asymmetric-morphology quartered COM symbol | `ResearchCOMGeometry` |
| White ground field plus dense diagonal hatch | `ResearchGroundGeometry` |
| LH/LF/RF/RH phase bars, labels, title, wrapping, body-following placement | `ResearchPhaseDiagramGeometry` |
| Left legs, ground, body/COM, right legs, forces, detailed overlay | `ResearchRenderer` handle order |

The research spring color is `[245 131 58]/256`. Each frame mutates existing
vertices/XData/YData; the dense ground geometry is created once. The COM is
shown only when the back attachment ratio differs from `0.5`.

The configured research camera follows body x with `[-1.5,1.5]`, fixes y to
`[-0.1,2]`, hides rulers, uses a white background, and applies equal data
aspect. Equal aspect is a Round 8 requirement and a documented deviation: the
pinned source did not call `axis equal` and had a release/layout-dependent
measured aspect.

## Research analysis plots

The selected plot profile is passed to `QuadrupedPlotProvider`:

- `research_legacy` and `high_contrast` use source-style torso, back-leg, and
  front-leg ordering and LaTeX labels;
- the research GRF view shows the four vertical channels in intended
  LH/LF/RF/RH order; and
- the research oscillator view preserves the leg/event cycle arrangement.

The pinned incremental source GRF updater swapped the right-front/right-hind
channels relative to construction and legend. LMZ preserves the intended
construction mapping and attaches a qualification to the research axes. The
`clean_generic` plot profile retains the broader modern magnitude/x/y GRF and
normalized contact views.

## Qualified source differences

- Old figure, axes-position, path setup, pause/interpolation, and output loops
  are replaced by framework-owned axes, animation, and recording services.
- Theme-dependent source edges are frozen as explicit RGB black for stable
  rendering.
- The source's undefined `TD == LO` phase local is represented as a defined
  zero-duration contact.
- Force arrows are an optional LMZ overlay and are not used as evidence for the
  source animation geometry claim.
- `high_contrast` deliberately changes the source palette and line widths.
- `clean_generic` uses straight links by design and must not be used as a
  research-fidelity reference.

## Programmatic profile use

The public helper loads the recommended branch, simulates `periodic_apex`, and
constructs the requested renderer through `RendererFactory`:

```matlab
session = lmz.examples.ResearchGraphics.open( ...
    'slip_quadruped', 'research_legacy', 'off');
cleanup = onCleanup(@() lmz.examples.ResearchGraphics.close(session));
summary = lmz.examples.ResearchGraphics.renderFrames( ...
    session, [0 0.37 0.73 1]);
```

For an existing `simulation`, resolve explicitly:

```matlab
profiles = lmz.viz.VisualizationProfileRegistry(registry);
factory = lmz.viz.RendererFactory(registry, profiles);
figureHandle = figure;
figureCleanup = onCleanup(@() delete(figureHandle));
axesHandle = axes('Parent', figureHandle);
[renderer, profile] = factory.createRenderer(axesHandle, simulation, ...
    'slip_quadruped', 'periodic_apex', 'research_legacy', ...
    struct('DetailedOverlay', true, 'ShowForces', false, ...
    'GroundVisible', true, 'GroundStyle', 'hatched', ...
    'CameraFollow', true, 'Palette', 'research_legacy'));
rendererCleanup = onCleanup(@() delete(renderer));
```

## Recording and sidecars

GUI GIF, MP4, keyframe, plot, and oscillator-GIF exports use the current
profile. Applicable `recordingProfile` defaults seed frame count, FPS/delay, and
DPI. Each GUI output receives an adjacent `.lmz.json` sidecar with artifact
kind, model/problem IDs, the resolved profile descriptor, and timestamp.

Direct `RecorderService` calls must pass profile metadata explicitly (omitted
operational values use service defaults):

```matlab
target = fullfile(tempdir, 'quadruped-research.gif');
metadata = struct('schemaVersion', '1.0.0', ...
    'modelId', 'slip_quadruped', 'problemId', 'periodic_apex', ...
    'visualizationProfile', profile.toStruct());
lmz.services.RecorderService().recordGif(renderer, target, ...
    struct('FrameCount', 40, 'DelayTime', 0.04, ...
    'Metadata', metadata), context);
```

The recorder restores the original frame and removes temporary files on
success, cancellation, or error. The renderer never owns a recording loop.

## Fidelity evidence and compatibility

Numeric body, leg, COM, ground, and phase fixtures live under
`tests/fixtures/graphics/slip_quadruped`; geometry, renderer, plot, and profile
tests live under `tests/visualization`. The exact source file/formula/caller map
and all qualifications are in `docs/legacy-graphics-audit.md` and
`docs/graphics-fidelity-map.csv`.

Numeric geometry and hidden image metrics do not constitute human approval.
The MATLAB desktop side-by-side review remains a separate manual gate. R2019b
is a static compatibility target only; current graphics runtime evidence comes
from the documented newer MATLAB release.

## Examples

```text
demo_slip_quadruped_roadmap_workflow.m
demo_slip_quadruped_solve.m
demo_slip_quadruped_continuation.m
demo_quadruped_research_graphics.m
demo_visual_profile_switching.m
demo_research_graphics_recording.m
demo_graphics_comparison_gallery.m
```

## Provenance and redistribution

The graphics audit uses pinned source commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a`. Adapted geometry and numeric
fixtures inherit the repository's unresolved redistribution decision. Their
presence in this source tree is not a public packaging grant; consult
`docs/REDISTRIBUTION_STATUS.md` before distribution.
