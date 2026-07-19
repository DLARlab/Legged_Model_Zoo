classdef TestBipedGUIWorkflow < matlab.unittest.TestCase
    methods (Test)
        function branchSelectionSimulationAndSolve(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_biped');
            testCase.verifyEqual(controller.State.ModelId,'slip_biped');
            testCase.verifyEqual(controller.State.WorkingSolution.DecisionSchema.count(),12);
            testCase.verifyEqual(controller.State.LockedSelection.PointIndex,30);
            simulation=controller.simulateWorkingSolution();
            testCase.verifySize(simulation.States,[numel(simulation.Time) 8]);
            testCase.verifyEqual(numel(simulation.EventRecords),5);
            result=controller.solveWorkingSolution(struct());
            testCase.verifyLessThan(result.Evaluation.ScaledResidualNorm,1e-10);
            datasets=controller.loadAllGaitMapBranches();testCase.verifyEqual(numel(datasets),6);
        end
        function rendererAndScientificPlotsUsePhysicalOutputs(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_biped');
            simulation=controller.simulateWorkingSolution();
            figureHandle=figure('Visible','off');cleanup=onCleanup(@()close(figureHandle));
            axesHandle=axes(figureHandle);renderer=lmzmodels.slip_biped.BipedRenderer( ...
                axesHandle,simulation);renderer.updateFrame(0.5);
            testCase.verifyGreaterThan(renderer.CurrentIndex,1);
            forceHandles=lmzmodels.slip_biped.BipedPlotProvider.plotGRF(axesHandle,simulation);
            testCase.verifyEqual(numel(forceHandles),6);testCase.verifyTrue(all(isgraphics(forceHandles)));
            footfallHandles=lmzmodels.slip_biped.BipedPlotProvider.plotFootfall(axesHandle,simulation);
            testCase.verifyEqual(numel(footfallHandles),2);testCase.verifyTrue(all(isgraphics(footfallHandles)));
            clear cleanup
        end
    end
end
