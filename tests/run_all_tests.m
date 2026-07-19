function results=run_all_tests
root=fileparts(fileparts(mfilename('fullpath'))); startup;
addpath(fullfile(root,'tools')); results=runtests(fullfile(root,'tests'),'IncludeSubfolders',true);
end
