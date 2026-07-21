classdef TestTimingOnlyFixedState < matlab.unittest.TestCase
    methods (Test)
        function tutorialStateIsBitwiseFixed(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'section_return_timing',struct());before=problem.FixedInitialState;
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(901));
            testCase.verifyTrue(isequaln(before,result.FixedInitialState));
            testCase.verifyTrue(result.SolverDiagnostics.InitialStateBitwiseUnchanged);
        end
    end
end
