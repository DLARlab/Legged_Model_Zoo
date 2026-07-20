# Contributing

Thank you for improving Legged Model Zoo. This repository treats numerical
behavior, provenance, and redistribution status as part of the implementation,
so a change is complete only when its evidence and documentation agree.

## Before opening a change

1. Read `docs/API_STABILITY.md`, `docs/architecture.md`, and
   `docs/REDISTRIBUTION_STATUS.md`.
2. Do not add code, data, figures, or derived fixtures unless you have the
   authority to contribute them and record their source, commit/hash, license,
   required notice, and redistribution decision.
3. Never replace a source-equivalence fixture, loosen a scientific tolerance,
   or change an imported compatibility evaluator merely to make a test pass.
4. Keep model-specific equations under `models/+lmzmodels`; generic APIs,
   services, I/O, registry, and presentation code belong under `src/+lmz`.
5. Treat external plug-in code as trusted executable MATLAB code. Treat MAT,
   JSON, and scene files as untrusted data and use the guarded loaders.

## Development workflow

Start MATLAB in the repository root and run:

```matlab
startup;
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Also run the MATLAB-free checks and Code Analyzer gate:

```text
python3 tools/ci/static_checks.py --all
```

```matlab
addpath(fullfile(pwd, 'tools'));
quality = run_code_quality;
assert(isempty(quality.Violations));
```

Use `tools/new_model.m` for a model scaffold. Generated models are not added to
the production catalog automatically. New model contributions should include
simulation, solve/continuation when claimed, artifact, scene, security, and
clean-registration tests as described in `docs/testing-a-model.md`.

## Change expectations

- Preserve stable APIs or follow the deprecation policy.
- Update release notes for provisional API changes.
- Add focused tests for fixes and new behavior.
- Keep examples deterministic, repository-contained, and non-interactive when
  a headless equivalent is possible.
- Record the MATLAB release, toolboxes, platform, and exact commands used.
- Keep generated package binaries and local coverage reports out of commits.
- Do not claim remote CI, R2019b runtime, desktop usability, or redistribution
  approval without the corresponding evidence.

The project has no root redistribution license while owner decisions remain
open. A contribution does not by itself resolve the licensing status of
existing material. Release gates must remain fail-closed until an authorized
decision is recorded.
