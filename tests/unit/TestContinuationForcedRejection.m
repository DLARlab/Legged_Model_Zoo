classdef TestContinuationForcedRejection < matlab.unittest.TestCase
    methods (Test)
        function rejectionBacktracksAndKeepsDiagnostics(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(720);
            options=struct('MaximumPoints',5,'BothDirections',false, ...
                'InitialStep',0.08,'MinimumStep',0.005,'MaximumStep',0.08, ...
                'MaxBacktracks',2,'AcceptanceFcn',@(~,~)false);
            result=lmz.services.ContinuationService().run( ...
                problem,pair,options,context);
            testCase.verifyEqual(result.TerminationReason,'maximum_backtracks');
            rejected=result.Snapshots(~[result.Snapshots.Accepted]);
            testCase.verifyEqual(numel(rejected),2);
            testCase.verifyEqual([rejected.StepSize],[0.08 0.04],'AbsTol',1e-12);
            backtracks=arrayfun(@(item)item.Diagnostics.BacktrackingCount,rejected);
            testCase.verifyEqual(backtracks(:),[1;2]);
            required={'Predictor','CorrectedDecision','ResidualNorm','Step', ...
                'Curvature','CorrectorIterations','BacktrackingCount', ...
                'Feasibility','Gait','TerminationCandidate','CheckpointPath'};
            for index=1:numel(required)
                testCase.verifyTrue(isfield(rejected(end).Diagnostics,required{index}));
            end
            artifact=result.toArtifact();
            testCase.verifyEqual(numel(artifact.continuationResult.Snapshots), ...
                numel(result.Snapshots));
        end
        function historyDuplicateProducesRejectedSnapshot(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(721);
            result=lmz.services.ContinuationService().run(problem,pair, ...
                struct('MaximumPoints',4,'BothDirections',false, ...
                'InitialStep',0.05,'MaximumStep',0.05, ...
                'DuplicateTolerance',0.06),context);
            testCase.verifyEqual(result.TerminationReason,'duplicate');
            testCase.verifyFalse(result.Snapshots(end).Accepted);
            testCase.verifyEqual(result.Snapshots(end).Diagnostics.Failure, ...
                'history-duplicate');
            testCase.verifyEqual(result.Snapshots(end).Diagnostics. ...
                TerminationCandidate,'duplicate');
        end
        function cancellationDuringCorrectionPreservesSeeds(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(722);
            result=lmz.services.ContinuationService().run(problem,pair, ...
                struct('MaximumPoints',5,'BothDirections',false, ...
                'PredictionFcn',@cancelAtPrediction),context);
            testCase.verifyEqual(result.TerminationReason,'controlled_stop');
            testCase.verifyEqual(result.Branch.pointCount(),2);
            testCase.verifyFalse(result.Snapshots(end).Accepted);
            testCase.verifyEqual(result.Snapshots(end).Diagnostics. ...
                TerminationCandidate,'controlled_stop');
            testCase.verifyTrue(result.Diagnostics.partialBranchPreserved);
            function cancelAtPrediction(~),context.Cancellation.cancel();end
        end
    end
end
