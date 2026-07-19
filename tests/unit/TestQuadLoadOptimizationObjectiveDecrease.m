classdef TestQuadLoadOptimizationObjectiveDecrease < matlab.unittest.TestCase
    methods (Test)
        function genericOptimizationImprovesExactStoredSourceSeed(testCase)
            model=lmzmodels.slip_quad_load.Model();
            problem=model.createProblem('multi_stride_fit',struct('InitialPerturbation',0));
            source=problem.sourceSeed();active=problem.ActiveOptimizationIndices;
            parameters=problem.getParameterSchema().defaults();
            testCase.verifyEqual(problem.getDecisionSchema().defaults(),source);
            seed=problem.makeSolution(source,parameters,[]);
            context=lmz.api.RunContext.synchronous(511);
            [initial,initialTerms]=problem.evaluateObjective(source,parameters,context);
            options=struct('Algorithm','sqp','MaxIterations',1, ...
                'MaxFunctionEvaluations',30,'OptimalityTolerance',1e-5, ...
                'StepTolerance',1e-5);
            result=lmz.services.OptimizationService().run(problem,seed,options,context);
            testCase.verifyLessThan(result.Objective,initial);
            testCase.verifyTrue(isfinite(result.Objective));
            testCase.verifyEqual(result.Output.freeVariableIndices,active(:));
            testCase.verifyEqual(result.SourceSeed.DecisionValues,source);
            testCase.verifyEqual(numel(result.Solution.DecisionValues),57);
            testCase.verifyEqual(fieldnames(result.Terms),fieldnames(initialTerms));
            simulation=problem.simulateDecision(result.Solution.DecisionValues,context);
            testCase.verifyEqual(simulation.Observables.stride_count,2);
            artifact=result.toArtifact();
            testCase.verifyEqual(artifact.artifactType,'optimization-run');
            testCase.verifyEqual(artifact.problemMaturity,'validated');
            testCase.verifyEqual(artifact.validationStatus,'source-equivalent');
        end
        function activeSubsetConfigurationRejectsOtherEntries(testCase)
            testCase.verifyError(@()lmzmodels.slip_quad_load.MultiStrideFitProblem( ...
                lmzmodels.slip_quad_load.Model(),struct('ActiveOptimizationIndices',1)), ...
                'lmz:QuadLoad:ActiveOptimizationIndices');
        end
    end
end
