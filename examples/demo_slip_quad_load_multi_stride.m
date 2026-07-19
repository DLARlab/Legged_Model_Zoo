%DEMO_SLIP_QUAD_LOAD_MULTI_STRIDE Source-equivalent transition simulation.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('slip_quad_load');
problem=model.createProblem('multi_stride_fit',struct('InitialPerturbation',0));
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
[branch,dataset]=lmz.services.BranchService().loadQuadLoadDataset( ...
    problem,catalog.defaultMultiPath());
solution=branch.point(1);context=lmz.api.RunContext.synchronous(82);
[objective,terms,diagnostics]=problem.evaluateObjective( ...
    solution.DecisionValues,solution.ParameterValues,context);
simulation=lmz.services.SolutionService().simulate(problem,solution,context);
output=struct('Dataset',dataset,'Branch',branch,'Solution',solution, ...
    'Objective',objective,'Terms',terms,'Diagnostics',diagnostics, ...
    'Simulation',simulation,'SuccessMarker','LMZ_QUAD_LOAD_MULTI_STRIDE_OK');
fprintf('%s strides=%d samples=%d objective=%.12g\n',output.SuccessMarker, ...
    simulation.Observables.stride_count,numel(simulation.Time),objective);
clear directoryCleanup
