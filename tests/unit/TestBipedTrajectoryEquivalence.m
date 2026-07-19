classdef TestBipedTrajectoryEquivalence < matlab.unittest.TestCase
    methods (Test)
        function rawAndPublicTrajectoriesMatch(testCase)
            data=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
                'slip_biped','source_equivalence.mat'),'baseline');baseline=data.baseline;
            expected=baseline.Entries(1);problem=lmzmodels.slip_biped.Model().createProblem( ...
                'periodic_apex',struct());context=lmz.api.RunContext.synchronous(71);
            raw=problem.Evaluator.evaluate(expected.Decision,expected.Offsets,context,problem.FixedConfiguration);
            testCase.verifyEqual(raw.LegacyTime,expected.Time,'AbsTol',baseline.Tolerances.TimeAbsolute);
            testCase.verifyEqual(raw.LegacyStates,expected.States, ...
                'AbsTol',baseline.Tolerances.StateAbsolute,'RelTol',baseline.Tolerances.StateRelative);
            evaluation=problem.evaluate(expected.Decision,expected.Offsets,context,true);
            testCase.verifyGreaterThan(min(diff(evaluation.Simulation.Time)),0);
            testCase.verifySize(evaluation.Simulation.States,[numel(evaluation.Simulation.Time) 8]);
            testCase.verifyEqual(evaluation.Diagnostics.HiddenEventTimeSolve,false);
            testCase.verifyEqual(evaluation.Diagnostics.DuplicateSamplesRemoved,6);
        end
    end
end
