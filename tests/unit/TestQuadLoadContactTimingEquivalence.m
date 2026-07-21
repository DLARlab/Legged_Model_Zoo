classdef TestQuadLoadContactTimingEquivalence < matlab.unittest.TestCase
    methods (Test)
        function solvesPreservedNineRowsWithoutNestedSolve(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quad_load').createProblem( ...
                'section_return_timing',struct());
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(906));
            testCase.verifyEqual(numel(result.ContactResiduals),8);
            testCase.verifyLessThan(norm([result.ContactResiduals; ...
                result.SectionResidual]),1e-9);
            testCase.verifyTrue(result.SolverDiagnostics.NoPeriodicityResidual);
        end
    end
end
