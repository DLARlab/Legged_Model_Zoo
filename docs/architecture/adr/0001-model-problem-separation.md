# ADR 0001: Separate model and problem

Accepted. Physical hybrid dynamics and kinematics implement `LeggedModel`; decision variables, residuals, objectives and constraints implement `NonlinearProblem`. This permits multiple numerical tasks per model and keeps solvers model-agnostic.
