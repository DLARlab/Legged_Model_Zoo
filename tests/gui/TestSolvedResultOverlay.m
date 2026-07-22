classdef TestSolvedResultOverlay < matlab.unittest.TestCase
    methods (Test)
        function controllerSolvePublishesSolvedMarker(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            result=app.Controller.solveWorkingSolution(struct());drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyEqual(app.Controller.State.SolvedSolution,result.Solution);
            testCase.verifyTrue(any(strcmp( ...
                layout.OverlayController.layerNames(),'solved_point')));
            clear cleanup
        end
    end
end
