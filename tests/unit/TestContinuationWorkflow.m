classdef TestContinuationWorkflow < matlab.unittest.TestCase
    methods (Test)
        function secondSeedAndBranch(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());u=problem.getDecisionSchema().defaults();p=problem.getParameterSchema().defaults();first=problem.makeSolution(u,p,problem.evaluate(u,p,lmz.api.RunContext.synchronous(0),false));context=lmz.api.RunContext.synchronous(4);
            pair=lmz.services.SeedService().makeSecondSeed(problem,first,0.03,struct(),context);testCase.verifyEqual(pair.AchievedRadius,0.03,'AbsTol',2e-5);
            result=lmz.services.ContinuationService().run(problem,pair,struct('MaximumPoints',8,'BothDirections',false),context);testCase.verifyEqual(result.Branch.pointCount(),8);for k=1:8,testCase.verifyLessThan(norm(problem.residual(result.Branch.point(k).DecisionValues,p,context)),1e-8);end
        end
    end
end
