classdef TestBipedSolve < matlab.unittest.TestCase
    methods (Test)
        function acceptsPublishedScientificSeed(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch([],problem,true);
            seed=branch.point(catalog.Manifest.defaultSeedIndex);
            result=lmz.services.SolveService().solve(problem,seed,struct(),lmz.api.RunContext.synchronous(73));
            testCase.verifyGreaterThan(result.ExitFlag,0);
            testCase.verifyLessThan(result.Evaluation.ScaledResidualNorm,1e-10);
            testCase.verifyEqual(result.Output.algorithm,'accepted-existing-seed');
        end
    end
end
