classdef TestContinuationStagnation < matlab.unittest.TestCase
    methods (Test)
        function finiteWindowDetectsSmallNetProgress(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(732);
            result=lmz.services.ContinuationService().run(problem,pair, ...
                struct('MaximumPoints',10,'BothDirections',false, ...
                'InitialStep',0.05,'MinimumStep',0.005,'MaximumStep',0.05, ...
                'DuplicateTolerance',0.04,'StagnationWindow',4),context);
            testCase.verifyEqual(result.TerminationReason,'stagnation');
            testCase.verifyGreaterThan(result.Branch.pointCount(),3);
            testCase.verifyEqual(result.Snapshots(end).Diagnostics. ...
                TerminationCandidate,'stagnation');
            testCase.verifyTrue(result.Snapshots(end).Accepted);
        end
    end
end
