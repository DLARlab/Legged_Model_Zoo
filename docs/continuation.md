# Continuation

The generic engine traces a one-dimensional solution set without assuming a particular residual shape. `SecantPredictor` uses problem chart differences and a schema diagonal metric. `PseudoArclengthCorrector` solves the scaled residual plus the metric arclength hyperplane.

Round 5 behavior includes:

- direct adjacent RoadMap pairs or a generated second seed;
- a transient lifted branch-history chart for cyclic timing values plus schema-provided scales;
- prediction, accepted, and rejected callbacks;
- retry/backtracking, bounded growth, and curvature-based shrinkage;
- duplicate checks against the lifted history and historical-segment loop-closure checks;
- stagnation detection and explicit termination reasons;
- feasibility and optional acceptance-policy hooks;
- cooperative pause, resume, cancellation/controlled stop, and partial branch preservation;
- atomically replaced checkpoint artifacts and resume from the last two accepted points while retaining the prior lifted history and adaptive step;
- bidirectional tracing whose `MaximumPoints` is the total returned branch size.

The default RoadMap seed pair is PK columns 267/268. Their parameters match exactly, their gait is PF, and their chart distance is stored in `SolutionPair.Diagnostics`. A three-point scientific run accepted its first corrected point at residual `2.05e-11` with no rejection.

Parameter homotopy uses one of the seven schema names. A branch-family scan transports the seed and repeats one-dimensional continuation at target values; it is not two-dimensional continuation.

The lift is numerical run state rather than serialized as a second public branch coordinate matrix. Checkpoints reconstruct it from stored decisions on resume. Very long branches crossing many timing wraps remain a cross-release stress-test item.
