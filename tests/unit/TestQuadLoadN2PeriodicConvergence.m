classdef TestQuadLoadN2PeriodicConvergence < matlab.unittest.TestCase
    methods (Test)
        function searchIsPreciselyQualifiedWhenPeriodicRootWasNotFound(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            record=evidence.caseRecord('n2_periodic_best_known');
            replay=evidence.replay(record.id, ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual(record.residualCount,60);
            testCase.verifyEqual(record.unknownCount,46);
            testCase.verifyEqual(record.jacobianRankEstimate,46);
            testCase.verifyEqual(record.nullity,0);
            testCase.verifyEqual(numel(record.singularValues),46);
            testCase.verifyEmpty(record.activeLowerBounds);
            testCase.verifyEmpty(record.activeUpperBounds);
            testCase.verifyTrue(replay.PhysicalValidity);
            testCase.verifyFalse(replay.RootFound);
            testCase.verifyEqual(replay.Classification, ...
                'numerical_failure');
            testCase.verifyFalse(replay.SolverTerminationAcceptable);
            testCase.verifyTrue(replay.StoredClassificationMatch);
            testCase.verifyEqual(replay.ScaledResidualNorm, ...
                record.scaledResidualNorm,'AbsTol',1e-12);
            testCase.verifyEqual(replay.BlockNames,record.blockNames);
            testCase.verifyEqual(replay.BlockScaledNorms, ...
                record.blockScaledNorms(:),'AbsTol',1e-12);
            testCase.verifyTrue(replay.StoredBlockNamesMatch);
            testCase.verifyTrue(replay.StoredBlockNormsMatch);
            testCase.verifyEqual(record.solver.terminationReason, ...
                'iteration_or_evaluation_limit');
            testCase.verifyFalse(record.globalInfeasibilityClaimed);
            testCase.verifyFalse(record.simulationPublished);
        end
    end
end
