# Regression fixture inputs

Run `startup; addpath(fullfile(lmz.util.ProjectPaths.root(),'tools')); regenerate_regression_inputs` in MATLAB to extract the small input fixtures from the immutable sibling repositories. The script records source paths, SHA-256 values, commits, and selected column numbers.

The generated MAT files are inputs, not numerical baselines. Baseline residuals, trajectories, events, forces, classifications, and tolerances remain blocked until MATLAB and the isolated legacy capture scripts are available.
