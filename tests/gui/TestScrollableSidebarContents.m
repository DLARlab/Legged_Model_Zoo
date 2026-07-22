classdef TestScrollableSidebarContents < matlab.unittest.TestCase
    methods (Test)
        function everyDenseTabOwnsStableViewport(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp(); %#ok<ASGLU>
            app.Figure.Visible='on';drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            ids=Round11GUITestSupport.sidebarIds(layout);
            tinyFloor=[120 100];
            sizes=layout.SidebarHost.fitContentsToControls(tinyFloor);
            for index=1:numel(ids)
                layout.SidebarHost.select(ids{index});drawnow;
                viewport=layout.SidebarHost.Viewports.(ids{index});
                computedSize=sizes.(ids{index});
                testCase.verifyEqual(char(viewport.Root.Scrollable),'on');
                testCase.verifyEqual(viewport.Content.MinimumSize, ...
                    computedSize);
                testCase.verifyGreaterThan(computedSize(1), ...
                    tinyFloor(1),[ids{index} ' computed width']);
                testCase.verifyGreaterThan(computedSize(2), ...
                    tinyFloor(2),[ids{index} ' computed height']);
                testCase.verifyGreaterThanOrEqual( ...
                    viewport.Content.Root.Position(3:4), ...
                    viewport.Content.MinimumSize);
                testCase.verifyEmpty(Round11GUITestSupport. ...
                    enabledControlClippingAllTabs(viewport),ids{index});
                testCase.verifyEmpty(Round11GUITestSupport. ...
                    enabledLabelControlOverlapAllTabs(viewport),ids{index});
            end
            continuation=layout.ComponentMap.continuation.NestedTabGroup;
            testCase.verifyGreaterThan(numel(continuation.Children),1);
            clear cleanup
        end


        function directOverflowAndOverlapAreDetected(testCase)
            figureHandle=uifigure('Visible','off', ...
                'Position',[40 40 320 260]);
            viewport=lmz.gui.layout.ScrollableViewport(figureHandle, ...
                'MinimumSize',[200 180]);
            viewport.Root.Position=[10 10 160 140];viewport.refresh();
            cleanup=onCleanup(@()delete(figureHandle));
            uilabel(viewport.Content.Root,'Text','Outside', ...
                'Position',[205 30 70 22]);
            uibutton(viewport.Content.Root,'Text','Control', ...
                'Tag','lmz-test-direct-overflow', ...
                'Position',[220 30 80 22]);drawnow;
            gridPanel=uipanel(viewport.Content.Root,'BorderType','none', ...
                'Position',[150 80 40 40]);
            fixedGrid=uigridlayout(gridPanel,[1 1]);
            fixedGrid.RowHeight={40};fixedGrid.ColumnWidth={40};
            fixedGrid.Padding=[0 0 0 0];
            holder=uipanel(fixedGrid,'BorderType','none');
            uibutton(holder,'Text','Grid overflow', ...
                'Tag','lmz-test-grid-descendant-overflow', ...
                'Position',[20 5 90 22]);drawnow;
            clipping=Round11GUITestSupport.enabledControlClipping(viewport);
            overlaps=Round11GUITestSupport.enabledLabelControlOverlap(viewport);
            testCase.verifyTrue(any(strcmp( ...
                clipping,'lmz-test-direct-overflow')));
            testCase.verifyTrue(any(strcmp( ...
                clipping,'lmz-test-grid-descendant-overflow')));
            testCase.verifyTrue(any(contains(overlaps,'Outside')));
            clear cleanup
        end
    end
end
