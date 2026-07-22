classdef TestWorkbenchContributionLayout < matlab.unittest.TestCase
    methods (Test)
        function registeredContributionSelectsViewsPanelsAndLiveHosts(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            contribution=layout.Contribution;
            testCase.verifyEqual(fieldnames(layout.WorkspaceCanvas.Views), ...
                contribution.CentralViews(:));
            expected=unique([contribution.SidebarPanels ...
                contribution.AnalysisPlugins],'stable');
            testCase.verifyEqual(fieldnames(layout.SidebarHost.Tabs), ...
                expected(:));
            testCase.verifyTrue(isfield(layout.SidebarHost.Tabs, ...
                'advanced_shooting_horizon'));
            testCase.verifyFalse(isfield(layout.SidebarHost.Tabs, ...
                'advanced_shooting'));

            layout.SidebarHost.select('oscillator_analysis');drawnow;
            testCase.verifyEqual(parentTabTag(app.tab('simulation').Root), ...
                'lmz-sidebar-oscillator-analysis');
            layout.SidebarHost.select('visualization');drawnow;
            testCase.verifyEqual(parentTabTag(app.tab('simulation').Root), ...
                'lmz-sidebar-visualization');
            layout.SidebarHost.select('advanced_shooting_horizon');drawnow;
            testCase.verifyEqual(parentTabTag(app.tab('solve').Root), ...
                'lmz-sidebar-advanced-shooting-horizon');
            layout.SidebarHost.select('solve_seeds');drawnow;
            testCase.verifyEqual(parentTabTag(app.tab('solve').Root), ...
                'lmz-sidebar-solve-seeds');
            clear cleanup
        end

        function programmaticModelChangeRebuildsRegisteredProfile(testCase)
            namespace=Round11GUITestSupport.namespace();
            preferences=lmz.gui.PreferencesStore('Namespace',namespace);
            preferences.setWindowPosition([40 40 1120 740]);
            app=lmz.gui.LeggedModelZooApp('Preferences',preferences, ...
                'Visible','off');
            cleanup=onCleanup(@()Round11GUITestSupport.clean( ...
                app,preferences));
            drawnow;
            original=app.WorkbenchShell.Layout;
            app.Controller.selectModel('slip_quad_load');drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyFalse(isvalid(original));
            testCase.verifyEqual(layout.Contribution.ModelId, ...
                app.Controller.State.ModelId);
            testCase.verifyTrue(isfield(layout.SidebarHost.Tabs, ...
                'optimization'));
            app.Controller.selectModel('tutorial_hopper');drawnow;
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ClassicTabbedLayout');
            clear cleanup
        end

        function programmaticLayoutChangeRebuildsExistingApp(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            app.LayoutDropDown.Value='classic_tabs';
            invokeValueChanged(app.LayoutDropDown);drawnow;
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ClassicTabbedLayout');
            testCase.verifyEqual(app.Controller.State.LayoutProfileId, ...
                'classic_tabs');
            app.LayoutDropDown.Value='scientific_workbench';
            invokeValueChanged(app.LayoutDropDown);drawnow;
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ScientificWorkbenchLayout');
            testCase.verifyEqual(app.Controller.State.LayoutProfileId, ...
                'scientific_workbench');
            clear cleanup
        end

        function centralAnalysisWorkspaceRendersControllerState(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyClass(layout.AnalysisWorkspace, ...
                'lmz.gui.workspace.CentralAnalysisWorkspace');
            analysisHooks=layout.AnalysisWorkspace.testHooks();
            testCase.verifyEqual(analysisHooks.FootfallAxes, ...
                layout.FootfallAxes);
            testCase.verifyEqual(analysisHooks.RunOverlayAxes, ...
                layout.RunOverlayAxes);
            refreshCount=analysisHooks.RefreshCount;
            layout.refreshAnalysisViews();
            testCase.verifyEqual( ...
                layout.AnalysisWorkspace.testHooks().RefreshCount, ...
                refreshCount+1);
            layout.WorkspaceCanvas.select('hildebrand_footfall');drawnow;
            testCase.verifyNotEmpty(layout.FootfallAxes.Children);
            testCase.verifySubstring(layout.FootfallAxes.Title.String, ...
                'classification');

            progress=lmz.data.SolveProgress();
            decision=app.Controller.State.WorkingSolution.DecisionValues;
            snapshot=lmz.data.SolveIterationSnapshot(struct( ...
                'Stage','iteration','Iteration',1,'FunctionCount',2, ...
                'DecisionValues',decision,'ScaledResidual',1e-4, ...
                'StepNorm',1e-3, ...
                'FirstOrderOptimality',1e-4,'Accepted',true, ...
                'Message','focused view test'));
            progress.record('iteration',snapshot);
            app.Controller.State.SolveProgress=progress;
            layout.WorkspaceCanvas.select('run_overlay');drawnow;
            testCase.verifyNotEmpty(findobj(layout.RunOverlayAxes, ...
                'Type','line'));
            testCase.verifySubstring(layout.RunOverlayAxes.Title.String, ...
                'diagnostics');
            clear cleanup
        end

        function placementLayoutDelegatesScientificRendering(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            layoutText=fileread(fullfile(root,'src','+lmz','+gui', ...
                '+layout','ScientificWorkbenchLayout.m'));
            workspaceText=fileread(fullfile(root,'src','+lmz','+gui', ...
                '+workspace','CentralAnalysisWorkspace.m'));
            forbidden={'Controller.State','activeDataset()', ...
                'renderFootfallAnalysis','renderRunAnalysis','semilogy('};
            for index=1:numel(forbidden)
                testCase.verifyFalse(contains(layoutText,forbidden{index}));
            end
            testCase.verifySubstring(layoutText, ...
                'obj.AnalysisWorkspace.refresh');
            testCase.verifySubstring(workspaceText,'Controller.State');
            testCase.verifySubstring(workspaceText, ...
                'renderFootfallAnalysis');
            testCase.verifySubstring(workspaceText,'renderRunAnalysis');
        end

        function parameterFiltersChangeVisibleBranchData(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            original=app.Controller.activeDataset().Branch;
            firstData=original.toStruct();count=original.pointCount();
            firstData.ParameterValues(1,:)=linspace(10,20,count);
            secondData=firstData;
            secondData.Id=lmz.util.Ids.new('branch');
            secondData.ParameterValues(2,:)=25;
            first=lmz.data.BranchDataset('filter first', ...
                lmz.data.SolutionBranch.fromStruct(firstData));
            second=lmz.data.BranchDataset('filter second', ...
                lmz.data.SolutionBranch.fromStruct(secondData));
            transaction=app.Controller.Events.beginTransaction();
            app.Controller.State.Datasets={first,second};
            app.Controller.State.ActiveDatasetId=first.Id;
            app.Controller.State.LockedSelection=[];
            clear transaction;drawnow;
            branchTab=app.tab('branches');

            branchTab.FixedParameterDropDown.Value='k_swing';
            invokeValueChanged(branchTab.FixedParameterDropDown);drawnow;
            branchTab.FixedValueDropDown.Value='25';
            invokeValueChanged(branchTab.FixedValueDropDown);drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyFalse(any(strcmp( ...
                layout.OverlayController.layerNames(),'source_branches')));

            branchTab.FixedValueDropDown.Value='<all>';
            invokeValueChanged(branchTab.FixedValueDropDown);
            branchTab.VaryingParameterDropDown.Value='k_leg';
            invokeValueChanged(branchTab.VaryingParameterDropDown);
            branchTab.VaryingValueDropDown.Value= ...
                branchTab.VaryingValueDropDown.Items{end};
            invokeValueChanged(branchTab.VaryingValueDropDown);drawnow;
            source=layout.OverlayController.layerHandle('source_branches');
            testCase.verifyNumElements(source.XData,1);
            clear cleanup
        end
    end
end

function invokeValueChanged(control)
callback=control.ValueChangedFcn;callback(control,[]);
end

function value=parentTabTag(control)
value='';current=control;
while ~isempty(current)&&isvalid(current)
    if isa(current,'matlab.ui.container.Tab')
        value=char(current.Tag);return
    end
    if ~isprop(current,'Parent'),return,end
    current=current.Parent;
end
end
