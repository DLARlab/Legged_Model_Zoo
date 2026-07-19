classdef TestQuadrupedVisualization < matlab.unittest.TestCase
    methods (Test)
        function framesTrajectoriesGrfOscillator(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');simulation=controller.simulateWorkingSolution();
            figureHandle=figure('Visible','off');cleanup=onCleanup(@()delete(figureHandle));layout=tiledlayout(figureHandle,2,2);
            animationAxes=nexttile(layout);renderer=lmzmodels.slip_quadruped.QuadrupedRenderer(animationAxes,simulation);renderer.updateFrame(round(numel(simulation.Time)/2));
            lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotTorso(nexttile(layout),simulation);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotGRF(nexttile(layout),simulation);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotOscillator(nexttile(layout),simulation);
            contacts=[simulation.Modes.back_left,simulation.Modes.front_left,simulation.Modes.back_right,simulation.Modes.front_right];testCase.verifyLessThanOrEqual(max(abs(simulation.Kinematics.FootY(contacts))),1e-12);testCase.verifyGreaterThan(numel(findall(figureHandle,'Type','line')),8);clear cleanup
        end
    end
end
