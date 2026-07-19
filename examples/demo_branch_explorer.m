projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;cleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();branch=lmz.services.BranchService().loadBuiltInBranch(registry,'slip_quadruped');
plot(branch.decision('speed'),branch.decision('stride_period'),'o-');xlabel('speed');ylabel('stride period');clear cleanup
