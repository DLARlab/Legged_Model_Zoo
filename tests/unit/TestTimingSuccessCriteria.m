classdef TestTimingSuccessCriteria < matlab.unittest.TestCase
    methods (Test)
        function rejectedCrossingOverridesSmallResidual(testCase)
            problem=lmztest.makeRectangularTimingProblem( ...
                'rejected_crossing',.4,false,1,false,struct());
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.InputSchedule,struct(), ...
                lmz.api.RunContext.synchronous(1012));
            testCase.verifyLessThan(result.SolverDiagnostics.ResidualNorm,1e-10);
            testCase.verifyFalse(result.SolverDiagnostics.Success);
            testCase.verifyFalse(result.SolverDiagnostics. ...
                SuccessCriteria.SectionCrossingAccepted);
            testCase.verifyEqual(result.SolverDiagnostics.Status,'infeasible');
        end
    end
end
