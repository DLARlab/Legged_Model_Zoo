classdef TestScientificReleaseGate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addReleaseTools(testCase)
            path=fullfile(lmz.util.ProjectPaths.root(),'tools','release');addpath(path);
            testCase.addTeardown(@()rmpath(path));
        end
    end
    methods (Test)
        function scientificDryRunListsScientificBlockers(testCase)
            result=build_release('scientific',struct('DryRun',true));
            testCase.verifyFalse(result.Authorized);
            joined=strjoin(result.BlockingFiles,'\n');
            testCase.verifyNotEmpty(strfind(joined,'slip_biped')); %#ok<STREMP>
            testCase.verifyNotEmpty(strfind(joined,'slip_quadruped')); %#ok<STREMP>
            testCase.verifyNotEmpty(strfind(joined,'slip_quad_load')); %#ok<STREMP>
        end

        function scientificPublicGateLeavesNoPartialArchive(testCase)
            output=tempname;cleanup=onCleanup(@()removeTree(output));
            testCase.verifyError(@()build_release('scientific',struct( ...
                'Mode','public','OutputDirectory',output)), ...
                'lmz:Release:AuthorizationBlocked');
            testCase.verifyNotEqual(exist(output,'dir'),7);
            clear cleanup
        end
    end
end

function removeTree(path),if exist(path,'dir')==7,rmdir(path,'s');end,end
