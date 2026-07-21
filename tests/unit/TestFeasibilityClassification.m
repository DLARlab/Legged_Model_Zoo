classdef TestFeasibilityClassification < matlab.unittest.TestCase
    methods (Test)
        function separatesResidualFailureFromPhysicalFailure(testCase)
            problem=lmzmodels.tutorial_hopper.Model().createProblem( ...
                'multiple_shooting',struct('NumberOfSegments',2));
            decision=problem.getDecisionSchema().defaults();
            names=problem.getDecisionSchema().names();
            decision(strcmp(names,'node_2_y'))=1.2;
            context=lmz.api.RunContext.synchronous(1901);
            evaluation=problem.evaluate(decision, ...
                problem.getParameterSchema().defaults(),context,false);
            diagnostics=lmz.solvers.RankAwareNonlinearSolver().analyze( ...
                problem,decision,problem.getParameterSchema().defaults(), ...
                struct(),context);
            report=lmz.shooting.FeasibilityReport.fromSolve( ...
                evaluation,diagnostics,1,1e-9);

            testCase.verifyFalse(evaluation.Feasibility.Valid);
            testCase.verifyTrue( ...
                evaluation.Feasibility.PhysicalConditionsValid);
            testCase.verifyTrue(report.PhysicalConditionsValid);
            testCase.verifyFalse(report.Success);
            testCase.verifyEqual(report.Classification, ...
                'best_known_residual');
        end

        function analysisPreservesPhysicalValidationFailure(testCase)
            [problem,~,~,decision]=lmztest.makeAnalyticShootingProblem( ...
                2,'Configuration',struct('InvalidSegment',2));
            context=lmz.api.RunContext.synchronous(1902);
            report=lmz.services.FeasibilityAnalysisService().analyze( ...
                problem,decision,problem.getParameterSchema().defaults(), ...
                struct('ResidualTolerance',1e-9),context);

            testCase.verifyFalse(report.Success);
            testCase.verifyFalse(report.PhysicalConditionsValid);
            testCase.verifyEqual(report.Classification, ...
                'physical_validation_failure');
            testCase.verifyEqual(report.TerminationReason, ...
                'analysis-only-no-existence-certificate');
        end

        function analysisNeverFabricatesSolverTermination(testCase)
            [problem,~,~,decision]=lmztest.makeAnalyticShootingProblem(2);
            context=lmz.api.RunContext.synchronous(1904);
            evaluation=problem.evaluate(decision, ...
                problem.getParameterSchema().defaults(),context,false);
            testCase.verifyLessThanOrEqual( ...
                max(abs(evaluation.ScaledResidual)),1e-12);

            report=lmz.services.FeasibilityAnalysisService().analyze( ...
                problem,decision,problem.getParameterSchema().defaults(), ...
                struct('ResidualTolerance',1e-9),context);

            testCase.verifyFalse(report.Success);
            testCase.verifyFalse(report.SolverTerminationAcceptable);
            testCase.verifyEqual(report.Classification, ...
                'best_known_residual');
            testCase.verifyEqual(report.TerminationReason, ...
                'analysis-only-no-existence-certificate');
        end

        function multistartRetainsReplayableAttemptInputs(testCase)
            model=lmzmodels.tutorial_hopper.Model();
            problem=model.createProblem('multiple_shooting', ...
                struct('HorizonLength',2));
            seed=problem.getDecisionSchema().defaults();
            invalidSeed=seed(1:end-1);
            parameters=problem.getParameterSchema().defaults();
            solutionSeed=problem.makeSolution(seed,parameters,[]);
            options=struct('Solver','auto','Display','off', ...
                'ResidualTolerance',1e-8,'MaxIterations',10);
            context=lmz.api.RunContext.synchronous(1903);
            evidence=lmz.services.FeasibilityAnalysisService().multistart( ...
                problem,{seed,invalidSeed,solutionSeed}, ...
                parameters,options,context);

            testCase.verifyEqual(evidence.AttemptCount,3);
            testCase.verifyEqual(evidence.Parameters,parameters(:));
            testCase.verifyEqual(evidence.Options,options);
            testCase.verifyEqual(evidence.RandomSeed,1903);
            testCase.verifyEqual(evidence.ProblemIdentity.ModelId, ...
                'tutorial_hopper');
            testCase.verifyEqual(evidence.ProblemIdentity.ProblemId, ...
                'multiple_shooting');
            testCase.verifyEqual(evidence.ProblemConfiguration, ...
                problem.getDescriptor().configuration);
            testCase.verifyEqual(evidence.ProblemConfigurationHash, ...
                lmz.io.ArtifactStore.dataHash( ...
                problem.getDescriptor().configuration));
            testCase.verifyEqual(evidence.ParametersHash, ...
                lmz.io.ArtifactStore.dataHash(parameters(:)));
            testCase.verifyEqual(evidence.OptionsHash, ...
                lmz.io.ArtifactStore.dataHash(options));
            testCase.verifyEqual(evidence.Attempts{1}.Seed,seed(:));
            testCase.verifyEqual(evidence.Attempts{2}.Seed,invalidSeed(:));
            testCase.verifyEqual(evidence.Attempts{3}.Seed, ...
                solutionSeed.toStruct());
            testCase.verifyEqual(evidence.Attempts{1}.RandomSeed,1903);
            testCase.verifyEqual(evidence.Attempts{1}.SeedDerivation, ...
                'caller-provided');
            testCase.verifyEqual(evidence.Attempts{2}.Identifier, ...
                'lmz:Schema:InvalidVector');
            testCase.verifyFalse(evidence.GlobalInfeasibilityProven);
        end
    end
end
