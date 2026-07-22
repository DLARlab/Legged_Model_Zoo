classdef TestNoControlClipping900x650 < matlab.unittest.TestCase
    methods (Test)
        function enabledControlsStayInsideScrollableContent(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench',[900 650]);
            app.Figure.Visible='on';drawnow;
            verifyNoSidebarClipping(testCase,app);
            clear cleanup
        end
    end
end

function verifyNoSidebarClipping(testCase,app)
layout=Round11GUITestSupport.scientificLayout(app);
ids=Round11GUITestSupport.sidebarIds(layout);
for index=1:numel(ids)
    layout.SidebarHost.select(ids{index});drawnow;
    offenders=Round11GUITestSupport.enabledControlClippingAllTabs( ...
        layout.SidebarHost.Viewports.(ids{index}));
    testCase.verifyEmpty(offenders,ids{index});
    overlaps=Round11GUITestSupport.enabledLabelControlOverlapAllTabs( ...
        layout.SidebarHost.Viewports.(ids{index}));
    testCase.verifyEmpty(overlaps,ids{index});
end
end
