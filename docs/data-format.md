# Native data format

`Solution` owns model/problem identity, ordered decision/parameter schemas, values, observables, residual blocks, diagnostics, classification, feasibility, lineage, provenance, and creation time.

`SolutionBranch` stores decisions and parameters as `nVariable × nPoint` matrices. Per-point observables/classifications are struct cells; fixed metadata preserves residual blocks, feasibility, diagnostics, and a source record. `point(index)` reconstructs the complete `Solution`. Named coordinates cover decisions, parameters, and scalar observables. Arclength and nearest-point distance use schema scales and cyclic charts.

## Quadruped Results29 boundary

Only `Results29Layout`, `Results29Adapter`, and the compatibility boundary interpret raw rows:

```text
1:13   periodic initial condition
14:21  four touchdown/liftoff pairs
22     positive apex return / stride period
23:29  k_leg, k_swing, J_pitch, l_leg, phi_neutral, l_b, k_r_leg
```

The 22 decision values are rows 1:22; the integrated physical state is separately named and has 14 entries beginning with horizontal position `x`. They must not be conflated.

The RoadMap manifest records source repository/commit/path and, for every asset, `name`, `relativePath`, SHA-256, size, kind, point/row count, legacy variable, parameter summary, `inferredGaitSummary`, and native artifact path. Catalog construction validates this per-record contract and the total point count. Runtime prefers a native artifact only when its stored legacy SHA matches the current copied MAT. Maintainers can explicitly rebuild all natives; verification covers all nine MAT and both FIG hashes.

Raw baseline trajectories retain the source evaluator's duplicate event timestamps. Public `SimulationResult` trajectories keep the final sample at each repeated time so `Time` is strictly increasing, while `EventRecords` preserve event, pre-event, and post-event states separately.

Native MAT files contain exactly one top-level `artifact` struct. Supported types include solution, branch, solve-run, continuation-run, optimization-run, simulation, checkpoint, and branch-family-report. `ArtifactStore` validates common schema/dimension/finite metadata and uses an atomic temporary-save/rename sequence.

## Biped Results14 boundary

Only `Results14Layout` and `Results14Adapter` interpret biped branch rows:

```text
1:12   dx, y, dy, alphaL, dalphaL, alphaR, dalphaR,
       tL_TD, tL_LO, tR_TD, tR_LO, tAPEX
13:14  offset_left, offset_right
```

The integrated state is separately named and contains eight entries (`x`,
`dx`, `y`, `dy`, and the left/right leg angle/rate pairs). The GaitMap manifest
records six immutable files, hashes, gait labels, recommended indices, native
paths, and a total of 2,967 points. Exact encoding of an unchanged branch
reconstructs the 14-row `results` matrix.

## Load-pulling X_accum boundary

`FirstStrideLayout`, `LaterStrideLayout`, `MultiStrideDecisionSchema`, and
`XAccumAdapter` are the only authorities for load decision indexing. The first
44 entries are:

```text
1:13   quadruped initial state
14:22  nine touchdown/liftoff/apex event times
23:36  14 quadruped physical/swing parameters
37:38  load horizontal state
39:44  load/tugline/slope parameters
```

Each later stride contributes 13 entries: nine named event times followed by
four post-contact swing stiffnesses. Therefore the exact decision dimension is
`44 + 13*(N-1)`. The physical simulation state is a separate 18-entry schema:
14 quadruped states followed by load `x`, `dx`, `y`, `dy`. `XAccumAdapter`
round-trips the complete legacy vector and retains experimental template,
weights, stored R-squared/sensitivity data, dataset identity, and provenance.

## Maturity and run metadata

Every solution/artifact records the problem descriptor’s maturity,
validation status, and provenance in addition to model/problem versions.
Continuation snapshots normalize predictor, corrected decision, residual,
step/curvature/backtracking, feasibility/gait, checkpoint, and termination
candidate fields. Optimization artifacts retain the full decision schema even
when exact fixed bounds allow `FminconSolver` to operate on a reduced free
subvector; free and fixed indices are included in solver output.
