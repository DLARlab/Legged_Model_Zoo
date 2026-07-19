# Legacy algorithms

The quadruped source contains direct nonlinear solving plus one-dimensional and repeated parameter-scan continuation. The latter must be migrated as `BranchFamilyScan`, not called two-dimensional continuation. Jerboa has its own continuation/corrector and retry logic. Load-pulling fitting combines simulation and objective calculation. Detailed behavioral extraction awaits executable baseline capture and will precede numerical changes.
