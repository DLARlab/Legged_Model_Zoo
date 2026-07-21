classdef TestOverdeterminedContactTiming < matlab.unittest.TestCase
    methods (Test)
        function explicitLeastSquaresReturnsRankDiagnostics(testCase)
            problem=lmztest.makeRectangularTimingProblem( ...
                'square',.4,true,1,false,struct( ...
                'FixedRowPolicy', ...
                'include_fixed_rows_in_least_squares'));
            testCase.verifyEqual(problem.unknownDimension(),1);
            testCase.verifyEqual(problem.residualDimension(),2);
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.InputSchedule,struct('Solver','lsqnonlin'), ...
                lmz.api.RunContext.synchronous(1001));
            rank=result.SolverDiagnostics.RankDiagnostics;
            testCase.verifyTrue(result.SolverDiagnostics.Success);
            testCase.verifyEqual(rank.SolverSelected,'lsqnonlin');
            testCase.verifyEqual([rank.M rank.N rank.Rank rank.Nullity], ...
                [2 1 1 0]);
            testCase.verifySize(rank.SingularValues,[1 1]);
            testCase.verifyTrue(isfinite(rank.ConditionEstimate));
            testCase.verifyLessThan(rank.FirstOrderOptimality,1e-9);
            testCase.verifyEqual(result.ContactResiduals,0,'AbsTol',1e-12);
        end

        function boundReturnRowNeedNotBeAnInteriorEvent(testCase)
            problem=lmztest.makeRectangularTimingProblem( ...
                'bound_endpoint',.4,true,1.1,false,struct());
            testCase.verifyEqual(problem.InputSchedule.count(),1);
            testCase.verifyEqual(problem.unknownDimension(),1);
            testCase.verifyEqual(problem.residualDimension(),1);
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.InputSchedule,struct(), ...
                lmz.api.RunContext.synchronous(1013));
            testCase.verifyTrue(result.SolverDiagnostics.Success);
            testCase.verifyEqual(numel(result.ContactResiduals),2);
            testCase.verifyLessThan(norm(result.ContactResiduals),1e-9);
            bindings=result.SolverDiagnostics.Feasibility;
            testCase.verifyTrue(bindings.FixedRowsValid);
        end
    end
end
