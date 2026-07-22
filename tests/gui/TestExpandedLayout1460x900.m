classdef TestExpandedLayout1460x900 < matlab.unittest.TestCase
    methods (Test)
        function mainPlotReceivesExpandedSpace(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench',[1460 900]);
            testCase.verifyEqual(app.Figure.Position(3:4),[1460 900]);
            app.Figure.Visible='on';drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            layout.refreshGeometry();drawnow;
            testCase.verifyGreaterThan(app.BranchAxes.Position(3),500);
            testCase.verifyGreaterThan(layout.WorkspaceCanvas.Root.Position(4),250);
            clear cleanup
        end
    end
end
