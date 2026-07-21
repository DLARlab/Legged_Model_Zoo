classdef TestInitialRootSuppression < matlab.unittest.TestCase
    methods (Test)
        function tutorialApexReturnDoesNotStopAtInitialRoot(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('periodic_hop',struct());
            context=lmz.api.RunContext.synchronous(929);
            u=problem.getDecisionSchema().defaults();
            p=problem.getParameterSchema().defaults();
            evaluation=problem.evaluate(u,p,context,true);
            source=problem.makeSolution(u,p,evaluation);
            returned=lmz.services.PoincareReturnService().simulate( ...
                model,source,struct('StartSectionId','apex', ...
                'StopSectionId','apex'),context);

            testCase.verifyGreaterThan(returned.ReturnTime,0.1);
            testCase.verifyGreaterThan(returned.StopCrossing.Time,0.1);
            testCase.verifyTrue( ...
                returned.Diagnostics.InitialRootSuppressed);
            testCase.verifyEqual(returned.StartCrossing.Time,0);
        end
    end
end
