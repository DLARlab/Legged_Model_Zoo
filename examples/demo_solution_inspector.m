projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;cleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();branch=lmz.services.BranchService().loadBuiltInBranch(registry,'slip_biped');solution=branch.point(1);disp(solution.DecisionSchema.unpack(solution.DecisionValues));clear cleanup
