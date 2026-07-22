classdef TestLockedSelectionAcrossSidebarTabs < matlab.unittest.TestCase
    methods (Test)
        function selectionAndMarkerPersist(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            app.Controller.selectByIndex(268);drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            ids=Round11GUITestSupport.sidebarIds(layout);
            for index=1:numel(ids)
                layout.SidebarHost.select(ids{index});drawnow;
                testCase.verifyEqual( ...
                    app.Controller.State.LockedSelection.PointIndex,268);
                testCase.verifyTrue(any(strcmp( ...
                    layout.OverlayController.layerNames(),'locked_point')));
            end
            clear cleanup
        end
    end
end
