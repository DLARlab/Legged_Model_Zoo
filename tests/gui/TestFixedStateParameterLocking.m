classdef TestFixedStateParameterLocking < matlab.unittest.TestCase
    methods (Test)
        function timingModeRendersFixedStateAndPhysicsAsLocked(testCase)
            [app,~,cleanup]=Round9GUITestSupport.makeApp( ...
                'tutorial_hopper','section_return_timing'); %#ok<ASGLU>
            controller=app.Controller;solutionTab=app.tab('solution');
            timing=controller.timingEditorData();
            testCase.verifyTrue(timing.Available);
            testCase.verifyFalse(any(solutionTab.SolutionTable.ColumnEditable));
            testCase.verifyFalse(any(solutionTab.ParameterTable.ColumnEditable));
            testCase.verifyEqual(size(solutionTab.SolutionTable.Data,1), ...
                numel(timing.FixedInitialState));
            testCase.verifyEqual(size(solutionTab.ParameterTable.Data,1), ...
                numel(timing.FixedPhysicalParameters));
            testCase.verifyEqual(cell2mat( ...
                solutionTab.SolutionTable.Data(:,3)), ...
                timing.FixedInitialState);
            testCase.verifyEqual(cell2mat( ...
                solutionTab.ParameterTable.Data(:,3)), ...
                timing.FixedPhysicalParameters);
            testCase.verifyTrue(all(contains( ...
                solutionTab.SolutionTable.Data(:,5),'fixed / locked')));
            testCase.verifyTrue(solutionTab.EventTable.ColumnEditable(3));
            clear cleanup
        end
    end
end
