classdef TestBipedContactTimingEquivalence < matlab.unittest.TestCase
    methods (Test)
        function solvesPreservedFiveRows(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_biped').createProblem( ...
                'section_return_timing',struct());
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(905));
            testCase.verifyEqual(numel(result.ContactResiduals),4);
            testCase.verifyLessThan(norm([result.ContactResiduals; ...
                result.SectionResidual]),1e-9);
        end
    end
end
