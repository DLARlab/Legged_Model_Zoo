function regenerate_regression_inputs
%REGENERATE_REGRESSION_INPUTS Extract minimal inputs from immutable sources.
% This script reads MAT data only. It does not add legacy code to the path.
projectRoot = lmz.util.ProjectPaths.root();
workspaceRoot = fileparts(projectRoot);
fixtureRoot = fullfile(lmz.util.ProjectPaths.tests(), 'fixtures');

extractQuadruped(workspaceRoot, fixtureRoot);
extractJerboa(workspaceRoot, fixtureRoot);
extractQuadLoad(workspaceRoot, fixtureRoot);
fprintf('Regression inputs written under %s.\n', fixtureRoot);
end

function extractQuadruped(workspaceRoot, fixtureRoot)
sourcePath = fullfile(workspaceRoot, 'SLIP_Model_Zoo', 'SLIP_Quadruped', ...
    'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
    '1_Roadmap', 'PK_20_2.mat');
loaded = load(sourcePath, 'results');
assert(size(loaded.results, 1) == 29, ...
    'lmz:Fixtures:QuadrupedLayout', 'Expected a 29-row results matrix.');
fixture = struct();
fixture.schemaVersion = '1.0.0';
fixture.modelId = 'slip.quadruped.planar.v2';
fixture.sourcePath = sourcePath;
fixture.sourceSHA256 = ...
    '45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401';
fixture.sourceCommitSHA = ...
    '2c106101383ecee1b2a9d695efe09fbd72d5718a';
fixture.sourceColumns = [1, 2, round(size(loaded.results, 2) / 2)];
fixture.results = loaded.results(:, fixture.sourceColumns);
save(fullfile(fixtureRoot, 'slip_quadruped_inputs.mat'), 'fixture');
end

function extractJerboa(workspaceRoot, fixtureRoot)
sourcePath = fullfile(workspaceRoot, ...
    '2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
    'Section2_solution_examples', 'W1.mat');
loaded = load(sourcePath, 'results');
assert(size(loaded.results, 1) == 14, ...
    'lmz:Fixtures:JerboaLayout', 'Expected a 14-row results matrix.');
fixture = struct();
fixture.schemaVersion = '1.0.0';
fixture.modelId = 'jerboa.biped.offset';
fixture.sourcePath = sourcePath;
fixture.sourceSHA256 = ...
    '52a6243833851ab9e498b0eb60e5489ab78747a3f9ff05c9be02d5c66e61d6dc';
fixture.sourceCommitSHA = ...
    '4595146c5881a5313bc8fe92de85099193ef9be9';
fixture.sourceColumns = [1, 2, round(size(loaded.results, 2) / 2)];
fixture.results = loaded.results(:, fixture.sourceColumns);
save(fullfile(fixtureRoot, 'jerboa_biped_inputs.mat'), 'fixture');
end

function extractQuadLoad(workspaceRoot, fixtureRoot)
sourcePath = fullfile(workspaceRoot, ...
    '2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights', ...
    'Section2_Single_Stride_Replication', 'P3_Individual_1_TR.mat');
loaded = load(sourcePath, 'X_accum', 'gait_data', 'gait_type', ...
    'term_weights');
assert(size(loaded.X_accum, 1) == 44, ...
    'lmz:Fixtures:QuadLoadLayout', 'Expected a 44-row X_accum vector.');
fixture = struct();
fixture.schemaVersion = '1.0.0';
fixture.modelId = 'slip.quadruped.load';
fixture.sourcePath = sourcePath;
fixture.sourceSHA256 = ...
    '56736cc33ab31a0ab40b3de6783b625a07ebd54f1ae6a561b47aea5e04cd6abe';
fixture.sourceCommitSHA = ...
    '19f3133073c988cc0c3424a647b4adbb60a90b99';
fixture.X_accum = loaded.X_accum;
fixture.gait_data = loaded.gait_data;
fixture.gait_type = loaded.gait_type;
fixture.term_weights = loaded.term_weights;
save(fullfile(fixtureRoot, 'quadruped_load_inputs.mat'), 'fixture');
end
