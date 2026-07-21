classdef TestStrideCountControls < matlab.unittest.TestCase
    methods (Test)
        function simulationAndOptimizationShareRequestedStrideCount(testCase)
            [app,~,cleanup]=Round9GUITestSupport.makeApp( ...
                'tutorial_hopper','n_stride_simulation'); %#ok<ASGLU>
            simulation=app.tab('simulation');
            optimization=app.tab('optimization');
            Round9GUITestSupport.change(simulation.StrideCountSpinner,5);
            testCase.verifyEqual(app.Controller.State.RequestedStrideCount,5);
            testCase.verifyEqual(optimization.StrideCountSpinner.Value,5);

            Round9GUITestSupport.change(optimization.StrideCountSpinner,3);
            testCase.verifyEqual(app.Controller.State.RequestedStrideCount,3);
            testCase.verifyEqual(simulation.StrideCountSpinner.Value,3);
            testCase.verifyEqual(optimization.StrideCountSpinner.Value,3);
            testCase.verifyEqual(app.Controller.Events.LastDispatchErrors,{});
            clear cleanup
        end
    end
end
