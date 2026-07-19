classdef TestBipedContinuation < matlab.unittest.TestCase
    methods (Test)
        function adjacentScientificContinuationExecutes(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch([],problem,true);
            index=catalog.Manifest.defaultSeedIndex;context=lmz.api.RunContext.synchronous(75);
            pair=lmz.services.SeedService().adjacentBranchPair(problem,branch,index,1,struct(),context);
            result=lmz.services.ContinuationService().run(problem,pair,struct( ...
                'MaximumPoints',3,'BothDirections',false,'InitialStep',pair.AchievedRadius, ...
                'MaximumStep',pair.AchievedRadius),context);
            testCase.verifyEqual(result.Branch.pointCount(),3);
            testCase.verifyEqual(result.TerminationReason,'maximum_points');
        end
    end
end
