# Performance benchmarks

`run_benchmarks` measures the release workflows requested for Round 7: startup
and discovery, scientific data loading/evaluation, animation rendering, a short
solve and continuation, GUI construction, and artifact I/O. Run it from a
fresh MATLAB process after `startup`:

```matlab
addpath(fullfile(pwd, 'benchmarks'));
report = run_benchmarks(struct('Repetitions', 3));
```

The tracked Round 7 measurement is
`baseline_r2025b_macos_arm64.json`. It contains 14 three-repetition records
from MATLAB R2025b on macOS arm64; all medians are below their conservative
budgets. Regenerate it explicitly with:

```matlab
report = run_benchmarks(struct( ...
    'Repetitions', 3, ...
    'OutputPath', fullfile(pwd, 'benchmarks', ...
    'baseline_r2025b_macos_arm64.json')));
```

The reported median and median absolute deviation are warm-process wall-clock
measurements. `MemoryBytes` is only the shallow MATLAB size of each returned
value; it is a portable estimate, not a process-resident-memory measurement.
Each record names its fixture, exact MATLAB release, architecture, and a
deliberately conservative regression budget. The budgets protect against
large regressions, not normal machine-to-machine variation.

For the routine test gate, use `GateOnly=true`. It measures the stable core and
service paths without repeating the full rendering and continuation workload.
The GUI record always constructs the real `uifigure`, all six tab components,
their subscriptions, and the initial refresh before closing the app; the
headless controller-only constructor is not counted as GUI construction:

```matlab
report = run_benchmarks(struct('Repetitions', 1, 'GateOnly', true));
```

Round 7 intentionally adds no evaluation cache. First profile the complete
benchmark on the target workflow. If repeated scientific evaluation dominates,
any future cache must be bounded, version/data-hash keyed, explicitly clearable,
and tested for invalidation and cross-run isolation.

The recorded profile does not justify a cache: scientific evaluations remain
well below one second, the three-point continuation median is about 1.70
seconds, and the real one-time GUI construction median is about 2.83 seconds.
Adding cache invalidation and cross-run state would currently cost more
complexity than it removes.
