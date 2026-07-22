classdef TestEditedCandidateOverlay < matlab.unittest.TestCase
    methods (Test)
        function editPreservesLockedSourceAndAddsLayer(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            locked=app.Controller.State.LockedSelection;
            source=app.Controller.State.WorkingSolution;
            name=source.DecisionSchema.names();name=name{1};
            app.Controller.editWorkingValue(name,source.decision(name)+1e-5);
            drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyEqual(app.Controller.State.LockedSelection,locked);
            testCase.verifyTrue(any(strcmp( ...
                layout.OverlayController.layerNames(),'edited_candidate')));
            clear cleanup
        end
    end
end
