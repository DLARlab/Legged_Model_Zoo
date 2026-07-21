# Legacy data contracts

## SLIP quadruped roadmap

The public legacy branch variable `results` is a 29-by-N matrix. Rows 1–13 are initial state/decision values, rows 14–22 are nine event times, and rows 23–29 are seven parameters. Raw indexing is confined to `lmzmodels.slip_quadruped.Results29Adapter`.

## Jerboa branch

The importer contract is 14-by-N: twelve decision entries followed by left and
right swing offsets. `lmzmodels.slip_biped.Results14Adapter` preserves that
layout across the six captured branches (2,967 points) with exact round-trip
and per-point metadata checks.

## Load-pulling branch

The source uses `X_accum` plus experimental, weight, and sensitivity fields.
The first stride occupies 44 entries and each later stride adds 13, giving the
exact `44 + 13*(N-1)` contract. The legacy adapters and native
`XAccumPlanAdapter` round-trip one-, two-, and requested-N layouts; extensions
beyond the two measured strides retain explicit synthetic/source-equivalence
qualifications.
