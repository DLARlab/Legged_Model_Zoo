projectRoot=fileparts(fileparts(mfilename('fullpath')));run(fullfile(projectRoot,'startup.m'));cleanup=onCleanup(@()close('all'));
registry=lmz.registry.ModelRegistry.discover();branch=lmz.services.BranchService().loadBuiltInBranch(registry,'slip_quadruped');
plot(branch.decision('dx'),branch.decision('dphi'),'LineWidth',1.5);xlabel('Forward speed, dx');ylabel('Pitch rate, dphi');grid on;clear cleanup
