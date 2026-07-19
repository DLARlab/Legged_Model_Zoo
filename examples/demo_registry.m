projectRoot = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
directoryCleanup = onCleanup(@()cd(originalDirectory));
cd(projectRoot);
startup;
cd(originalDirectory);
registry = lmz.registry.ModelRegistry.discover();
modelIds = registry.listModels();
disp(modelIds);
clear directoryCleanup
