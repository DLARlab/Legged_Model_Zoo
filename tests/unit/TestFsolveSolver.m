classdef TestFsolveSolver < matlab.unittest.TestCase
    methods (Test)
        function solvesBothPeriodicProblems(testCase)
            registry=lmz.registry.ModelRegistry.discover();ids={'slip_biped','slip_quadruped'};
            for index=1:numel(ids),problem=registry.createModel(ids{index}).createProblem('periodic_apex',struct());seed=problem.makeSolution([0.7;1],[],[]);result=lmz.services.SolveService().solve(problem,seed,struct(),lmz.api.RunContext.synchronous(index));testCase.verifyGreaterThan(result.ExitFlag,0);testCase.verifyLessThan(result.Evaluation.ScaledResidualNorm,1e-9);end
        end
    end
end
