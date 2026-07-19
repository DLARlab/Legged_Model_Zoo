projectRoot = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
directoryCleanup = onCleanup(@()cd(originalDirectory));
cd(projectRoot);
startup;
cd(originalDirectory);
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_quad_load');
problem = model.createProblem('demo_stride', struct());
simulation = lmz.services.SimulationService().simulate(problem, struct(), ...
    struct(), lmz.api.RunContext.synchronous(3));
plot(simulation.state('quad_x'), simulation.state('quad_y'));
clear directoryCleanup
