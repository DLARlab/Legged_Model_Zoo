classdef TestToolboxInstall < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addReleaseTools(testCase)
            path=fullfile(lmz.util.ProjectPaths.root(),'tools','release');addpath(path);
            testCase.addTeardown(@()rmpath(path));
        end
    end
    methods (Test)
        function toolboxDryRunIsAuthorizationBlocked(testCase)
            result=build_toolbox('core',struct('DryRun',true));
            testCase.verifyFalse(result.Authorized);
            testCase.verifyFalse(result.Retained);
        end

        function temporaryToolboxBuildAndInstall(testCase)
            if exist('matlab.addons.toolbox.ToolboxOptions','class')==8
                result=build_toolbox('core',struct( ...
                    'Mode','technical-validation','RunInstallTest',true));
                testCase.verifyNotEmpty(result.Sha256);
                testCase.verifyTrue(result.InstallTest.Passed);
                verifyInstallEvidence(testCase,result.InstallTest);
                testCase.verifyEqual(result.TestEvidence.cleanInstall,'passed');
                testCase.verifyTrue(result.TestEvidence.pathRemoval);
                testCase.verifyFalse(result.Retained);
            else
                result=build_release('core',struct('Mode','technical-validation'));
                testCase.verifyTrue(result.Verification.Valid);
                testCase.verifyFalse(result.Retained);
            end
        end

        function temporaryZipFallbackCleanInstall(testCase)
            result=build_release('core',struct('Mode','technical-validation', ...
                'RunInstallTest',true));
            testCase.verifyTrue(result.InstallTest.Passed);
            testCase.verifyEqual(result.InstallTest.PackageType,'zip');
            verifyInstallEvidence(testCase,result.InstallTest);
            testCase.verifyEqual(result.Verification.TestEvidence.cleanInstall, ...
                'passed');
            testCase.verifyTrue(result.Verification.TestEvidence.pathRemoval);
            testCase.verifyFalse(result.Retained);
        end
    end
end

function verifyInstallEvidence(testCase,report)
testCase.verifyTrue(report.RegistryDiscovery);
testCase.verifyTrue(report.Workflow);
testCase.verifyTrue(report.GuiConstruction);
testCase.verifyTrue(report.ArtifactRoundTrip);
testCase.verifyTrue(report.Unloaded);
required={'registry=1','workflow=1','gui=1','artifact=1','unloaded=1'};
for index=1:numel(required)
    testCase.verifyNotEmpty(strfind(report.Output,required{index}));
end
end
