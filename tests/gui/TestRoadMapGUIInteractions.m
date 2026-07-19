classdef TestRoadMapGUIInteractions < matlab.unittest.TestCase
    methods (Test)
        function workingCopyEditAndDatasetPlotControls(testCase)
            app=lmz.gui.LeggedModelZooApp();cleanup=onCleanup(@()delete(app));drawnow;
            original=app.Controller.State.WorkingSolution.decision('dx');
            row=find(strcmp(app.SolutionTable.Data(:,1),'dx'),1);
            event=struct('Indices',[row 3],'NewData',original+1e-4);
            app.SolutionTable.CellEditCallback(app.SolutionTable,event);
            testCase.verifyEqual(app.Controller.State.WorkingSolution.decision('dx'),original+1e-4,'AbsTol',1e-14);
            testCase.verifyTrue(app.SolutionTable.Data{row,7});
            press(app,'Load all');testCase.verifyEqual(numel(app.Controller.State.Datasets),9);
            press(app,'Plot selected');testCase.verifyEqual(sum(cellfun(@(dataset)dataset.Visible,app.Controller.State.Datasets)),1);
            press(app,'Plot all');testCase.verifyTrue(all(cellfun(@(dataset)dataset.Visible,app.Controller.State.Datasets)));
            press(app,'Clear plot');testCase.verifyFalse(any(cellfun(@(dataset)dataset.Visible,app.Controller.State.Datasets)));
            testCase.verifyNotEmpty(app.NormalizedTimeField);testCase.verifyNotEmpty(app.AnimationFPSSpinner);
            testCase.verifyNotEmpty(app.BranchVisibilityCheckBox);testCase.verifyNotEmpty(app.DiagnosticsTable);
            testCase.verifyNotEmpty(app.ContinuationCheckpointField);clear cleanup
        end

        function controllerInvalidatesDerivedStateAndSupportsManualPair(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');
            solved=controller.solveWorkingSolution(struct());testCase.verifyNotEmpty(solved);
            pair=controller.makeManualSeedPair(267,268,struct());testCase.verifyEqual(pair.Diagnostics.SourceIndices,[267 268]);
            controller.selectByIndex(269);testCase.verifyEmpty(controller.State.SeedPair);testCase.verifyEmpty(controller.State.SolveResult);
            controller.editWorkingValue('dx',controller.State.WorkingSolution.decision('dx')+1e-4);
            testCase.verifyEmpty(fieldnames(controller.State.WorkingSolution.Observables));
            evaluation=controller.evaluateWorkingSolution(false);testCase.verifyNotEmpty(controller.State.WorkingSolution.ResidualBlocks);testCase.verifyEqual(controller.State.WorkingEvaluation.ScaledResidualNorm,evaluation.ScaledResidualNorm);
        end

        function visibleThreeDimensionalHoverDoesNotLock(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');controller.loadAllRoadMapBranches();locked=controller.State.LockedSelection;
            dataset=controller.State.Datasets{4};index=min(20,dataset.Branch.pointCount());coordinates={'dx','dphi','y'};
            target=cellfun(@(name)dataset.Branch.coordinate(name),coordinates,'UniformOutput',false);target=cellfun(@(values)values(index),target);
            [selection,details]=controller.hoverNearestVisiblePoint(coordinates,target);
            testCase.verifyEqual(controller.State.LockedSelection.PointIndex,locked.PointIndex);testCase.verifyEqual(numel(details.Values),3);testCase.verifyNotEmpty(selection.DatasetId);
        end
    end
end

function press(app,label)
buttons=findall(app.Figure,'Type','uibutton');index=find(arrayfun(@(button)strcmp(button.Text,label),buttons),1);
if isempty(index),error('lmz:Test:MissingButton','Missing button %s.',label);end
callback=buttons(index).ButtonPushedFcn;callback(buttons(index),[]);drawnow;
end
