classdef TestTimingOnlyFixedParameters < matlab.unittest.TestCase
    methods (Test)
        function tutorialPhysicsIsBitwiseFixed(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'section_return_timing',struct());before=problem.FixedPhysicalParameters;
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(902));
            testCase.verifyTrue(isequaln(before,result.FixedPhysicalParameters));
            testCase.verifyTrue(result.SolverDiagnostics.PhysicalParametersBitwiseUnchanged);
        end
    end
end
