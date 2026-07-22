classdef TestQuadrupedReferenceWorkflowEndToEnd < matlab.unittest.TestCase
    methods (Test)
        function registeredRoadMapSolveSeedsContinueAndRoundTrip(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            registryCleanup=onCleanup(@()delete(registry));
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            descriptor=workflows.get( ...
                'slip_quadruped','roadmap_root_continuation');
            session=lmz.workflow.WorkflowRunner().initialize( ...
                descriptor,lmz.api.RunContext.synchronous(1401));

            testCase.verifyEqual(session.SeedIndex,267);
            testCase.verifyEqual(session.Dataset.Metadata.SourceHash, ...
                ['45835bb5024b1dc9b875c7b8f7b205769f537a4f' ...
                'f4144c763058537f44dbf401']);
            testCase.verifyLessThan( ...
                session.InitialEvaluation.ScaledResidualNorm,1e-7);
            solved=session.solve(struct());
            testCase.verifyGreaterThan(solved.ExitFlag,0);
            testCase.verifyEqual( ...
                solved.Output.algorithm,'accepted-existing-seed');
            testCase.verifyLessThan( ...
                solved.Evaluation.ScaledResidualNorm,1e-8);

            adjacent=session.makeAdjacentSeedPair(+1,struct());
            testCase.verifyEqual( ...
                adjacent.Diagnostics.SourceIndices,[267 268]);
            testCase.verifyGreaterThan(adjacent.AchievedRadius,0);
            generated=session.makeGeneratedSeedPair([],struct());
            testCase.verifyGreaterThan(generated.Diagnostics.ExitFlag,0);
            testCase.verifyLessThan(generated.Diagnostics.ResidualNorm,1e-8);
            testCase.verifyEqual(generated.AchievedRadius, ...
                descriptor.SeedPreset.GeneratedRadius,'AbsTol',2e-6);
            adjacent=session.makeAdjacentSeedPair(+1,struct());

            directionalOptions=struct('MaximumPoints',3, ...
                'InitialStep',adjacent.AchievedRadius, ...
                'MaximumStep',adjacent.AchievedRadius);
            forwardOptions=directionalOptions;
            forwardOptions.DirectionMode='forward';
            forward=session.continueBranch(forwardOptions);
            testCase.verifyEqual(forward.Branch.pointCount(),3);
            testCase.verifyGreaterThan( ...
                forward.Branch.point(3).decision('dx'), ...
                forward.Branch.point(2).decision('dx'));
            backwardOptions=directionalOptions;
            backwardOptions.DirectionMode='backward';
            backward=session.continueBranch(backwardOptions);
            testCase.verifyEqual(backward.Branch.pointCount(),3);
            testCase.verifyLessThan( ...
                backward.Branch.point(3).decision('dx'), ...
                backward.Branch.point(2).decision('dx'));

            checkpoint=[tempname '.lmz.mat'];
            artifactPath=[tempname '.lmz.mat'];
            fileCleanup=onCleanup(@()deleteFiles({checkpoint,artifactPath}));
            acceptedDirections=[];
            continuation=session.continueBranch(struct( ...
                'MaximumPoints',6,'DirectionMode','both', ...
                'InitialStep',adjacent.AchievedRadius, ...
                'MaximumStep',adjacent.AchievedRadius, ...
                'CheckpointPath',checkpoint, ...
                'AcceptedFcn',@acceptedPoint));
            testCase.verifyEqual(continuation.Branch.pointCount(),6);
            testCase.verifyEqual( ...
                continuation.TerminationReason,'maximum_points');
            testCase.verifyTrue(any(acceptedDirections<0));
            testCase.verifyTrue(any(acceptedDirections>0));
            testCase.verifyEqual( ...
                lmz.io.ArtifactStore.load(checkpoint). ...
                checkpointState.PointCount,6);

            resumed=session.resumeCheckpoint(checkpoint, ...
                struct('MaximumPoints',7));
            testCase.verifyEqual(resumed.Branch.pointCount(),7);
            lmz.io.ArtifactStore.save(artifactPath,resumed.toArtifact());
            restored=lmz.data.SolutionBranch.fromArtifact( ...
                lmz.io.ArtifactStore.load(artifactPath));
            testCase.verifyEqual(restored.pointCount(),7);
            testCase.verifyEqual(restored.ModelId,'slip_quadruped');
            result=session.result();
            testCase.verifyEqual( ...
                result.WorkflowId,'roadmap_root_continuation');
            testCase.verifyClass(result.ContinuationResult, ...
                'lmz.data.ContinuationResult');
            clear fileCleanup registryCleanup

            function acceptedPoint(state)
                acceptedDirections(end+1)=state.Direction;
            end
        end

        function touchdownWorkflowTransfersAndBuildsLocalPair(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            descriptor=workflows.get( ...
                'slip_quadruped','touchdown_root_continuation');
            session=lmz.workflow.WorkflowRunner().initialize( ...
                descriptor,lmz.api.RunContext.synchronous(1402));
            testCase.verifyEqual( ...
                session.SourceBranch.ProblemId,'periodic_apex');
            testCase.verifyEqual( ...
                session.WorkingSolution.ProblemId,'periodic_orbit');
            testCase.verifyNumElements( ...
                session.WorkingSolution.DecisionValues,21);
            testCase.verifyLessThan( ...
                session.InitialEvaluation.ScaledResidualNorm,1e-7);
            pair=session.makeAdjacentSeedPair(+1,struct());
            testCase.verifyTrue(pair.Diagnostics.SectionLocal);
            testCase.verifyEqual(pair.Diagnostics.SourceIndices,[267 268]);
            testCase.verifyLessThan(max(pair.Diagnostics.ResidualNorms),1e-7);
            clear cleanup
        end
    end
end

function deleteFiles(paths)
for index=1:numel(paths)
    if exist(paths{index},'file')==2,delete(paths{index});end
end
end
