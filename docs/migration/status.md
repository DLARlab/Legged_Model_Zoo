# Migration status

| Phase | Status | Evidence / limitation |
|---|---|---|
| 0 inventory | complete | source inventory, mapping, baseline and repository metadata recorded |
| 1 characterization | partial | layouts and comparison semantics captured; MATLAB fixture execution unavailable |
| 2 core/registry | implemented | manifests, schemas, registry, data objects, persistence and unit tests |
| 3 quadruped | partial | model, named schemas, problem, codec, import and views; clean-room dynamics are demonstration-level, not full legacy parity |
| 4 solvers/continuation | implemented | root/optimization/multi-start, pseudo-arclength, analytic fold test, branch persistence/view |
| 5 jerboa | partial | model/schema/problem/view contract; research equations and parity fixtures remain |
| 6 load model | partial | model, load channel and arbitrary-N codec; research transition equations/objective terms remain |
| 7 visualization | implemented baseline | scene specs, named frames, renderer lifecycle and duplicate-time controller |
| 8 GUI | partial | programmatic app, six required tabs, registry/controller routing; advanced editors/background execution/export remain |
| 9 authoring/docs | implemented baseline | template manifest/model/assets and authoring guide |

The repository is a functional architectural baseline, not a scientifically validated replacement for the source research models. This distinction is intentional and test-visible.
