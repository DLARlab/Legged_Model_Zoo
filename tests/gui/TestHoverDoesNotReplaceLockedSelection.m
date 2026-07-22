classdef TestHoverDoesNotReplaceLockedSelection < matlab.unittest.TestCase
    methods (Test)
        function hoverLayerIsIndependent(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            before=app.Controller.State.LockedSelection;
            values=lmz.gui.branch.BranchCoordinateMapper.solutions( ...
                app.Controller.lockedSolution(), ...
                app.Controller.State.AxisVariables);
            layout.OverlayController.setCoordinates('hover_point',values);
            testCase.verifyEqual(app.Controller.State.LockedSelection,before);
            names=layout.OverlayController.layerNames();
            testCase.verifyTrue(all(ismember( ...
                {'hover_point','locked_point'},names)));
            clear cleanup
        end
    end
end
