function results = run_tests
%RUN_TESTS Execute the complete MATLAB test suite and print a summary.
startup;
root = lmz.util.ProjectPaths.root();
toolsPath = fullfile(root, 'tools');
fixturesPath = fullfile(lmz.util.ProjectPaths.tests(), 'fixtures');
addpath(toolsPath);
addpath(fixturesPath);
cleanup = onCleanup(@() removeTestPaths(toolsPath, fixturesPath));

results = runtests(lmz.util.ProjectPaths.tests(), ...
    'IncludeSubfolders', true);
failed = sum([results.Failed]);
incomplete = sum([results.Incomplete]);
fprintf('Legged Model Zoo: %d run, %d failed, %d incomplete.\n', ...
    numel(results), failed, incomplete);
if failed > 0
    error('lmz:Tests:Failed', '%d MATLAB tests failed.', failed);
end
clear cleanup
end

function removeTestPaths(toolsPath, fixturesPath)
rmpath(toolsPath);
rmpath(fixturesPath);
end
