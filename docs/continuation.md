# Continuation

The native engine traces a one-dimensional solution set without requiring the residual row count to equal `n-1`. It uses problem chart differences, schema scales, a metric-normalized secant predictor, and a weighted pseudo-arclength corrector. The current implementation supports bidirectional tracing, adaptive correction step reduction/growth, duplicate rejection, cancellation, progress, and checkpoint callbacks.

Current limitations are file-backed checkpoint resume, cyclic lifted coordinates across repeated wraps, curvature/stagnation controllers, and historical segment loop closure. Native stride-closure tests pass; published model continuation equivalence is not claimed.
