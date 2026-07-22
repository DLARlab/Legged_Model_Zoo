classdef TestScrollPositionPreserved < matlab.unittest.TestCase
    methods (Test)
        function ordinaryRefreshDoesNotResetViewport(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench',[900 650]); %#ok<ASGLU>
            layout=Round11GUITestSupport.scientificLayout(app);
            mainViewport=layout.Viewport;
            mainViewport.setScrollPosition([25 30]);drawnow;
            mainBefore=mainViewport.scrollPosition();
            testCase.verifyEqual(mainBefore,[25 30]);
            layout.refreshGeometry();drawnow;
            testCase.verifyEqual(mainViewport.scrollPosition(),mainBefore, ...
                'AbsTol',1);
            viewport=layout.SidebarHost.Viewports.continuation;
            viewport.setScrollPosition([25 70]);drawnow;
            before=viewport.scrollPosition();
            testCase.verifyEqual(before,[25 70]);
            app.tab('continuation').refresh();drawnow;
            testCase.verifyEqual(viewport.scrollPosition(),before, ...
                'AbsTol',1);
            viewport.resetScroll();
            testCase.verifyEqual(viewport.scrollPosition(),[0 0]);
            clear cleanup
        end


        function documentedScrollApiMovesAndSurvivesRefresh(testCase)
            % isInScrollView was introduced after the R2019b compatibility
            % floor.  Use it when available to verify actual rendered state;
            % older releases retain the API/state contract checks above.
            figureHandle=uifigure('Visible','on', ...
                'Position',[40 40 400 300]);
            cleanup=onCleanup(@()delete(figureHandle));
            if ~ismethod(figureHandle,'isInScrollView')
                testCase.verifyTrue(true, ...
                    'Rendered scroll-view inspection requires R2022a.');
                clear cleanup
                return
            end
            viewport=lmz.gui.layout.ScrollableViewport(figureHandle, ...
                'MinimumSize',[900 800]);
            viewport.Root.Position=[10 10 300 220];viewport.refresh();
            target=uibutton(viewport.Content.Root,'Text','Far target', ...
                'Position',[760 700 100 30]);
            drawnow;
            testCase.verifyFalse(isInScrollView(viewport.Root,target));
            viewport.setScrollPosition([650 550]);
            settleScroll();
            viewport.setScrollPosition([650 550]);
            settleScroll();
            testCase.verifyTrue(isInScrollView(viewport.Root,target));
            viewport.refresh();settleScroll();
            testCase.verifyTrue(isInScrollView(viewport.Root,target));
            viewport.resetScroll();settleScroll();
            viewport.resetScroll();settleScroll();
            testCase.verifyFalse(isInScrollView(viewport.Root,target));
            clear target cleanup
        end
    end
end

function settleScroll()
% The UIFigure web client applies scrolling after MATLAB yields the event
% loop; two draws around a short yield make the rendered-state assertion
% deterministic without changing the requested position.
drawnow;pause(0.2);drawnow
end
