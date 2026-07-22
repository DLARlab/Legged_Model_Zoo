classdef TestGUIComponentLifecycle < matlab.unittest.TestCase
    methods (Test)
        function sixTabsExposeCompleteComponentContract(testCase)
            [app,cleanup]=makeApp();
            ids={'branches','solution','simulation','solve','continuation','optimization'};
            required={'build','refresh','setBusy','setCapabilities','setSelection', ...
                'dispose','delete','testHooks'};
            for index=1:numel(ids)
                component=app.tab(ids{index});
                testCase.verifyTrue(isa(component,'handle'));
                methodsList=methods(component);
                testCase.verifyTrue(all(ismember(required,methodsList)),ids{index});
                hooks=component.testHooks();
                testCase.verifyTrue(isgraphics(hooks.Root));
                testCase.verifyGreaterThan(hooks.SubscriptionCount,0);
            end
            testCase.verifyClass(app.tab('branches'),'lmz.gui.tabs.BranchTab');
            clear cleanup
        end

        function modelChangeRebuildsContributionTabsOnce(testCase)
            [app,cleanup]=makeApp();ids=fieldnames(app.TabComponents);
            previous=cell(size(ids));
            for index=1:numel(ids)
                previous{index}=app.tab(ids{index});
            end
            app.Controller.selectModel('slip_biped');drawnow;
            for index=1:numel(ids)
                oldHooks=previous{index}.testHooks();
                current=app.tab(ids{index});newHooks=current.testHooks();
                testCase.verifyEqual(oldHooks.SubscriptionCount,0, ...
                    [ids{index} ' old subscriptions']);
                testCase.verifyEmpty(oldHooks.Root,[ids{index} ' old root']);
                testCase.verifyFalse(current==previous{index}, ...
                    [ids{index} ' replacement']);
                testCase.verifyEqual(newHooks.RefreshCount,1, ...
                    [ids{index} ' replacement refresh']);
                testCase.verifyTrue(isgraphics(newHooks.Root), ...
                    [ids{index} ' replacement root']);
            end
            testCase.verifyEqual(app.Controller.Events.LastDispatchErrors,{});
            clear cleanup
        end

        function closeDisposesEveryPresentationSubscription(testCase)
            controller=lmz.gui.AppController();preferences=testPreferences();
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            testCase.verifyEqual(controller.Events.subscriptionCount(),7);
            closeCallback=app.Figure.CloseRequestFcn;closeCallback(app.Figure,[]);drawnow;
            testCase.verifyEqual(controller.Events.subscriptionCount(),0);
            testCase.verifyEmpty(app.Figure);delete(app);preferences.reset();
        end

        function inspectorShowsRoleAndEnergyMetadata(testCase)
            [app,cleanup]=makeApp();
            app.Controller.selectModel('tutorial_hopper');drawnow;
            tableHandle=app.tab('solution').ParameterTable;
            testCase.verifyEqual(tableHandle.ColumnName{5}, ...
                'Bounds / activity / role / energy');
            row=find(strcmp(tableHandle.Data(:,1),'gravity'),1);
            testCase.verifyNotEmpty(row);
            testCase.verifySubstring(tableHandle.Data{row,5},'physical');
            testCase.verifySubstring( ...
                tableHandle.Data{row,5},'state_dependent');
            clear cleanup
        end
    end
end

function [app,cleanup]=makeApp()
preferences=testPreferences();app=lmz.gui.LeggedModelZooApp( ...
    'Preferences',preferences,'Visible','off');
cleanup=onCleanup(@()clean(app,preferences));
end
function preferences=testPreferences()
namespace=sprintf('LMZGuiLifecycle%d%d',round(now*1e7),randi(1e6));
preferences=lmz.gui.PreferencesStore('Namespace',namespace);
end
function clean(app,preferences)
if ~isempty(app)&&isvalid(app),delete(app);end
preferences.reset();
end
