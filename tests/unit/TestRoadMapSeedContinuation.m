classdef TestRoadMapSeedContinuation < matlab.unittest.TestCase
    methods (Test)
        function solveAdjacentContinueCheckpointResume(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');solved=controller.solveWorkingSolution(struct());testCase.verifyEqual(solved.Output.algorithm,'accepted-existing-seed');
            pair=controller.makeAdjacentSeedPair(1,struct());testCase.verifyEqual(pair.Diagnostics.SourceIndices,[267 268]);
            checkpoint=[tempname '.mat'];cleanup=onCleanup(@()deleteIfPresent(checkpoint));accepted=0;
            options=struct('MaximumPoints',3,'BothDirections',false,'InitialStep',pair.AchievedRadius,'MaximumStep',pair.AchievedRadius,'CheckpointPath',checkpoint,'AcceptedFcn',@acceptedPoint);
            result=controller.runContinuation(options);testCase.verifyEqual(result.Branch.pointCount(),3);testCase.verifyEqual(accepted,1);testCase.verifyEqual(result.TerminationReason,'maximum_points');
            problem=controller.Registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());resumed=lmz.services.ContinuationService().resumeCheckpoint(problem,checkpoint,struct('MaximumPoints',4),lmz.api.RunContext.synchronous(62));testCase.verifyEqual(resumed.Branch.pointCount(),4);testCase.verifyEqual(lmz.io.ArtifactStore.load(checkpoint).checkpointState.PointCount,4);clear cleanup
            function acceptedPoint(~),accepted=accepted+1;end
        end
        function controlledStopPreservesPartialBranch(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');pair=controller.makeAdjacentSeedPair(1,struct());context=lmz.api.RunContext.synchronous(63);problem=controller.Registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());
            result=lmz.services.ContinuationService().run(problem,pair,struct('MaximumPoints',8,'BothDirections',false,'InitialStep',pair.AchievedRadius,'AcceptedFcn',@stopAfterAccept),context);testCase.verifyEqual(result.TerminationReason,'controlled_stop');testCase.verifyGreaterThanOrEqual(result.Branch.pointCount(),3);
            function stopAfterAccept(~),context.Cancellation.cancel();end
        end
        function generatedSecondSeedFromRoadMap(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');pair=controller.makeSecondSeed(0.005);
            testCase.verifyEqual(pair.AchievedRadius,0.005,'AbsTol',2e-6);testCase.verifyLessThan(pair.Diagnostics.ResidualNorm,1e-8);testCase.verifyGreaterThan(pair.Diagnostics.ExitFlag,0);
        end
        function namedHomotopyAndFamilyScan(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');homotopy=controller.runParameterHomotopy('phi_neutral',[0 0.05],struct());testCase.verifyEqual(homotopy.Completed,2);testCase.verifyEqual(homotopy.Solutions(2).parameter('phi_neutral'),0.05,'AbsTol',1e-12);
            options=struct('SecondSeedRadius',0.005,'ContinuationOptions',struct('MaximumPoints',3,'BothDirections',false,'InitialStep',0.005,'MaximumStep',0.005));report=controller.runBranchFamilyScan('phi_neutral',0,options);testCase.verifyEqual(report.Completed,1);testCase.verifyEqual(report.Failed,0);testCase.verifyEqual(report.Status,{'completed'});testCase.verifyEqual(report.Branches{1}.pointCount(),3);testCase.verifyNotEmpty(report.OutputArtifacts{1});
        end
    end
end
function deleteIfPresent(path),if exist(path,'file')==2,delete(path);end,end
