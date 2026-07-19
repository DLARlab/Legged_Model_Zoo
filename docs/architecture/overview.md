# Architecture overview

The GUI and examples use service objects. Services consume `NonlinearProblem`; a problem owns task-specific schemas and evaluates a `LeggedModel`; models produce serializable simulation results. Model registry discovery scans manifests and contains no concrete model list. Executable equations remain MATLAB code.

The core is headless. Visualization consumes results and named kinematic frames. Duplicate event times use explicit pre/post selection. Persistence stores schema, model/problem identity, diagnostics and provenance. Legacy indices exist only in named codecs.
