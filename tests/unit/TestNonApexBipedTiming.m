classdef TestNonApexBipedTiming < matlab.unittest.TestCase
    methods (Test)
        function touchdownReturnConvergesWithReturnBoundEndpoint(testCase)
            model=lmz.registry.ModelRegistry.discover(). ...
                createModel('slip_biped');
            problem=model.createProblem('section_return_timing', ...
                localConfiguration('left_touchdown'));
            context=lmz.api.RunContext.synchronous(1180);
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.InputSchedule,struct('Display','off', ...
                'ResidualTolerance',1e-9),context);
            rank=result.SolverDiagnostics.RankDiagnostics;
            evaluation=problem.evaluate( ...
                problem.decisionFromSchedule(result.SolvedSchedule),[], ...
                context,false);
            bindings=evaluation.Diagnostics.ContactRowBindings;
            testCase.verifyTrue(result.SolverDiagnostics.Success);
            testCase.verifyEqual(result.SolverDiagnostics.Status,'converged');
            testCase.verifyEqual([rank.M rank.N rank.Rank rank.Nullity], ...
                [4 4 4 0]);
            testCase.verifyLessThan(norm(result.ContactResiduals),1e-9);
            testCase.verifyTrue(result.SolverDiagnostics.Feasibility.Valid);
            testCase.verifyEqual(problem.InputSchedule.count(),3);
            testCase.verifyEqual(sum(strcmp({bindings.Kind},'return')),1);
            testCase.verifyTrue(evaluation.Diagnostics. ...
                ProviderDiagnostics.DirectSectionIntegration);
        end
    end
end

function value=localConfiguration(sectionId)
value=struct('StartSectionId',sectionId,'StopSectionId',sectionId, ...
    'SymmetryId','planar_translation');
end
