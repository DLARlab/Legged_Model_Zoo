classdef TestSlipQuadLoadVisualization < matlab.unittest.TestCase
    methods (Test)
        function rendererAndAnalysisProviders(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();dataset=catalog.load('individual_1_tr_to_rl');
            simulation=lmzmodels.slip_quad_load.MultiStrideSimulator().run(dataset.XAccum,lmz.api.RunContext.synchronous(94),struct());
            figureHandle=figure('Visible','off');cleanup=onCleanup(@()deleteIfValid(figureHandle));layout=tiledlayout(figureHandle,3,3);
            renderer=lmzmodels.slip_quad_load.QuadLoadRenderer(nexttile(layout),simulation);renderer.updateFrame(.5);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotFootfall(nexttile(layout),simulation,dataset.Experimental.ft_exp);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotBodyAndLegs(nexttile(layout),simulation);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotLoad(nexttile(layout),simulation);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotGRF(nexttile(layout),simulation);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotTugline(nexttile(layout),simulation,dataset.Experimental.loading_force_exp);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotSensitivity(nexttile(layout),dataset.SensitivityStudyData);
            problem=lmzmodels.slip_quad_load.MultiStrideFitProblem(lmzmodels.slip_quad_load.Model(),struct('InitialPerturbation',0));
            [~,~,diagnostics]=problem.evaluateObjective(dataset.XAccum,problem.getParameterSchema().defaults(),lmz.api.RunContext.synchronous(95));
            lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotR2(nexttile(layout),diagnostics.R2);
            testCase.verifyEqual(renderer.CurrentIndex,1+round(.5*(numel(simulation.Time)-1)));
            testCase.verifyTrue(isgraphics(renderer.Handles.Load));testCase.verifyTrue(isgraphics(renderer.Handles.Rope));
        end
    end
end
function deleteIfValid(handle)
if isgraphics(handle),delete(handle);end
end
