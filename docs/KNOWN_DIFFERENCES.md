# Known differences

- Native evaluation is not implemented; model stubs fail explicitly instead of silently delegating.
- No event schedule repair or parameter transform occurs inside residual evaluation.
- Registry configuration is declarative and implementation classes are restricted to `lmzmodels.*`.
- The prior tracked project contents were already deleted in the working tree at task start and were not restored wholesale.
