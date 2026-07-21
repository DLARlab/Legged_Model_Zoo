classdef TestQuadLoadFourStrideHorizon < matlab.unittest.TestCase
    methods (Test)
        function fourStrideRecordIsStructuralAfterUnresolvedThirdStride(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            [~,n2]=evidence.problemFor('n2_transition_feasibility_root');
            configuration=struct('StartStrideCount',2, ...
                'TargetStrideCount',4,'EnergyMode','diagnostic_only', ...
                'InitialDecisionForContinuation',n2);
            result=lmzmodels.slip_quad_load. ...
                QuadLoadHorizonContinuation().continueTo(configuration, ...
                struct('SolveEachHorizon',false), ...
                lmz.api.RunContext.synchronous(0));
            testCase.verifyEqual(result.CompletedStrideCount,4);
            testCase.verifyEqual(result.FinalProblem.Horizon.segmentCount(),4);
            testCase.verifyEqual(numel(result.FinalDecision),92);
            testCase.verifyFalse(result.FinalReport.RootFound);
            testCase.verifyFalse(result.PhysicalFiveStrideRootFound);
            testCase.verifyFalse(evidence.horizonStatus().fourStrideRootFound);
        end
    end
end
