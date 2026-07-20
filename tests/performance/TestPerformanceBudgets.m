classdef TestPerformanceBudgets < matlab.unittest.TestCase
    methods (Test)
        function stableGateStaysWithinConservativeBudgets(testCase)
            root = lmz.util.ProjectPaths.root();
            benchmarkPath = fullfile(root, 'benchmarks');
            addpath(root);
            addpath(benchmarkPath);
            cleanup = onCleanup(@() removePaths(root, benchmarkPath));
            outputPath = lmz.compat.Files.temporary(tempdir, '.json');
            outputCleanup = onCleanup(@() deleteIfPresent(outputPath));
            report = run_benchmarks(struct('Repetitions', 1, ...
                'GateOnly', true, 'OutputPath', outputPath));
            testCase.verifyEqual(exist(outputPath, 'file'), 2, ...
                'The requested benchmark report was not retained.');
            persisted = lmz.compat.Json.read(outputPath);
            testCase.verifyTrue(persisted.gateOnly);
            testCase.verifyEqual(numel(persisted.records), ...
                numel(report.records));
            for index = 1:numel(report.records)
                record = report.records(index);
                testCase.verifyLessThanOrEqual(record.MedianSeconds, ...
                    record.BudgetSeconds, sprintf( ...
                    '%s exceeded its conservative %.1f second budget.', ...
                    record.Name, record.BudgetSeconds));
            end
            clear outputCleanup
            clear cleanup
        end
    end
end

function deleteIfPresent(path)
if exist(path, 'file') == 2
    delete(path);
end
end

function removePaths(root, benchmarkPath)
if contains(path, benchmarkPath)
    rmpath(benchmarkPath);
end
if contains(path, root)
    rmpath(root);
end
end
