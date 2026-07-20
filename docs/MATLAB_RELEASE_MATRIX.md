# MATLAB release matrix

The compatibility target and the runtime evidence are deliberately separate.

| Release | Evidence | Status |
|---|---|---|
| R2025b Update 5 (`25.2.0.3177638`) | Local macOS arm64 execution, including the untouched 117-test Round 6 baseline | Runtime verified; final Round 7 total is recorded in `RELEASE_CANDIDATE_STATUS.md` |
| R2021a | Configured as the oldest GitHub-hosted release accepted by the current official Setup MATLAB action | Not executed locally; remote CI not yet run |
| R2019b | Static syntax/API scan plus preferred/forced-fallback tests on R2025b | Designed for compatibility; runtime not verified |

On 2026-07-19, standard local installation roots were searched for R2019b,
R2020b, R2021a, and other MATLAB releases. Only
`/Applications/MATLAB_R2025b.app` was found. No installer was downloaded and no
license mechanism was bypassed.

Run the repeatable standard-root scan from MATLAB with:

```matlab
startup;
addpath(fullfile(pwd, 'tools'));
find_matlab_installations
```

User-facing requirements must therefore say: “Designed for MATLAB R2019b compatibility;
runtime-verified on R2025b.” A claim of R2019b runtime support
remains blocked until the same validation matrix executes on an actual R2019b
installation.
