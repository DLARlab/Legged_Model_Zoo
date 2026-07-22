classdef TestClassicLayoutFallback < matlab.unittest.TestCase
    methods (Test)
        function retainsStableTopLevelTabs(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp('classic_tabs');
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ClassicTabbedLayout');
            testCase.verifyEqual(app.TabGroup.Tag,'lmz-main-tabs');
            testCase.verifyClass(app.tab('branches'),'lmz.gui.tabs.BranchTab');
            testCase.verifyEqual(app.tab('branches').testHooks().HostMode, ...
                'classic_tabs');
            continuation=app.tab('continuation').testHooks();
            testCase.verifyTrue(isgraphics(continuation.Controls.Axes));
            testCase.verifyEqual(continuation.Controls.Axes.Tag, ...
                'lmz-continuation-axes');
            clear cleanup
        end
    end
end
