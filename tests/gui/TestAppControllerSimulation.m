classdef TestAppControllerSimulation < matlab.unittest.TestCase
    methods (Test)
        function headlessWorkflow(testCase)
            controller = lmz.gui.AppController();
            testCase.verifyEqual(controller.modelIds(), ...
                {'slip_biped','slip_quad_load','slip_quadruped'});
            ids = controller.modelIds();
            for index = 1:numel(ids)
                controller.selectModel(ids{index});
                result = controller.simulate(struct());
                testCase.verifyClass(result, 'lmz.api.SimulationResult');
                testCase.verifyNotEmpty(controller.bodyTrajectoryNames());
            end
        end
    end
end
