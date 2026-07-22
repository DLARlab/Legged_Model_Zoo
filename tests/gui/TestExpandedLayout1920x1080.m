classdef TestExpandedLayout1920x1080 < matlab.unittest.TestCase
    methods (Test)
        function mainPlotExpandsAtLargeSize(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench',[1920 1080]); %#ok<ASGLU>
            testCase.verifyEqual(app.Figure.Position(3:4),[1920 1080]);
            % MATLAB does not resolve hidden-uifigure grid geometry until a
            % render pass.  Exercise the actually displayed workbench.
            app.Figure.Visible='on';drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            originalGrid=layout.MainGrid;
            originalAxes=app.BranchAxes;
            originalOverlayAxes=layout.OverlayController.Axes;
            layout.refreshGeometry();drawnow;
            testCase.verifyTrue(isequal(layout.MainGrid,originalGrid));
            testCase.verifyTrue(isequal(app.BranchAxes,originalAxes));
            testCase.verifyTrue(isequal( ...
                layout.OverlayController.Axes,originalOverlayAxes));
            testCase.verifyEqual(layout.MainGrid.Position(3:4), ...
                layout.Viewport.Content.Root.Position(3:4), ...
                'AbsTol',2);
            testCase.verifyGreaterThan(app.BranchAxes.Position(3),700);
            testCase.verifyGreaterThan( ...
                layout.WorkspaceCanvas.Root.Position(4),350);
            clear cleanup
        end
    end
end
