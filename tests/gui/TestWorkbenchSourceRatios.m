classdef TestWorkbenchSourceRatios < matlab.unittest.TestCase
    methods (Test)
        function mainGridMatchesSourceHierarchy(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyEqual(layout.MainGrid.RowHeight,{'fit','1x',93});
            testCase.verifyEqual(layout.ColumnRatio,[3.35 1.85], ...
                'AbsTol',1e-12);
            testCase.verifyEqual(layout.MainGrid.Padding,[12 12 12 12]);
            testCase.verifyEqual(layout.MainGrid.RowSpacing,10);
            testCase.verifyEqual(layout.MainGrid.ColumnSpacing,12);
            clear cleanup
        end
    end
end
