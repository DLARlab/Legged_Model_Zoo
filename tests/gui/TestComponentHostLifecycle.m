classdef TestComponentHostLifecycle < matlab.unittest.TestCase
    methods (Test)
        function layoutSwitchDisposesOldRoots(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            oldRoots=cellfun(@(item)item.Root, ...
                struct2cell(app.TabComponents),'UniformOutput',false);
            app.LayoutDropDown.Value='classic_tabs';
            callback=app.LayoutDropDown.ValueChangedFcn;
            callback(app.LayoutDropDown,[]);drawnow;
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ClassicTabbedLayout');
            testCase.verifyTrue(all(cellfun(@(item)~isvalid(item),oldRoots)));
            clear cleanup
        end

        function branchPartsOwnControlsAndDisposeWithHost(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            branch=app.TabComponents.branches;
            components={branch.DataToolbar,branch.ParameterFilterPanel, ...
                branch.BranchCanvas,branch.AxisControlPanel, ...
                branch.DatasetPanel,branch.BranchNavigationPanel};
            representatives={branch.CatalogDropDown, ...
                branch.FixedParameterDropDown,branch.Axes, ...
                branch.XDropDown,branch.DatasetList,branch.IndexSpinner};
            roots=cell(1,numel(components));
            for index=1:numel(components)
                component=components{index};hooks=component.testHooks();
                roots{index}=hooks.Root;
                testCase.verifyTrue(hooks.OwnsRoot);
                testCase.verifyTrue(isvalid(hooks.Root));
                testCase.verifyNotEqual(hooks.Root,branch.Root);
                testCase.verifyTrue(rootContains( ...
                    hooks.Root,representatives{index}));
            end
            testCase.verifyEqual( ...
                branch.DataToolbar.Controls.CatalogDropDown, ...
                branch.CatalogDropDown);
            testCase.verifyEqual( ...
                branch.ParameterFilterPanel.Controls.FixedParameter, ...
                branch.FixedParameterDropDown);
            testCase.verifyEqual(branch.BranchCanvas.Controls.Axes, ...
                branch.Axes);
            testCase.verifyEqual(branch.AxisControlPanel.Controls.X, ...
                branch.XDropDown);
            testCase.verifyEqual(branch.DatasetPanel.Controls.List, ...
                branch.DatasetList);
            testCase.verifyEqual( ...
                branch.BranchNavigationPanel.Controls.Index, ...
                branch.IndexSpinner);

            app.LayoutDropDown.Value='classic_tabs';
            callback=app.LayoutDropDown.ValueChangedFcn;
            callback(app.LayoutDropDown,[]);drawnow;
            for index=1:numel(components)
                testCase.verifyFalse(isvalid(components{index}));
                testCase.verifyFalse(isvalid(roots{index}));
            end
            clear cleanup
        end
    end
end

function value=rootContains(root,control)
value=false;current=control;
while ~isempty(current)&&isvalid(current)
    if isequal(current,root),value=true;return,end
    if ~isprop(current,'Parent'),return,end
    current=current.Parent;
end
end
