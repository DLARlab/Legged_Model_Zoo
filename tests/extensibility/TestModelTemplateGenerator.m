classdef TestModelTemplateGenerator < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGeneratorToPath(testCase)
            toolsRoot = fullfile(lmz.util.ProjectPaths.root(), 'tools');
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(toolsRoot));
        end
    end

    methods (Test)
        function generatesInactiveExecutableExternalProject(testCase)
            outputRoot = tempname; mkdir(outputRoot);
            cleanup = onCleanup(@() removeTree(outputRoot));
            report = new_model('example_hopper', outputRoot);
            testCase.verifyFalse(report.ActivatedProductionCatalog);
            required = { ...
                fullfile('models','+lmzmodels','+example_hopper','Model.m'), ...
                fullfile('catalog','example_hopper','manifest.json'), ...
                fullfile('tests','generated','example_hopper','TestGeneratedModel.m'), ...
                fullfile('examples','demo_example_hopper.m'), 'plugin.json'};
            for index = 1:numel(required)
                testCase.verifyEqual(exist(fullfile(outputRoot, required{index}), 'file'), 2);
            end
            defaultRegistry = lmz.registry.ModelRegistry.discover();
            defaultCleanup = onCleanup(@() delete(defaultRegistry));
            testCase.verifyFalse(any(strcmp(defaultRegistry.listModels(), 'example_hopper')));
            clear defaultCleanup
            registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
                outputRoot, 'IncludeBuiltIns', false);
            registryCleanup = onCleanup(@() delete(registry));
            model = registry.createModel('example_hopper');
            problem = model.createProblem('periodic_orbit', struct());
            result = problem.evaluate(problem.getDecisionSchema().defaults(), ...
                problem.getParameterSchema().defaults(), ...
                lmz.api.RunContext.synchronous(4), true);
            testCase.verifyLessThan(result.ScaledResidualNorm, 1e-12);
            testCase.verifyClass(result.Simulation, 'lmz.api.SimulationResult');
            testCase.verifyError(@() new_model('example_hopper', outputRoot), ...
                'lmz:Template:Collision');
            result = []; problem = []; model = [];
            clear registryCleanup cleanup
        end

        function rejectsUnsafeIdsAndImplicitProductionActivation(testCase)
            outputRoot = tempname; mkdir(outputRoot);
            cleanup = onCleanup(@() removeTree(outputRoot));
            testCase.verifyError(@() new_model('../escape', outputRoot), ...
                'lmz:Template:ModelId');
            testCase.verifyError(@() new_model('slip_biped', outputRoot), ...
                'lmz:Template:ReservedModelId');
            testCase.verifyError(@() new_model('implicit_activation', ...
                lmz.util.ProjectPaths.root()), ...
                'lmz:Template:ProductionActivation');
            clear cleanup
        end
    end
end

function removeTree(value)
if exist(value, 'dir') == 7, rmdir(value, 's'); end
end
