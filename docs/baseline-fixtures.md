# Baseline fixtures

Selected candidates and SHA-256 hashes:

| Model | Fixture | SHA-256 |
|---|---|---|
| Quadruped | `PK_20_2.mat` | `45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401` |
| Jerboa | `Section2_solution_examples/W1.mat` | `52a6243833851ab9e498b0eb60e5489ab78747a3f9ff05c9be02d5c66e61d6dc` |
| Load pulling | `Section2_Single_Stride_Replication/P3_Individual_1_TR.mat` | `56736cc33ab31a0ab40b3de6783b625a07ebd54f1ae6a561b47aea5e04cd6abe` |

Numerical capture remains unexecuted. MATLAB is not installed in the current environment, so no residual, event, trajectory, force, classification or objective value is claimed.

Static MAT inspection on 2026-07-19 confirmed `results` is 29-by-891 for the quadruped, `results` is 14-by-215 for Jerboa, and the load fixture contains `X_accum` 44-by-1 plus `gait_data`, `gait_type`, and `term_weights`. Historical source-fixture regeneration is isolated under `tools/maintainers/` and is not part of standalone installation or runtime usage.
