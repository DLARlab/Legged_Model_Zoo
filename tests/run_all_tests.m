function results=run_all_tests
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'tests','fixtures'));suite=matlab.unittest.TestSuite.fromFolder(fullfile(root,'tests'),'IncludingSubfolders',true);results=run(suite);assertSuccess(results);
end
