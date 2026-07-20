# Test coverage policy

Run `tools/run_coverage.m` on MATLAB R2023a or newer to collect programmatic
statement coverage for every MATLAB file under `src/+lmz` and
`models/+lmzmodels`. The report contains an overall summary and per-package and
per-file/class results. CI also emits Cobertura XML through the official MATLAB
test action.

No runtime code is omitted from collection. The source-preserved files beneath
`+legacy` stay visible in coverage; their strongest evidence remains the
separate source-equivalence and numerical-regression suite because style-driven
coverage alone cannot validate a scientific oracle.

The policy file at `coverage/baseline_policy.json` is created only from a
successful measured run. Stable `lmz.api`, `lmz.data`, `lmz.io`, `lmz.registry`,
and `lmz.services` package floors are set five percentage points below the
measured package rates (never below zero). This catches material regressions
without inventing a high target or encouraging meaningless tests. New code is
expected to add relevant tests; maintainers should deliberately remeasure and
explain any baseline change.

## Round 7 measured baseline

The baseline was measured on 2026-07-19 with MATLAB R2025b Update 5. The run
executed 194 tests: the complete then-current suite except the single policy
test that requires the measurement being produced. No runtime file was
excluded. It covered 7,401 of 9,792 statements across 174 files, for an overall
line rate of 75.5821%.

| Stable package | Covered / total statements | Measured rate | Regression floor |
|---|---:|---:|---:|
| `lmz.api` | 110 / 140 | 78.5714% | 73.5714% |
| `lmz.data` | 416 / 504 | 82.5397% | 77.5397% |
| `lmz.io` | 312 / 363 | 85.9504% | 80.9504% |
| `lmz.registry` | 272 / 326 | 83.4356% | 78.4356% |
| `lmz.services` | 441 / 592 | 74.4932% | 69.4932% |

The other 19 discovered packages and every per-class/file result remain in the
measured report used to derive the policy. They are reported for visibility,
but only the stable core/service packages above are release-regression gates.

Example:

```matlab
startup;
addpath(fullfile(pwd, 'tools'));
[report, results] = run_coverage(struct( ...
    'OutputPath', fullfile(pwd, 'coverage', 'latest.json'), ...
    'CoberturaPath', fullfile(pwd, 'coverage', 'coverage.xml'), ...
    'EnforceBaseline', true));
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Generated HTML/XML/latest reports are build evidence and are not committed.
The small baseline policy is tracked because it defines the regression gate.
