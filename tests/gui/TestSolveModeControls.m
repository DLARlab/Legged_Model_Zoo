classdef TestSolveModeControls < matlab.unittest.TestCase
    methods (Test)
        function modeSelectorSwitchesConcreteProblemFormulations(testCase)
            [app,~,cleanup]=Round9GUITestSupport.makeApp( ...
                'tutorial_hopper','periodic_orbit'); %#ok<ASGLU>
            solveTab=app.tab('solve');controller=app.Controller;
            expected={'Periodic orbit','Contact timings only', ...
                'N-stride periodic orbit','Timing sequence'};
            testCase.verifyEqual(solveTab.SolveModeDropDown.Items,expected);

            Round9GUITestSupport.change(solveTab.SolveModeDropDown, ...
                'Contact timings only');
            testCase.verifyEqual(controller.State.ProblemId, ...
                'section_return_timing');
            testCase.verifyEqual(controller.State.SolveMode, ...
                'Contact timings only');
            testCase.verifyEqual(solveTab.SolveModeDropDown.Value, ...
                'Contact timings only');
            testCase.verifyEqual(char(solveTab.EventMaskTable.Enable),'on');
            testCase.verifyNotEmpty(solveTab.EventMaskTable.Data);
            testCase.verifySubstring(solveTab.FixedDataLabel.Text, ...
                'Timing-only mode');

            Round9GUITestSupport.change(solveTab.SolveModeDropDown, ...
                'Periodic orbit');
            testCase.verifyEqual(controller.State.ProblemId,'periodic_orbit');
            testCase.verifyEqual(controller.State.SolveMode,'Periodic orbit');
            testCase.verifyEmpty(solveTab.EventMaskTable.Data);
            testCase.verifySubstring(solveTab.FixedDataLabel.Text, ...
                'state and parameters are decision data');
            testCase.verifyEqual(controller.Events.LastDispatchErrors,{});
            clear cleanup
        end
    end
end
