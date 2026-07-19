classdef TestOptimizationWorkflow < matlab.unittest.TestCase
    methods (Test)
        function objectivesDecrease(testCase)
            registry=lmz.registry.ModelRegistry.discover();cases={{'slip_biped','trajectory_fit'},{'slip_quad_load','multi_stride_fit'}};
            for index=1:numel(cases),item=cases{index};problem=registry.createModel(item{1}).createProblem(item{2},struct());seed=problem.makeSolution(problem.getDecisionSchema().defaults(),[],[]);[initial,~,~]=problem.evaluateObjective(seed.DecisionValues,seed.ParameterValues,lmz.api.RunContext.synchronous(0));result=lmz.services.OptimizationService().run(problem,seed,struct(),lmz.api.RunContext.synchronous(index));testCase.verifyLessThan(result.Objective,initial);testCase.verifyGreaterThan(result.ExitFlag,0);end
        end
    end
end
