classdef TestScientificCheckpointResume < matlab.unittest.TestCase
    methods (Test)
        function controlledQuadrupedStopResumesFromAtomicCheckpoint(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quadruped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            branch=lmz.services.BranchService().loadRoadMapBranch( ...
                problem,catalog.defaultBranchPath());
            seedIndex=catalog.recommendedSeedIndex(catalog.defaultBranchPath());
            pair=lmz.services.SeedService().adjacentBranchPair( ...
                problem,branch,seedIndex,1,struct(), ...
                lmz.api.RunContext.synchronous(750));
            checkpoint=[tempname '.mat'];
            cleanup=onCleanup(@()deleteIfPresent(checkpoint));
            stopContext=lmz.api.RunContext.synchronous(751);
            stopped=lmz.services.ContinuationService().run(problem,pair, ...
                struct('MaximumPoints',8,'BothDirections',false, ...
                'InitialStep',pair.AchievedRadius, ...
                'MaximumStep',pair.AchievedRadius, ...
                'CheckpointPath',checkpoint,'AcceptedFcn',@stopAfterAccept), ...
                stopContext);
            testCase.verifyEqual(stopped.TerminationReason,'controlled_stop');
            testCase.verifyGreaterThanOrEqual(stopped.Branch.pointCount(),3);
            resumed=lmz.services.ContinuationService().resumeCheckpoint( ...
                problem,checkpoint,struct('MaximumPoints',4), ...
                lmz.api.RunContext.synchronous(752));
            testCase.verifyEqual(resumed.Branch.pointCount(),4);
            artifact=lmz.io.ArtifactStore.load(checkpoint);
            testCase.verifyTrue(isfield(artifact,'continuationSnapshots'));
            testCase.verifyNotEmpty(artifact.continuationSnapshots);
            snapshot=artifact.continuationSnapshots{end};
            testCase.verifyTrue(isfield(snapshot.Diagnostics,'CorrectorIterations'));
            testCase.verifyTrue(isfield(snapshot.Diagnostics,'CheckpointPath'));
            clear cleanup
            function stopAfterAccept(~),stopContext.Cancellation.cancel();end
        end
    end
end

function deleteIfPresent(path),if exist(path,'file')==2,delete(path);end,end
