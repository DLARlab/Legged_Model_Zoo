# Legacy data contracts

## SLIP quadruped roadmap

The public legacy branch variable `results` is a 29-by-N matrix. Rows 1–13 are initial state/decision values, rows 14–22 are nine event times, and rows 23–29 are seven parameters. Raw indexing is confined to `lmzmodels.slipquadruped.Results29Adapter`.

## Jerboa branch

The required importer contract is 14-by-N: twelve decision entries followed by left and right swing offsets. Fixture interpretation still requires execution and field inspection.

## Load-pulling branch

The source uses `X_accum` plus experimental, weight and sensitivity fields. Packing varies between first and later strides and remains unresolved pending fixture-led adapter tests.
