classdef TestQuadLoadFiveStrideHorizon < matlab.unittest.TestCase
    methods (Test)
        function fiveStrideLayoutIsNotReportedAsPhysicalHorizon(testCase)
            problem=lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingProblem([],struct( ...
                'NumberOfStrides',5,'EnergyMode','diagnostic_only'));
            testCase.verifyEqual(problem.Horizon.segmentCount(),5);
            testCase.verifyEqual(problem.Codec.unknownCount(),115);
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            status=evidence.horizonStatus();
            testCase.verifyEqual(status.completedPhysicalStrideCount,2);
            testCase.verifyFalse(status.fiveStrideRootFound);
            testCase.verifyFalse( ...
                status.physicalFiveStrideSimulationPublished);
            testCase.verifyFalse(status.syntheticCarryForwardUsed);
            testCase.verifyFalse(status.globalInfeasibilityClaimed);
        end

        function boundedWorkBoundarySearchIsQualifiedAndReplayable(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            record=evidence.caseRecord( ...
                'n5_stride_boundary_bounded_work_best_known');
            replay=evidence.replay(record.id, ...
                lmz.api.RunContext.synchronous(0),false);
            attempts=evidence.attempts(record.id);

            testCase.verifyEqual(record.sectionId,'stride_boundary');
            testCase.verifyEqual(logical(record.eventFreeMask), ...
                [true;false]);
            testCase.verifyEqual(record.unknownCount,119);
            testCase.verifyEqual(record.residualCount,119);
            testCase.verifyEqual(record.jacobianRankEstimate,112);
            testCase.verifyEqual(record.nullity,7);
            testCase.verifyEqual(numel(record.singularValues),119);
            testCase.verifyEqual(record.conditionEstimate,'Inf');
            testCase.verifyGreaterThan(record.firstOrderOptimality,0);
            testCase.verifyEmpty(record.activeLowerBounds);
            testCase.verifyEmpty(record.activeUpperBounds);
            testCase.verifyEqual(numel(replay.Decision),119);
            testCase.verifyTrue(replay.PhysicalValidity);
            testCase.verifyTrue(replay.CrossingsAccepted);
            testCase.verifyTrue(replay.EventOrderValid);
            testCase.verifyFalse(replay.RootFound);
            testCase.verifyEqual(replay.Classification, ...
                'numerical_failure');
            testCase.verifyFalse(replay.SolverTerminationAcceptable);
            testCase.verifyTrue(replay.StoredClassificationMatch);
            testCase.verifyFalse(record.simulationPublished);
            testCase.verifyGreaterThan(min( ...
                record.minimumEventGapBySegment),0);
            testCase.verifyEqual(replay.ScaledResidualNorm, ...
                record.scaledResidualNorm,'AbsTol',1e-12);
            testCase.verifyEqual(replay.MaximumScaledResidual, ...
                record.maximumScaledResidual,'AbsTol',1e-12);
            testCase.verifyEqual(replay.BlockNames,record.blockNames);
            testCase.verifyEqual(replay.BlockScaledNorms, ...
                record.blockScaledNorms(:),'AbsTol',1e-12);
            testCase.verifyTrue(replay.StoredBlockNamesMatch);
            testCase.verifyTrue(replay.StoredBlockNormsMatch);
            testCase.verifyNumElements(attempts,1);
            testCase.verifyEqual(attempts{1}.seedDecisionSource, ...
                'deterministicSearchSeed');
            testCase.verifyNumElements(record.deterministicSearchSeed,119);
            testCase.verifyEqual(record.controlChangeReport.finalControls, ...
                record.changedControls,'AbsTol',0);
            testCase.verifyEqual(record.controlChangeReport.lowerBounds, ...
                zeros(4,1));
            testCase.verifyEqual(record.controlChangeReport.upperBounds, ...
                100*ones(4,1));
            testCase.verifyEqual(record.controlChangeReport. ...
                deltaFromBaseline,record.controlChangeReport.finalControls- ...
                record.controlChangeReport.baselineControls,'AbsTol',1e-12);
            testCase.verifyEqual(attempts{1}.scaledResidualNorm, ...
                record.scaledResidualNorm,'AbsTol',0);
            summaries=record.candidateFamilySummaries;
            if isstruct(summaries),summaries=num2cell(summaries);end
            summaries=summaries(:);
            testCase.verifyNumElements(summaries,4);
            testCase.verifyFalse(record.candidateFamilySummariesGating);
            testCase.verifyEqual(cellfun(@(item)item.scaledResidualNorm, ...
                summaries(:)),record.candidateFamilyScaledResidualNorms(:), ...
                'AbsTol',0);
            testCase.verifyEqual(record.searchSummary. ...
                primaryContinuationStageSolveCount,20);
            testCase.verifyEqual(record.searchSummary. ...
                persistenceReplayStageSolveCount,5);
            testCase.verifyFalse(evidence.horizonStatus(). ...
                relaxedFiveStrideRootFound);
        end
    end
end
