classdef TestQuadrupedContactTimingEquivalence < matlab.unittest.TestCase
    methods (Test)
        function solvesPreservedNineRows(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quadruped').createProblem( ...
                'section_return_timing',struct());
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(904));
            testCase.verifyEqual(numel(result.ContactResiduals),8);
            testCase.verifyLessThan(norm([result.ContactResiduals; ...
                result.SectionResidual]),5e-9);
        end
    end
end
