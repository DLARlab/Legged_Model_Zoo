classdef TestCodeQuality < matlab.unittest.TestCase
    methods (Test)
        function maintainedRuntimeHasNoUnapprovedFindings(testCase)
            report = run_code_quality(lmz.util.ProjectPaths.root());
            testCase.verifyEmpty(report.Violations, ...
                strjoin(report.Violations, sprintf('\n')));
            testCase.verifyGreaterThan(report.FilesAnalyzed, 100);
            testCase.verifyNotEmpty(report.LegacyExclusionRationale);
        end
    end
end
