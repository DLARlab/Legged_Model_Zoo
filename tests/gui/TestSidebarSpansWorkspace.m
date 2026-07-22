classdef TestSidebarSpansWorkspace < matlab.unittest.TestCase
    methods (Test)
        function sidebarOccupiesAllThreeRows(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyEqual(layout.SidebarHost.Root.Layout.Row,[1 3]);
            testCase.verifyEqual(layout.SidebarHost.Root.Layout.Column,2);
            testCase.verifyEqual(layout.StatusDock.Root.Layout.Row,3);
            testCase.verifyEqual(layout.StatusDock.Root.Layout.Column,1);
            clear cleanup
        end
    end
end
