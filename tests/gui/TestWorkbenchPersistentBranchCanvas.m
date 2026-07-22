classdef TestWorkbenchPersistentBranchCanvas < matlab.unittest.TestCase
    methods (Test)
        function sidebarSwitchPreservesAxesAndLayers(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            axesHandle=app.BranchAxes;
            overlay=layout.OverlayController;
            testCase.verifyEqual(overlay.Axes,axesHandle);
            testCase.verifyTrue(any(strcmp( ...
                overlay.layerNames(),'source_branches')));
            sourceHandle=overlay.layerHandle('source_branches');
            defaultColor=sourceHandle.Color;
            app.PaletteDropDown.Value='high-contrast';
            callback=app.PaletteDropDown.ValueChangedFcn;
            callback(app.PaletteDropDown,[]);drawnow;
            testCase.verifyEqual(overlay.PaletteName,'high-contrast');
            sourceHandle=overlay.layerHandle('source_branches');
            testCase.verifyNotEqual(sourceHandle.Color,defaultColor);
            ids=Round11GUITestSupport.sidebarIds(layout);
            for index=1:numel(ids)
                layout.SidebarHost.select(ids{index});drawnow;
                testCase.verifyTrue(isgraphics(axesHandle));
                testCase.verifyEqual(overlay.Axes,axesHandle);
            end
            clear cleanup
        end
    end
end
