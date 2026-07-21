classdef TestHorizonCheckpointResume < matlab.unittest.TestCase
    methods (Test)
        function checkpointRestoresDecisionAndHistory(testCase)
            [problem,~,~,seed]=lmztest.makeAnalyticShootingProblem(2);
            history={struct('Step',1,'ResidualNorm',0)};
            service=lmz.shooting.HorizonContinuation();
            checkpoint=service.checkpoint(problem,seed,history,'complete');
            [restored,restoredHistory]=service.resume(checkpoint,problem);
            testCase.verifyEqual(restored,seed);
            testCase.verifyEqual(restoredHistory,history);
            testCase.verifyEqual(checkpoint.SegmentCount,2);
            testCase.verifyEqual(checkpoint.ProblemContractHash, ...
                lmz.io.ArtifactStore.dataHash(checkpoint.ProblemContract));
        end

        function checkpointRejectsSameSizedDifferentProblemAndTampering(testCase)
            model=lmzmodels.tutorial_hopper.Model();
            first=model.createProblem('multiple_shooting',struct( ...
                'HorizonLength',2,'Gravity',9.81));
            other=model.createProblem('multiple_shooting',struct( ...
                'HorizonLength',2,'Gravity',9.7));
            service=lmz.shooting.HorizonContinuation();
            checkpoint=service.checkpoint(first, ...
                first.getDecisionSchema().defaults(),{},'in_progress');
            testCase.verifyError(@()service.resume(checkpoint,other), ...
                'lmz:Shooting:HorizonCheckpointProblemContract');

            tampered=checkpoint;
            tampered.ProblemContract.Configuration.Tampered=true;
            testCase.verifyError(@()service.resume(tampered,first), ...
                'lmz:Shooting:HorizonCheckpointProblemContract');
            tampered.ProblemContractHash=lmz.io.ArtifactStore.dataHash( ...
                tampered.ProblemContract);
            testCase.verifyError(@()service.resume(tampered,first), ...
                'lmz:Shooting:HorizonCheckpointProblemContract');

            executable=checkpoint;
            executable.History={@()true};
            testCase.verifyError(@()service.resume(executable,first), ...
                'lmz:Shooting:HorizonCheckpoint');

            missingHash=rmfield(checkpoint,'ProblemContractHash');
            testCase.verifyError(@()service.resume(missingHash,first), ...
                'lmz:Shooting:HorizonCheckpoint');
            wrongSchema=checkpoint;wrongSchema.SchemaVersion='0.9.0';
            testCase.verifyError(@()service.resume(wrongSchema,first), ...
                'lmz:Shooting:HorizonCheckpoint');

            future=checkpoint;future.FrameworkVersion='9.0.0';
            testCase.verifyError(@()service.resume(future,first), ...
                'lmz:Shooting:HorizonCheckpointFramework');
        end

        function adaptiveHomotopyResumesFromAcceptedCheckpoint(testCase)
            model=lmzmodels.tutorial_hopper.Model();
            configuration=struct('HorizonLength',3);
            problem=model.createProblem('multiple_shooting',configuration);
            anchor=problem.getDecisionSchema().defaults();
            names=problem.getDecisionSchema().names();
            anchor(strcmp(names,'node_2_y'))=1.1;
            common=struct('ResidualTolerance',1e-8, ...
                'HomotopyInitialStep',0.4, ...
                'HomotopyMaximumStep',0.5, ...
                'HomotopyMinimumStep',0.01);
            first=common;first.HomotopyMaximumAttempts=1;
            context=lmz.api.RunContext.synchronous(2104);
            partial=lmz.shooting.HorizonContinuation().traceHomotopy( ...
                problem,anchor,first,context);
            testCase.verifyFalse(partial.Completed);
            checkpoint=partial.Checkpoints{end};
            testCase.verifyGreaterThan(checkpoint.Lambda,0);
            testCase.verifyLessThan(checkpoint.Lambda,1);
            testCase.verifyEqual(checkpoint.AttemptCount,1);
            incompatible=configuration;incompatible.Gravity=9.7;
            testCase.verifyError(@()lmz.services. ...
                HorizonContinuationService().resumeHomotopy( ...
                model,'multiple_shooting',incompatible,anchor, ...
                checkpoint,common,context), ...
                'lmz:Shooting:HorizonHomotopyCheckpointProblemContract');

            changedAnchor=anchor;
            changedAnchor(strcmp(names,'node_2_y'))=1.2;
            testCase.verifyError(@()lmz.services. ...
                HorizonContinuationService().resumeHomotopy( ...
                model,'multiple_shooting',configuration,changedAnchor, ...
                checkpoint,common,context), ...
                'lmz:Shooting:HorizonHomotopyCheckpointAnchor');

            resumedOptions=common;
            resumedOptions.HomotopyMaximumAttempts=50;
            resumed=lmz.services.HorizonContinuationService(). ...
                resumeHomotopy(model,'multiple_shooting',configuration, ...
                anchor,checkpoint,resumedOptions,context);
            testCase.verifyTrue(resumed.Completed);
            testCase.verifyEqual(resumed.Lambda,1);
            testCase.verifyGreaterThan(numel(resumed.Attempts), ...
                numel(partial.Attempts));
            testCase.verifyEqual(resumed.Attempts{1},partial.Attempts{1});
            final=problem.evaluate(resumed.Decision, ...
                problem.getParameterSchema().defaults(),context,false);
            testCase.verifyLessThan(max(abs(final.ScaledResidual)),1e-8);
        end
    end
end
