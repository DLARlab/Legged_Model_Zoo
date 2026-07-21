classdef TestLoadStrideBoundaryTiming < matlab.unittest.TestCase
    methods (Test)
        function apexToBoundaryTimingSolveConvergesOnDirectEightByEightSystem(testCase)
            context=lmz.api.RunContext.synchronous(1172);
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('slip_quad_load');
            problem=model.createProblem('section_return_timing',struct( ...
                'StartSectionId','apex','StopSectionId','stride_boundary', ...
                'FixReturnTime',true, ...
                'FixedRowPolicy','validate_fixed_rows'));
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.InputSchedule,struct('Display','off', ...
                'ResidualTolerance',1e-8),context);
            rank=result.SolverDiagnostics.RankDiagnostics;
            diagnostics=result.SolverDiagnostics;
            provider=problem.evaluate( ...
                problem.getDecisionSchema().defaults(),[],context,false). ...
                Diagnostics.ProviderDiagnostics;
            testCase.verifyEqual([rank.M rank.N],[8 8]);
            testCase.verifyEqual(rank.Rank,8);
            testCase.verifyEqual(rank.Nullity,0);
            testCase.verifyLessThan(norm(result.ContactResiduals),1e-8);
            testCase.verifyEmpty(result.SectionResidual);
            testCase.verifyTrue(diagnostics.Success);
            testCase.verifyEqual(diagnostics.Status,'converged');
            testCase.verifyEqual(provider.StartSectionId,'apex');
            testCase.verifyEqual(provider.StopSectionId,'stride_boundary');
            testCase.verifyTrue(provider.DirectSectionIntegration);
            testCase.verifyFalse(provider.AdapterDiagnostics. ...
                FullApexTrajectoryLookupDuringEvaluation);
            testCase.verifyTrue(diagnostics.Feasibility. ...
                SectionCrossingAccepted);
        end
    end
end
