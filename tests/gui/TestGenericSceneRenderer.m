classdef TestGenericSceneRenderer < matlab.unittest.TestCase
    methods (Test)
        function externalPluginUpdatesWithoutHandleLeaks(testCase)
            pluginRoot = fullfile(lmz.util.ProjectPaths.tests(), 'fixtures', ...
                'external_plugins', 'analytic_hopper');
            registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot, 'IncludeBuiltIns', false);
            registryCleanup = onCleanup(@() delete(registry));
            model = registry.createModel('analytic_hopper');
            problem = model.createProblem('periodic_hop', struct());
            evaluation = problem.evaluate(problem.getDecisionSchema().defaults(), ...
                problem.getParameterSchema().defaults(), ...
                lmz.api.RunContext.synchronous(0), true);
            figureHandle = figure('Visible', 'off');
            figureCleanup = onCleanup(@() delete(figureHandle));
            axesHandle = axes('Parent', figureHandle);
            renderer = model.getVisualizationPlugin().createRenderer( ...
                axesHandle, evaluation.Simulation);
            count = numel(findall(axesHandle));
            indices = round(linspace(1, numel(evaluation.Simulation.Time), 100));
            for index = indices
                renderer.updateFrame(index);
            end
            testCase.verifyEqual(numel(findall(axesHandle)), count);
            testCase.verifyEqual(renderer.CurrentIndex, indices(end));
            delete(renderer);
            testCase.verifyEmpty(findall(axesHandle, 'Type', 'line'));
            clear figureCleanup registryCleanup
        end

        function quadrupedTutorialUsesGenericSceneWithoutReplacingOracle(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            registryCleanup = onCleanup(@() delete(registry));
            model = registry.createModel('slip_quadruped');
            problem = model.createProblem('demo_stride', struct());
            simulation = lmz.services.SimulationService().simulate( ...
                problem, struct(), struct(), lmz.api.RunContext.synchronous(0));
            figureHandle = figure('Visible', 'off');
            figureCleanup = onCleanup(@() delete(figureHandle));
            renderer = model.getVisualizationPlugin().createRenderer( ...
                axes('Parent', figureHandle), simulation);
            renderer.updateFrame(50);
            testCase.verifyGreaterThan(numel(renderer.Handles), 5);
            testCase.verifyClass( ...
                lmzmodels.slip_quadruped.QuadrupedRenderer(), ...
                'lmzmodels.slip_quadruped.QuadrupedRenderer');
            delete(renderer);
            clear figureCleanup registryCleanup
        end
    end
end
