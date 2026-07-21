classdef TestTimingOnlyNoPeriodicityResidual < matlab.unittest.TestCase
    methods (Test)
        function exposesOnlyContactAndSectionBlocks(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'section_return_timing',struct());
            evaluation=problem.evaluate(problem.getDecisionSchema().defaults(),[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual({evaluation.ResidualBlocks.Name}, ...
                {'contact_constraints','section_return'});
            testCase.verifyFalse(evaluation.Diagnostics.HiddenPeriodicityResidual);
        end
    end
end
