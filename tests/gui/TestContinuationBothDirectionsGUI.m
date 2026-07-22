classdef TestContinuationBothDirectionsGUI < matlab.unittest.TestCase
    methods (Test)
        function registeredWorkbenchDefaultsToBoth(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            control=app.tab('continuation').DirectionModeDropDown;
            testCase.verifyEqual(control.ItemsData, ...
                {'forward','backward','both'});
            testCase.verifyEqual(control.Value,'both');
            testCase.verifySubstring(lower(control.Items{1}),'increasing');
            testCase.verifySubstring(lower(control.Items{2}),'decreasing');
            clear cleanup
        end
    end
end
