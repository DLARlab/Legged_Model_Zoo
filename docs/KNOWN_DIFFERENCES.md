# Known differences

- Native evaluation is not implemented; model stubs fail explicitly instead of silently delegating.
- No event schedule repair or parameter transform occurs inside residual evaluation.
- Registry configuration is declarative and implementation classes are restricted to `lmzmodels.*`.
- The prior tracked project contents were already deleted in the working tree at task start and were not restored wholesale.
- Catalog capabilities are deliberately false until executable problem/service support exists; merely retaining an adapter does not advertise simulation or solving.
- Artifact schema version `1.0.0` now requires explicit diagnostics, lineage, random seed, source commits, and ordered schema metadata. Earlier incomplete development artifacts are rejected rather than guessed into shape.
- Round 3 built-in simulations are explicitly labeled standalone analytic demonstrations. They exercise common runtime and GUI boundaries but are not claimed equivalent to the published legacy equations.
- Canonical model IDs are `slip_biped`, `slip_quadruped`, and `slip_quad_load`. Older IDs resolve only through warning-producing registry/artifact aliases.
- Round 4 periodic problems solve the native relation `speed * stride_period = stride_length`, with an explicitly redundant residual block to exercise rank-deficient formulation and generic continuation. This is not the published biped or quadruped residual.
- Round 4 fitting problems use deterministic named quadratic targets. They exercise real `fmincon` and objective decomposition but are not equivalent to the published trajectory/load objectives.
- Continuation currently provides secant prediction, metric-weighted correction, adaptive step reduction/growth, duplicate rejection, bidirectional tracing, callbacks, and cancellation. File-backed checkpoint resume, curvature control, stagnation, and historical loop closure remain incomplete.
