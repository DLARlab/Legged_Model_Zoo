classdef TestNoControlClipping1120x740 < matlab.unittest.TestCase
    methods (Test)
        function enabledControlsStayInsideScrollableContent(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench',[1120 740]);
            app.Figure.Visible='on';drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            ids=Round11GUITestSupport.sidebarIds(layout);
            for index=1:numel(ids)
                layout.SidebarHost.select(ids{index});drawnow;
                offenders=Round11GUITestSupport. ...
                    enabledControlClippingAllTabs( ...
                    layout.SidebarHost.Viewports.(ids{index}));
                testCase.verifyEmpty(offenders,ids{index});
                overlaps=Round11GUITestSupport. ...
                    enabledLabelControlOverlapAllTabs( ...
                    layout.SidebarHost.Viewports.(ids{index}));
                testCase.verifyEmpty(overlaps,ids{index});
            end
            clear cleanup
        end
    end
end
