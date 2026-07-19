# SLIP biped trajectory-fit data

`exp_1802_j30.mat` is the repository-contained observed stride used by the
source optimization example. It contains 101 observation times (`To`), four
footfall times (`footsequence`), an 101-by-8 physical-state observation matrix
(`ob_data`), and the source video identifier. `sim_1802_j30.mat` contains the
published 16-variable fitted seed `X`. `fit_manifest.json` records immutable
source paths, hashes, shapes, and provenance for both files.

Create the fit problem with:

```matlab
registry = lmz.registry.ModelRegistry.discover();
problem = registry.createModel('slip_biped').createProblem('trajectory_fit',struct());
u = problem.sourceSeed();
p = problem.getParameterSchema().defaults();
[objective,terms,diagnostics] = problem.evaluateObjective( ...
    u,p,lmz.api.RunContext.synchronous(0));
```

The six weights are named parameters. The returned terms separately expose
position, height, left/right leg-angle, periodic-residual, and event-timing
contributions. Construct the problem with
`struct('EnforceConstraints',true)` to select the source constrained
alternative; its `nonlinearConstraints` returns the source-scaled 15-entry
physical/periodic residual. No globals or sibling repository paths are used.

SHA-256: `exp_1802_j30.mat`
`4b16bfc041cc386e9768d035716a0dedb1ff38b7fb7efe70fbf749ce3c5596cc`;
`sim_1802_j30.mat`
`303aeca45c7717d5745f1c0e436442d2b083edb9162ecbfc69277b1abfe35e23`.
