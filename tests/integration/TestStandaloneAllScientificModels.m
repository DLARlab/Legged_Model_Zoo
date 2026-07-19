classdef TestStandaloneAllScientificModels < matlab.unittest.TestCase
    methods (Test)
        function cleanCopiedRepositoryProcess(testCase)
            sourceRoot = lmz.util.ProjectPaths.root();
            temporaryParent = tempname;
            mkdir(temporaryParent);
            cleanup = onCleanup(@()removeDirectory(temporaryParent));
            isolatedRoot = fullfile(temporaryParent,'Legged_Model_Zoo');
            [copied,message] = copyfile(sourceRoot,isolatedRoot);
            testCase.assertTrue(copied,message);

            matlabExecutable = fullfile(matlabroot,'bin','matlab');
            if ispc,matlabExecutable=[matlabExecutable '.exe'];end
            testCase.assertEqual(exist(matlabExecutable,'file'),2, ...
                'The current MATLAB executable could not be located.');
            expression = sprintf(['cd(''%s'');addpath(''%s'');' ...
                'report=run_standalone_all_scientific_models;' ...
                'assert(report.Success);'],matlabQuote(isolatedRoot), ...
                matlabQuote(fullfile(isolatedRoot,'tools')));
            command = sprintf('"%s" -batch "%s"', ...
                matlabExecutable,shellDoubleQuote(expression));
            [status,output] = system(command);
            testCase.verifyEqual(status,0,output);
            testCase.verifyNotEmpty(strfind(output, ...
                'ISOLATED_ALL_SCIENTIFIC_MODELS_OK'),output);
            clear cleanup
        end
    end
end

function value = matlabQuote(value)
value = strrep(value,'''','''''');
end

function value = shellDoubleQuote(value)
value = strrep(value,'\','\\');
value = strrep(value,'"','\"');
value = strrep(value,'$','\$');
value = strrep(value,'`','\`');
end

function removeDirectory(path)
if exist(path,'dir')==7
    rmdir(path,'s');
end
end
