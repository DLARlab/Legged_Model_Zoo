projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('slip_biped');
problem=model.createProblem('periodic_apex',struct());
catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
datasets=lmz.services.BranchService().loadAllGaitMapBranches(problem);
branch=datasets{1}.Branch;
seedIndex=catalog.recommendedSeedIndex(catalog.defaultBranchPath());
solution=branch.point(seedIndex);
request=lmz.api.SimulationRequest('slip_biped','periodic_apex',solution,struct());
simulation=model.simulate(request,lmz.api.RunContext.synchronous(60));
output=struct('Catalog',catalog.Manifest,'Datasets',{datasets},'Branch',branch, ...
    'SeedIndex',seedIndex,'Solution',solution,'Simulation',simulation, ...
    'TotalBranchPoints',sum(cellfun(@(x)x.Branch.pointCount(),datasets)), ...
    'SuccessMarker','LMZ_BIPED_GAITMAP_WORKFLOW_OK');
fprintf('%s branches=%d points=%d\n',output.SuccessMarker,numel(datasets), ...
    output.TotalBranchPoints);
clear directoryCleanup
