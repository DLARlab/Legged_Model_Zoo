# Legacy graphics audit

This audit records what the three pinned research repositories actually draw,
how those graphics are reached by their callers, and which behavior is carried
into the Legged Model Zoo `research_legacy` profile. It distinguishes measured
source behavior from comments in the source and from later LMZ enhancements.

## Immutable references and audit environment

| Model | Local reference | Pinned commit | Final source status |
|---|---|---|---|
| SLIP quadruped | `../SLIP_Model_Zoo` | `2c106101383ecee1b2a9d695efe09fbd72d5718a` | clean |
| SLIP biped | `../2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` | `4595146c5881a5313bc8fe92de85099193ef9be9` | clean |
| Quadruped with load | `../2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` | `19f3133073c988cc0c3424a647b4adbb60a90b99` | clean |

All three repositories were inspected read-only. No runtime path and no
ordinary test in LMZ depends on them. Source-helper execution is confined to
maintainer capture scripts.

The executable audit used MATLAB R2025b Update 5 on macOS arm64. The hidden
graphics path reported WebGL through ANGLE/Metal. `usejava('desktop')` was
false, so numeric capture and hidden raster capture were available but human
desktop approval was not.

The row-level inventory is [graphics-fidelity-map.csv](graphics-fidelity-map.csv).

## Quadruped: actual construction and update chain

The active GUI path is:

```text
SLIP_Quadruped_GUI
  -> branch click / data-tip selection
  -> Quadrupedal_ZeroFun_v2(X,Para)
  -> SLIP_Animation_Quad(P,axes.Position,UIAxes,AnimationMode='Detailed')
  -> SLIP_PeriodicOrbit_Quad(Y,...)
  -> SLIP_Trajectories_Quad(T,Y,...)
  -> SLIP_GRF_Quad(T,GRFs,...)
  -> per display frame: jitter duplicate T samples, interp1, update(t,y,P)
```

The animation does not own the GUI playback loop. The GUI selects 120 frames
over the chosen normalized interval and separately records GIF/MP4/keyframes.
`SLIP_Animation_Quad.rate` is `0.05` even though its comment says 25 fps;
the GUI independently records at 25 fps.

### Named source data

The visualization state is
`[x,dx,y,dy,phi,dphi,alphaBL,dalphaBL,alphaFL,dalphaFL,alphaBR,dalphaBR,alphaFR,dalphaFR]`.
The parameter vector is eight touchdown/liftoff times followed by
`tAPEX,k,ks,J,l_rest,osa,lb,kr`.

For body position `(x,y,phi)`:

```text
back hip  = [x-lb*cos(phi),     y-lb*sin(phi)]
front hip = [x+(1-lb)*cos(phi), y+(1-lb)*sin(phi)]
gamma     = alpha + phi
stance length = hip_y/cos(gamma)
flight length = l_rest
```

Each event is wrapped once by adding or subtracting `tAPEX`. Contact uses
strict boundaries. An exact touchdown or liftoff sample is flight; a wrapped
stance interval uses `t < LO || t > TD`. There is no cosine guard.

### Body, legs, COM, ground, and phase overlay

`ComputeBodyGraphics` returns an 80-vertex perimeter, 13 two-vertex shading
faces, and a five-point outline. The nominal local body is 1.2 by 0.4. When
`lb ~= 0.5`, height becomes 0.45 and the skew is
`sign(0.5-lb)*sqrt(abs((0.5-lb)*10))/15`; local x is shifted by `0.5-lb`.
The body is then rotated by `phi` and translated.

Every leg is six patch handles, not a straight line:

1. a 15-vertex connected zig-zag spring;
2. an upper white background;
3. eight upper gray hatch segments;
4. a 26-vertex upper outline;
5. a 54-vertex lower leg with a circular point foot;
6. seven alternating spring segments.

Compression is `(length-rest)/rest`. Spring half-width is `0.09`; the spring
edge is `[245 131 58]/256`, width 5. Upper hatching is 0.8 gray, width 3;
the lower patch has a black edge, width 3. Raw constants stay in the research
geometry/style layer.

The COM exists only when `lb ~= 0.5`. Its outer radius is 0.075 even though
the configured radius is 0.15; the quartered inner radius is 0.1125, so the
inner sectors intentionally exceed the outer circle.

The ground is two patches built once: a white below-ground field and a hatch
with 20,002 vertices and 5,001 faces. Its true hatch extent is approximately
`[-50,200.01]`; the shorter source comment is stale.

The detailed phase box follows body x. It has one box, four labels, and two
patches per leg. Non-wrapped stance draws a white base plus black stance
duration; wrapped stance draws a black base plus white flight interval.

Bottom-to-top source order is left legs, ground, body, optional COM, right
legs, then detailed title/phase overlay. A detailed asymmetric scene has 45
axes children. Updates mutate vertices/XData/YData and retain this order.

### Camera and source qualifications

The source tracks `x + [-1.5,1.5]` with y `[-0.1,2]` and hides both rulers.
This pinned source does **not** call `axis equal`; R2025b measured data aspect
ratio `[1.5,1.05,1]`. Round 8 requests an equal research camera, so equal
aspect is recorded as a prompt-level intentional deviation, not exact source
behavior.

Other qualified corrections are:

- source-default dark edges are frozen explicitly as black for portability;
- incremental GRF update swaps right-front/right-hind relative to its legend;
  LMZ preserves the intended construction map `[1,2,4,3]`;
- `TD == LO` leaves source phase locals undefined; LMZ renders a defined
  zero-duration contact;
- source phase colors are fixed at construction if event topology changes;
  LMZ keeps the semantic color on profile rebuild.

## Biped: actual construction and update chain

The five gait calls in `Main.m` all use:

```text
ShowTrajectory_BipedalDemo
  -> normalize four event times around P(5)
  -> compute left/right vertical GRF
  -> construct SLIP_Model_Graphics_PointFeet_BipedalDemo
  -> interpolate state for every display frame
  -> update(state,eventTimes,time)
  -> construct a second renderer for MPEG-4 recording
  -> plot vertical GRFs
```

State order is `[x,dx,y,dy,alphaL,dalphaL,alphaR,dalphaR]`; parameters are
`[LTD,LLO,RTD,RLO,tAPEX,k,omega]`. Geometry uses x, y, and the two angles.
Contact uses the same strict wrapped predicate as the quadruped. Stance length
is `y/cos(alpha)` and flight length is exactly 1, with no guard or clamp.

### Patch geometry and order

The body is a 40-sample radius-0.2 white circular patch, edge width 5. The
quartered COG contains four alternating black/white radius-0.1 sectors, each
with 12 points, edge width 3.

Each point-foot leg has two overlapping spring patches, one 26-vertex upper
patch, and one 54-vertex post-update lower-leg/point-foot patch. Spring
half-width is 0.09 and its edge is `[0 68 158]/256`, width 5. Left fill is
`[202 202 202]/256`; right fill is white. The animated setter deliberately
uses the same post-update lower geometry for both legs, overriding a transient
constructor-only left/right width discrepancy. Primary fixtures therefore use
post-update geometry.

The ground is a white mask plus the same 20,002-vertex/5,001-face hatch family.
Creation order is left leg, mask, hatch, body, right leg, COG. That makes the
left leg lie behind the body and the right leg in front. The mask can hide the
left flight foot below ground while the later-created right foot remains
visible.

Every update tracks x with `[-1.5,1.5]`, uses y `[-0.3,2]`, and retains equal
aspect. The renderer contains no title, labels, force arrows, phase label, or
gait annotation.

### Display, recording, and plots

Display uses approximately 50 samples per source-time unit, omits the final
endpoint, and pauses 0.03 seconds. Recording uses approximately 100 samples
per source-time unit, a second figure, `MPEG-4`, quality 100, and the writer's
default frame rate (30 fps in the audited release). These loops remain in LMZ
services, not the model renderer.

`Main.m` plots all eight state columns. The animation helper separately plots
only left/right vertical GRF:
`(1-y/cos(alpha))*k*cos(alpha)` during contact. There is no source footfall
plot, horizontal/magnitude GRF plot, or gait label in this path; those LMZ
views are retained enrichments and are not described as source graphics.

## Load-pulling quadruped: actual construction and update chain

Single-stride Section 2 constructs `Animation`, `Footfall`, and `Tugline`.
Transition Section 3 constructs `Footfall`, `LegTrajectories`, `Tugline`,
`Animation`, and two-axis `Sensitivity`. Only the animation is updated during
playback; the analysis plots remain static.

The load repository's `ComputeBodyGraphics`, `ComputeJoint_LegLA`,
`ComputeLegGraphics`, and `OutputCLASS` are byte-for-byte identical to the
pinned quadruped repository versions. The load research renderer therefore
reuses the quadruped body/leg/COM/ground providers.

### Load, rope, camera, and stride selection

For load state `(load_x,load_y)`, the source patch is:

```text
X = [load_x-load_y, load_x+load_y, load_x+load_y, load_x-load_y]
Y = [0,               0,             2*load_y,      2*load_y]
```

The rope is a degenerate four-vertex patch with duplicated endpoints from
quadruped COM `[state x,state y]` to load center `[load_x,load_y]`. Load and
rope are black, alpha 0.3, black edge, width 2. Rope appearance does not encode
tension and remains visible when unilateral tugline force is zero.

Bottom-to-top order is left legs, ground, body, COM, right legs, load, rope.
The camera follows body x with `[-3,1.5]`, y `[-0.1,2]`, plot-box aspect
`[2,1,1]`, hidden rulers, and title `SLIP Quad-Load Animation`.

The literal transition caller supports two rows: `t < P(1,9)` selects row 1;
the exact boundary selects row 2 and offsets row-2 columns 1:9 by the first
duration. LMZ generalizes this to N rows using cumulative ends, retains the
exact-boundary-later rule, and offsets the selected row's event/apex columns
by all preceding durations.

### Analysis plots

- Footfall receives simulation first despite its reversed comment. Actual
  simulation pixels use LH blue, LF yellow, RF orange, RH green, while its
  dummy legend advertises the reverse intended mapping. Research plots retain
  and label this qualification.
- Leg trajectories are angular velocities `Y(:,[8,10,14,12])`, plotted over
  normalized stride count rather than physical time.
- Tugline uses a blue width-2 simulation line; structured experiment data is
  a dotted dark-red mean plus alpha-0.3 standard-deviation band.
- Sensitivity recomputes relative curves and sorted percentage variation from
  `C`; it ignores stored precomputed deltas.
- The source has numeric R-squared fields, not an R-squared plot class. The LMZ
  bar view is a modern analytical enrichment.

## Fidelity and approval levels

The release evidence uses three separate labels:

1. **geometry-tested**: numeric vertices, faces, endpoints, layers, camera,
   and style constants match committed fixtures;
2. **image-metric-tested**: hidden renders pass platform-tolerant RMSE, edge,
   foreground-bound, and color-cluster checks on the recorded release;
3. **human-approved**: a person completed a desktop side-by-side review.

Only the first two can be automated in the current headless environment.
Human side-by-side approval remains blocked until a MATLAB desktop is
available and must not be inferred from batch captures.

## Redistribution qualification

Adapted geometry, numeric fixtures, and locally generated source rasters
inherit their source repository's current redistribution decision. No source
golden image is published while authority is unresolved. The load README says
BSD-3-Clause but the pinned repository contains no license file; that claim is
not treated as authoritative permission.
