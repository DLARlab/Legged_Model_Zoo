projectRoot = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
directoryCleanup = onCleanup(@()cd(originalDirectory));
cd(projectRoot);
startup;
cd(originalDirectory);
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('slip_biped');
problem = model.createProblem('demo_stride', struct());
simulation = lmz.services.SimulationService().simulate(problem, struct(), ...
    struct(), lmz.api.RunContext.synchronous(1));
plot(simulation.state('x'), simulation.state('y'));
clear directoryCleanup
