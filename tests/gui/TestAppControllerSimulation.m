classdef TestAppControllerSimulation < matlab.unittest.TestCase
    methods (Test)
        function headlessWorkflow(testCase)
            controller = lmz.gui.AppController();
            testCase.verifyEqual(controller.modelIds(), ...
                {'slip_biped','slip_quad_load','slip_quadruped', ...
                'tutorial_hopper'});
            ids = controller.modelIds();
            for index = 1:numel(ids)
                controller.selectModel(ids{index});
                testCase.verifyTrue(controller.canSimulateDemo());
                result = controller.simulate(struct());
                testCase.verifyClass(result, 'lmz.api.SimulationResult');
                testCase.verifyNotEmpty(controller.bodyTrajectoryNames());
            end
        end

        function tutorialHopperUsesDeclaredEmptyExampleOptions(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            testCase.verifyEqual(controller.State.ProblemId,'periodic_hop');
            testCase.verifyEqual(controller.builtInExamples(),{'default_hop'});
            testCase.verifyEqual(controller.State.ExampleId,'default_hop');
            testCase.verifyTrue(controller.canSimulateDemo());

            demo=controller.simulate(struct());
            testCase.verifyClass(demo,'lmz.api.SimulationResult');
            testCase.verifySize(demo.States,[numel(demo.Time) 4]);
            testCase.verifySubstring(controller.State.Status,'demo_hop');

            solution=controller.selectProblem('demo_hop');
            capabilities=controller.capabilities();
            testCase.verifyEqual(solution.ProblemId,'demo_hop');
            testCase.verifyTrue(capabilities.simulate);
            testCase.verifyFalse(capabilities.solve);
            testCase.verifyFalse(capabilities.continue);
            simulation=controller.simulateWorkingSolution();
            testCase.verifyClass(simulation,'lmz.api.SimulationResult');
            testCase.verifySize(simulation.States,[numel(simulation.Time) 4]);
            testCase.verifyEqual(controller.bodyTrajectoryNames(),{'x','y'});
        end

        function externalDemoUsesDefaultsWithoutDataExample(testCase)
            pluginRoot=fullfile(lmz.util.ProjectPaths.tests(),'fixtures', ...
                'external_plugins','analytic_hopper');
            registry=lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot,'IncludeBuiltIns',false);
            cleanup=onCleanup(@()delete(registry));
            controller=lmz.gui.AppController(registry);
            testCase.verifyEqual(controller.State.ModelId,'analytic_hopper');
            testCase.verifyEmpty(controller.builtInExamples());
            testCase.verifyEmpty(controller.State.ExampleId);
            testCase.verifyTrue(controller.canSimulateDemo());

            simulation=controller.simulate(struct());
            testCase.verifyClass(simulation,'lmz.api.SimulationResult');
            testCase.verifySize(simulation.States,[numel(simulation.Time) 4]);
            testCase.verifySubstring(controller.State.Status,'demo_hop');
            clear cleanup
        end

        function dataBackedScientificDemoRetainsExampleOptions(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quadruped');
            simulation=controller.simulate(struct());
            x=simulation.state('x');
            testCase.verifyEqual(simulation.Time(end),0.7,'AbsTol',1e-12);
            testCase.verifyEqual(x(end),1.3*0.7,'AbsTol',1e-12);

            simulation=controller.simulate( ...
                struct('speed',2,'stride_period',0.4));
            x=simulation.state('x');
            testCase.verifyEqual(simulation.Time(end),0.4,'AbsTol',1e-12);
            testCase.verifyEqual(x(end),0.8,'AbsTol',1e-12);
        end
    end
end
