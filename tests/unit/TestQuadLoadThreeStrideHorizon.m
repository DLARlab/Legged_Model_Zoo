classdef TestQuadLoadThreeStrideHorizon < matlab.unittest.TestCase
    methods (Test)
        function unresolvedSearchEvidenceNeverClaimsThreeStrideRoot(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            fixed=evidence.caseRecord('case_a_fixed_controls_best_known');
            relaxed=evidence.caseRecord( ...
                'case_b_energy_neutral_controls_best_known');
            testCase.verifyEqual(fixed.numberOfStrides,3);
            testCase.verifyEqual(relaxed.numberOfStrides,3);
            testCase.verifyFalse(fixed.rootFound);
            testCase.verifyFalse(relaxed.rootFound);
            testCase.verifyFalse(fixed.simulationPublished);
            testCase.verifyFalse(relaxed.simulationPublished);
            testCase.verifyFalse(evidence.horizonStatus().threeStrideRootFound);
        end
    end
end
