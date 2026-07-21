classdef TestShootingJacobianRank < matlab.unittest.TestCase
    methods (Test)
        function rankDiagnosticsMatchAnalyticSquareSystem(testCase)
            [problem,~,~,seed]=lmztest.makeAnalyticShootingProblem(2);
            diagnostics=lmz.solvers.RankAwareNonlinearSolver().analyze( ...
                problem,seed,[],struct('FiniteDifferenceStep',1e-7), ...
                lmz.api.RunContext.synchronous(1005));
            testCase.verifyEqual(diagnostics.M,3);
            testCase.verifyEqual(diagnostics.N,3);
            testCase.verifyEqual(diagnostics.Rank,3);
            testCase.verifyEqual(diagnostics.Nullity,0);
            testCase.verifySize(diagnostics.Jacobian,[3 3]);
        end
    end
end
