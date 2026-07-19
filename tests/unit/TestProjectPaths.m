classdef TestProjectPaths < matlab.unittest.TestCase
    methods (Test)
        function pathsExist(testCase)
            testCase.verifyEqual(exist(lmz.util.ProjectPaths.root(), 'dir'), 7);
            testCase.verifyEqual(exist(lmz.util.ProjectPaths.src(), 'dir'), 7);
            testCase.verifyEqual(exist(lmz.util.ProjectPaths.models(), 'dir'), 7);
            testCase.verifyEqual(exist(lmz.util.ProjectPaths.catalog(), 'dir'), 7);
            testCase.verifyEqual(exist(lmz.util.ProjectPaths.tests(), 'dir'), 7);
            testCase.verifyEqual(exist(lmz.util.ProjectPaths.examples(), 'dir'), 7);
        end

        function registryIndependentOfCurrentDirectory(testCase)
            original = pwd;
            cleanup = onCleanup(@() cd(original));
            cd(tempdir());
            registry = lmz.registry.ModelRegistry.discover();
            testCase.verifyEqual(numel(registry.listModels()), 3);
            clear cleanup
        end
    end
end
