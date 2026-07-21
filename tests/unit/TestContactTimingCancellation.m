classdef TestContactTimingCancellation < matlab.unittest.TestCase
    methods (Test)
        function honorsCancellationBeforeSolve(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'section_return_timing',struct());
            context=lmz.api.RunContext.synchronous(907);context.Cancellation.cancel();
            testCase.verifyError(@()lmz.services.ContactTimingService().solve( ...
                problem,problem.getDecisionSchema().defaults(),struct(),context), ...
                'lmz:Cancelled');
        end
    end
end
