projectRoot=fileparts(fileparts(mfilename('fullpath')));run(fullfile(projectRoot,'startup.m'));
cleanup=onCleanup(@()close('all'));
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
singleDataset=catalog.load('individual_1_tr_single');
transitionDataset=catalog.load('individual_1_tr_to_rl');
model=lmzmodels.slip_quad_load.Model();
singleProblem=model.createProblem('single_stride',struct('DatasetPath',singleDataset.Path));
singleSimulation=singleProblem.simulateDecision(singleDataset.XAccum,lmz.api.RunContext.synchronous(71));
fitProblem=model.createProblem('multi_stride_fit',struct('DatasetPath',transitionDataset.Path,'InitialPerturbation',0));
[initialObjective,initialTerms,initialDiagnostics]=fitProblem.evaluateObjective( ...
    transitionDataset.XAccum,fitProblem.getParameterSchema().defaults(),lmz.api.RunContext.synchronous(72));
transitionSimulation=fitProblem.simulateDecision(transitionDataset.XAccum,lmz.api.RunContext.synchronous(73));
figures.Animation=figure('Name','Load-pulling quadruped');
renderer=lmzmodels.slip_quad_load.QuadLoadRenderer(axes(figures.Animation),transitionSimulation);renderer.updateFrame(.5);
figures.Analysis=figure('Name','Load-pulling analysis');layout=tiledlayout(figures.Analysis,2,2);
lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotFootfall(nexttile(layout),transitionSimulation,transitionDataset.Experimental.ft_exp);
lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotTugline(nexttile(layout),transitionSimulation,transitionDataset.Experimental.loading_force_exp);
lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotLoad(nexttile(layout),transitionSimulation);
lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotR2(nexttile(layout),initialDiagnostics.R2);
fprintf('SLIP_QUAD_LOAD_SCIENTIFIC_OK single=%d multi=%d objective=%.12g terms=[%.6g %.6g %.6g]\n', ...
    singleSimulation.Observables.stride_count,transitionSimulation.Observables.stride_count,initialObjective, ...
    initialTerms.StrideDuration.Value,initialTerms.FootfallTiming.Value,initialTerms.LoadingForce.Value);
clear cleanup
