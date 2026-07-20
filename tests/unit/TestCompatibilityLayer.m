classdef TestCompatibilityLayer < matlab.unittest.TestCase
    methods (Test)
        function timestampPreferredAndFallback(testCase)
            preferred = lmz.compat.Timestamp.current(false);
            fallback = lmz.compat.Timestamp.current(true);
            testCase.verifyNotEmpty(preferred);
            testCase.verifyNotEmpty(fallback);
            testCase.verifyNotEmpty(regexp(fallback, '^\d{8}T\d{6}$', 'once'));
        end

        function recursiveDiscoveryPreferredAndFallbackAgree(testCase)
            root = lmz.util.ProjectPaths.root();
            preferred = lmz.compat.Files.recursive( ...
                fullfile(root, 'src'), '*.m', false);
            fallback = lmz.compat.Files.recursive( ...
                fullfile(root, 'src'), '*.m', true);
            preferredNames = sort(arrayfun(@(item) fullfile( ...
                item.folder, item.name), preferred, 'UniformOutput', false));
            fallbackNames = sort(arrayfun(@(item) fullfile( ...
                item.folder, item.name), fallback, 'UniformOutput', false));
            testCase.verifyEqual(preferredNames, fallbackNames);
        end

        function atomicMovePreferredAndFallback(testCase)
            folder = tempname;
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's'));
            for forced = [false true]
                source = fullfile(folder, sprintf('source%d.txt', forced));
                target = fullfile(folder, sprintf('target%d.txt', forced));
                writeText(source, 'new');
                writeText(target, 'old');
                lmz.compat.Files.atomicMove(source, target, forced);
                testCase.verifyEqual(fileread(target), 'new');
                testCase.verifyEqual(exist(source, 'file'), 0);
            end
            clear cleanup
        end

        function jsonRoundTrip(testCase)
            expected = struct('name', 'compatibility', 'count', 2);
            actual = lmz.compat.Json.decode(lmz.compat.Json.encode(expected));
            testCase.verifyEqual(actual, expected);
        end

        function optimizationFallback(testCase)
            values = struct('Display', 'off', 'MaxIterations', 12, ...
                'FunctionTolerance', 1e-7, 'StepTolerance', 1e-8);
            options = lmz.compat.Optimization.fsolve(values, true);
            testCase.verifyEqual(options.MaxIter, 12);
            testCase.verifyEqual(options.TolFun, 1e-7);
            testCase.verifyEqual(options.TolX, 1e-8);
        end

        function graphicsStrategyCanBeForced(testCase)
            testCase.verifyFalse( ...
                lmz.compat.Graphics.preferredExporterAvailable(true));
            expected = exist('exportgraphics', 'file') == 2;
            testCase.verifyEqual( ...
                lmz.compat.Graphics.preferredExporterAvailable(false), expected);
        end
    end
end

function writeText(path, value)
file = fopen(path, 'w');
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', value);
clear cleanup
end
