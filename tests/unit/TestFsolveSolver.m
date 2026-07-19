classdef TestFsolveSolver < matlab.unittest.TestCase
    methods (Test)
        function solvesBothPeriodicProblems(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch(catalog.defaultBranchPath(),problem);seed=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));result=lmz.services.SolveService().solve(problem,seed,struct(),lmz.api.RunContext.synchronous(1));testCase.verifyGreaterThan(result.ExitFlag,0);testCase.verifyLessThan(result.Evaluation.ScaledResidualNorm,1e-9);
            qproblem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();branch=lmz.services.BranchService().loadRoadMapBranch(qproblem,catalog.defaultBranchPath());qseed=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));qresult=lmz.services.SolveService().solve(qproblem,qseed,struct(),lmz.api.RunContext.synchronous(2));testCase.verifyEqual(qresult.Output.algorithm,'accepted-existing-seed');testCase.verifyLessThan(qresult.Evaluation.ScaledResidualNorm,1e-7);
        end
    end
end
