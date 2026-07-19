# Legacy source inventory

The three references were verified by Git origin and commit; see `provenance.md`.

## SLIP quadruped

Core evaluation is `1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m`; solving enters through `SolveQuadrupedalZE.m`. One- and two-parameter routines live under `3_Numerical_Continuation/1_Continuation_Algorithm`. Event repair and gait classification are `4_Solution_Management/EventTimingRegulation.m` and `Gait_Identification.m`. Roadmap MAT/FIG fixtures are present under `P1_.../1_Roadmap`.

## Jerboa

Entry points are `Main.m` and `Section3_optimization/Optimization.m`. Residuals, continuation, gait classification, resampling and graphics are under `Stored_Functions`. Walk, run, hop, skip and asymmetric-run MAT fixtures exist under `Section2_solution_examples`.

## Load pulling

Replication scripts are in the Section 2 and 3 directories. Dynamics, multistride simulation/objective, event timing and graphics are under `Stored_Functions`. Section-specific MAT fixtures are present.

Recursive call/global/path/toolbox analysis is incomplete. No reference repository was changed.
