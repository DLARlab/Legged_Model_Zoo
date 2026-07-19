projectRoot = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
directoryCleanup = onCleanup(@()cd(originalDirectory));
cd(projectRoot);
app = legged_model_zoo; %#ok<NASGU>
cd(originalDirectory);
clear directoryCleanup
