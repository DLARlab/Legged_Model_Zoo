classdef TestCoreReleaseProfile < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addReleaseTools(testCase)
            path=fullfile(lmz.util.ProjectPaths.root(),'tools','release');addpath(path);
            testCase.addTeardown(@()rmpath(path));
        end
    end
    methods (Test)
        function coreDryRunReportsAuthorizationBlock(testCase)
            result=build_release('core',struct('DryRun',true));
            testCase.verifyFalse(result.Authorized);
            testCase.verifyFalse(result.Retained);
            testCase.verifyNotEmpty(result.BlockingFiles);
        end

        function publicCoreFailsBeforeOutput(testCase)
            output=tempname;cleanup=onCleanup(@()removeTree(output));
            testCase.verifyError(@()build_release('core',struct( ...
                'Mode','public','OutputDirectory',output)), ...
                'lmz:Release:AuthorizationBlocked');
            testCase.verifyNotEqual(exist(output,'dir'),7);
            clear cleanup
        end

        function technicalZipIsDeterministicAndTemporary(testCase)
            first=build_release('core',struct('Mode','technical-validation'));
            second=build_release('core',struct('Mode','technical-validation'));
            testCase.verifyEqual(first.Sha256,second.Sha256);
            testCase.verifyTrue(first.Verification.Valid);
            testCase.verifyEqual(first.Verification.TestEvidence.cleanInstall, ...
                'not-requested');
            testCase.verifyEqual( ...
                first.Verification.TestEvidence.automatedTestSuite, ...
                'not-run-by-package-builder');
            testCase.verifyTrue(any(strcmp( ...
                first.Verification.SourceTreeState.worktreeStatus, ...
                {'clean','dirty','unknown'})));
            testCase.verifyEqual(first.SourceTreeState, ...
                first.Verification.SourceTreeState);
            testCase.verifyFalse(first.Retained);
            testCase.verifyEmpty(first.ArchivePath);
        end
    end
end

function removeTree(path),if exist(path,'dir')==7,rmdir(path,'s');end,end
