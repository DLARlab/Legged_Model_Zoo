%DEMO_SLIP_QUAD_LOAD_SINGLE_STRIDE Source-equivalent 44-entry simulation.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('slip_quad_load');
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset=catalog.load('individual_1_tr_single');
problem=model.createProblem('single_stride',struct('DatasetPath',dataset.Path));
solution=lmzmodels.slip_quad_load.XAccumAdapter.toSolution(problem,dataset);
context=lmz.api.RunContext.synchronous(81);
evaluation=lmz.services.EvaluationService().evaluate( ...
    problem,solution,true,context);
simulation=evaluation.Simulation;
output=struct('Dataset',dataset,'ProblemDescriptor',problem.getDescriptor(), ...
    'Solution',solution,'Evaluation',evaluation,'Simulation',simulation, ...
    'ResidualNorm',evaluation.ScaledResidualNorm, ...
    'SuccessMarker','LMZ_QUAD_LOAD_SINGLE_STRIDE_OK');
fprintf('%s samples=%d events=%d residual=%.6g\n',output.SuccessMarker, ...
    numel(simulation.Time),numel(simulation.EventRecords),output.ResidualNorm);
clear directoryCleanup
