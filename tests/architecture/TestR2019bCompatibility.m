classdef TestR2019bCompatibility < matlab.unittest.TestCase
    methods (Test)
        function staticAuditHasNoKnownPostReleaseDependency(testCase)
            [violations,report]=check_matlab_compatibility( ...
                lmz.util.ProjectPaths.root());
            testCase.verifyEmpty(violations,strjoin(violations,sprintf('\n')));
            testCase.verifyEqual(report.TargetRelease,'R2019b');
            testCase.verifyGreaterThan(report.Counts.UIComponents,0);
            testCase.verifyGreaterThan(report.Counts.OptimizationOptions,0);
            testCase.verifyGreaterThan(report.Counts.GuardedExportGraphicsCalls,0);
            testCase.verifyGreaterThan(report.Counts.CompatibilityRoutedCalls,10);
            testCase.verifyEqual(report.RuntimeRelease,version('-release'));
            testCase.verifyEqual(report.RuntimeVerified, ...
                strcmpi(version('-release'),'2019b'));
            testCase.verifyEqual(report.StaticOnly,~report.RuntimeVerified);
        end
    end
end
