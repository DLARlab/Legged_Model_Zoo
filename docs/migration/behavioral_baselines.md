# Behavioral baselines

The quadruped legacy branch format is 29 rows: 13 initial states, 9 event times, and 7 parameters. Touchdown resets append duplicate event-time rows; comparisons must select explicit pre/post sides. The biped decision has 7 initial states and 5 event times; the legacy residual has 15 allocated rows with inactive/default rows, which the new continuation formulation must not treat as active equations. The load transition layout is exactly `44 + 13*(N-1)`; each later stride contributes nine event times and four stride-specific parameters.

Baseline comparison policy: event states at named pre/post samples, fixed physical-time samples within continuous segments, residual blocks, final state, force channels, and gait classification. Adaptive integrator grids are never compared directly. Default tolerance targets are `1e-8` for algebraic test problems, `1e-6` for imported vector round trips, and initially `1e-5` absolute / `1e-4` relative for legacy ODE observables, subject to fixture characterization.

No MATLAB executable was available during this implementation session, so saved `.mat` baselines were inventoried but not executed. No numerical parity result is claimed.
