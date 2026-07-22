classdef TestSolveIterationEvents < matlab.unittest.TestCase
    methods (Test)
        function acceptedSeedPublishesZeroIterationLifecycle(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            problem=registry.createModel('slip_biped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            branch=catalog.loadBranch([],problem,true);
            seed=branch.point(catalog.Manifest.defaultSeedIndex);

            progress=lmz.data.SolveProgress();
            result=lmz.services.SolveService().solve(problem,seed, ...
                struct('Progress',progress), ...
                lmz.api.RunContext.synchronous(1101));

            testCase.verifySameHandle(result.Progress,progress);
            testCase.verifyEqual(progress.Events,{ ...
                'seed_selected';'seed_evaluated';'solve_completed'});
            testCase.verifyEqual(result.Output.iterations,0);
            testCase.verifyEqual(result.Output.funcCount,2);
            testCase.verifyEqual(progress.Snapshots(end).Iteration,0);
            testCase.verifyLessThan( ...
                progress.Snapshots(end).ScaledResidual,1e-10);
            artifact=result.toArtifact();
            testCase.verifyEqual(artifact.solveProgress.Events, ...
                progress.Events);
            testCase.verifyEqual(artifact.solveResult.Progress.Events, ...
                progress.Events);
        end

        function fsolveComposesCallbacksAndTypedIterationSnapshots(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'periodic_hop',struct());
            decision=problem.getDecisionSchema().defaults();
            parameters=problem.getParameterSchema().defaults();
            decision(5)=decision(5)+0.08;
            seed=problem.makeSolution(decision,parameters,[]);
            outputSeen=lmz.api.CancellationToken();
            callbackSeen=lmz.api.CancellationToken();
            progress=lmz.data.SolveProgress();
            callbacks=lmz.solvers.SolveCallbacks(struct( ...
                'IterationFcn',@recordIteration));

            result=lmz.services.SolveService().solve(problem,seed,struct( ...
                'AcceptExistingTolerance',0,'MaxIterations',100, ...
                'MaxFunctionEvaluations',500,'OutputFcn',@recordOutput, ...
                'Callbacks',callbacks,'Progress',progress), ...
                lmz.api.RunContext.synchronous(1102));

            testCase.verifyGreaterThan(result.ExitFlag,0);
            testCase.verifyTrue(outputSeen.IsCancellationRequested);
            testCase.verifyTrue(callbackSeen.IsCancellationRequested);
            testCase.verifyTrue(any(strcmp(progress.Events,'solve_started')));
            testCase.verifyTrue(any(strcmp(progress.Events,'iteration')));
            testCase.verifyTrue(any(strcmp(progress.Events,'step_accepted')));
            testCase.verifyEqual(progress.Events{end},'solve_completed');
            iteration=progress.Snapshots(find( ...
                strcmp(progress.Events,'iteration'),1,'last'));
            testCase.verifyClass(iteration, ...
                'lmz.data.SolveIterationSnapshot');
            testCase.verifySize(iteration.DecisionValues, ...
                size(decision));
            testCase.verifyGreaterThanOrEqual(iteration.Iteration,0);
            testCase.verifyGreaterThan(iteration.FunctionCount,0);
            testCase.verifyTrue(isfinite(iteration.ScaledResidual));
            testCase.verifyEqual(result.Progress,progress);

            function stop=recordOutput(~,~,~)
                outputSeen.cancel();stop=false;
            end
            function stop=recordIteration(~,snapshot)
                testCase.verifyClass(snapshot, ...
                    'lmz.data.SolveIterationSnapshot');
                callbackSeen.cancel();stop=false;
            end
        end

        function projectionPublishesTypedLifecycle(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'periodic_hop',struct());
            seed=problem.makeSolution( ...
                problem.getDecisionSchema().defaults(), ...
                problem.getParameterSchema().defaults(),[]);
            callbackSeen=lmz.api.CancellationToken();
            callbacks=lmz.solvers.SolveCallbacks(struct( ...
                'ProjectionCompletedFcn',@recordProjection));

            [projected,~,progress]=lmz.services.SeedService().project( ...
                problem,seed,struct('Callbacks',callbacks), ...
                lmz.api.RunContext.synchronous(1103));

            testCase.verifyEqual(progress.Events,{ ...
                'projection_started';'projection_completed'});
            testCase.verifyTrue(callbackSeen.IsCancellationRequested);
            testCase.verifyEqual(projected.DecisionValues, ...
                seed.DecisionValues,'AbsTol',0);

            function stop=recordProjection(~,snapshot)
                testCase.verifyClass(snapshot, ...
                    'lmz.data.SolveIterationSnapshot');
                callbackSeen.cancel();stop=false;
            end
        end

        function callbackControlledStopPersistsArtifactReason(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'periodic_hop',struct());
            decision=problem.getDecisionSchema().defaults();
            decision(5)=decision(5)+0.08;
            seed=problem.makeSolution(decision, ...
                problem.getParameterSchema().defaults(),[]);
            callbacks=lmz.solvers.SolveCallbacks(struct( ...
                'IterationFcn',@stopAtFirstIteration));

            result=lmz.services.SolveService().solve(problem,seed,struct( ...
                'AcceptExistingTolerance',0,'MaxIterations',100, ...
                'MaxFunctionEvaluations',500,'Callbacks',callbacks), ...
                lmz.api.RunContext.synchronous(1104));
            artifact=result.toArtifact();

            testCase.verifyEqual(result.Progress.Events{end}, ...
                'controlled_stop');
            testCase.verifyEqual(result.Progress.TerminationReason, ...
                'controlled_stop');
            testCase.verifyEqual(artifact.solveResult.TerminationReason, ...
                'controlled_stop');
            testCase.verifyEqual(artifact.terminationReason, ...
                'controlled_stop');

            function stop=stopAtFirstIteration(~,~)
                stop=true;
            end
        end
    end
end
