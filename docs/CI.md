# Continuous integration

The repository defines three GitHub Actions workflows. They are configuration,
not evidence of a successful remote run. A maintainer must push the branch and
inspect the resulting checks before reporting that CI passes.

## Workflows

- `static.yml` runs JSON, README, architecture, R2019b static-compatibility,
  redistribution-manifest, hash, completeness (including unlisted-file), and
  whitespace checks without MATLAB. Decision inheritance and profile selection
  remain authoritative only in the MATLAB redistribution scanner.
- `matlab.yml` runs the complete suite on the latest MATLAB and R2021a on Linux,
  plus a latest-release macOS smoke job. The extended latest/Linux job also
  reruns the official test action for JUnit and Cobertura reports and uploads
  only those two reports as CI artifacts; only
  `src` and `models` are coverage roots, while test support folders arrive via
  `MATLABPATH`. R2021a is the oldest release supported by the current official
  hosted Setup MATLAB action; it is not evidence for runtime compatibility
  with the R2019b target.
- `release-audit.yml` evaluates redistribution and both dry-run packaging gates,
  then builds and verifies a temporary core technical-validation ZIP. The
  builder deletes that ZIP before returning. The workflow never publishes or
  uploads a release package.

The workflows use `actions/checkout@v6` and the maintained
`matlab-actions/*@v3` actions. Optimization Toolbox is required by solve and fit
coverage; Parallel Computing Toolbox is installed for optional parallel work.
A private repository may require a MATLAB batch licensing token stored as the
`MLM_LICENSE_TOKEN` GitHub secret. Public repositories and product licensing
remain subject to MathWorks' current hosted-runner terms.

## Local equivalents

From the repository root, run the MATLAB-free checks with:

```text
python3 tools/ci/static_checks.py --all
git diff --check
```

From MATLAB, run:

```matlab
startup;
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
addpath(fullfile(pwd, 'tools'));
run_public_examples;
isolationResults = runtests(fullfile(pwd, 'tests', 'integration', ...
    'TestStandaloneAllScientificModels.m'));
assert(~any([isolationResults.Failed]));
assert(~any([isolationResults.Incomplete]));
```

For the release audit, add `tools/release` to the MATLAB path, scan the
inventory, invoke both profiles in dry-run mode, and invoke the core profile in
`technical-validation` mode. A blocked authorization gate is an expected
release decision, not a test failure to bypass. A technical-validation package
is temporary and marked `NOT_FOR_REDISTRIBUTION`. No CI job in this repository
creates a GitHub release or publishes a package; the MATLAB workflow's uploaded
JUnit and Cobertura files are test reports, not distribution artifacts.
