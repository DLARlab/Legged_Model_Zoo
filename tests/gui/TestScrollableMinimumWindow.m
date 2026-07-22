classdef TestScrollableMinimumWindow < matlab.unittest.TestCase
    methods (Test)
        function minimumWindowRetainsScrollableWorkspace(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench',[900 650]);
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyEqual(app.Figure.Position(3:4),[900 650]);
            testCase.verifyGreaterThanOrEqual( ...
                layout.Viewport.Content.Root.Position(3:4),[1120 590]);
            clear cleanup
        end
    end
end
