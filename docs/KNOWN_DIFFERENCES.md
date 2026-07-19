# Known differences

- Native evaluation is not implemented; model stubs fail explicitly instead of silently delegating.
- No event schedule repair or parameter transform occurs inside residual evaluation.
- Registry configuration is declarative and implementation classes are restricted to `lmzmodels.*`.
- The prior tracked project contents were already deleted in the working tree at task start and were not restored wholesale.
- Catalog capabilities are deliberately false until executable problem/service support exists; merely retaining an adapter does not advertise simulation or solving.
- Artifact schema version `1.0.0` now requires explicit diagnostics, lineage, random seed, source commits, and ordered schema metadata. Earlier incomplete development artifacts are rejected rather than guessed into shape.
