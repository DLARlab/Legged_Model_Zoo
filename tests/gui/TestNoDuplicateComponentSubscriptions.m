classdef TestNoDuplicateComponentSubscriptions < matlab.unittest.TestCase
    methods (Test)
        function eachComponentSubscribesOnceAcrossLayouts(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            testCase.verifyEqual(app.Controller.Events.subscriptionCount(),7);
            values=struct2cell(app.TabComponents);
            testCase.verifyTrue(all(cellfun(@(item) ...
                item.testHooks().SubscriptionCount==1,values)));
            app.LayoutDropDown.Value='classic_tabs';
            callback=app.LayoutDropDown.ValueChangedFcn;
            callback(app.LayoutDropDown,[]);drawnow;
            testCase.verifyEqual(app.Controller.Events.subscriptionCount(),7);
            clear cleanup
        end
    end
end
