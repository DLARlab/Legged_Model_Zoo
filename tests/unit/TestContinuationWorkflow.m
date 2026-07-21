classdef TestContinuationWorkflow < matlab.unittest.TestCase
    methods (Test)
        function secondSeedAndBranch(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch(catalog.defaultBranchPath(),problem);source=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));p=source.ParameterValues;first=problem.makeSolution(source.DecisionValues,p,problem.evaluate(source.DecisionValues,p,lmz.api.RunContext.synchronous(0),false));context=lmz.api.RunContext.synchronous(4);
            pair=lmz.services.SeedService().makeSecondSeed(problem,first,0.03,struct(),context);testCase.verifyEqual(pair.AchievedRadius,0.03,'AbsTol',2e-5);
            result=lmz.services.ContinuationService().run(problem,pair,struct('MaximumPoints',8,'BothDirections',false),context);testCase.verifyEqual(result.Branch.pointCount(),8);for k=1:8,testCase.verifyLessThan(norm(problem.residual(result.Branch.point(k).DecisionValues,p,context)),1e-8);end
        end

        function oneByTwoJacobianRetainsNullDirection(testCase)
            problem=lmztest.AnalyticModel().createProblem('line',struct());
            context=lmz.api.RunContext.synchronous(81);
            decision=problem.getDecisionSchema().defaults();
            first=problem.makeSolution(decision,[], ...
                problem.evaluate(decision,[],context,false));
            pair=lmz.services.SeedService().makeSecondSeed( ...
                problem,first,0.01,struct(),context);
            testCase.verifyEqual(pair.Diagnostics.LocalDimension,1);
            testCase.verifyEqual(pair.Diagnostics.JacobianRank,1);
            testCase.verifyEqual(pair.AchievedRadius,0.01,'AbsTol',1e-5);
        end
    end
end
