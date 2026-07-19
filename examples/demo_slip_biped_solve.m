projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();
problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
branch=lmz.services.BranchService().loadGaitMapBranch(problem,catalog.defaultBranchPath());
seedIndex=catalog.recommendedSeedIndex(catalog.defaultBranchPath());
seed=branch.point(seedIndex);
solveResult=lmz.services.SolveService().solve(problem,seed,struct(), ...
    lmz.api.RunContext.synchronous(21));
output=struct('SeedIndex',seedIndex,'Seed',seed,'SolveResult',solveResult, ...
    'ResidualNorm',solveResult.Evaluation.ScaledResidualNorm, ...
    'SuccessMarker','LMZ_BIPED_SOLVE_OK');
fprintf('%s residual=%.3e\n',output.SuccessMarker,output.ResidualNorm);
clear directoryCleanup
