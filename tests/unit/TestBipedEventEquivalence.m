classdef TestBipedEventEquivalence < matlab.unittest.TestCase
    methods (Test)
        function eventStatesAndTouchdownResetsMatch(testCase)
            data=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
                'slip_biped','source_equivalence.mat'),'baseline');baseline=data.baseline;
            expected=baseline.Entries(4);problem=lmzmodels.slip_biped.Model().createProblem( ...
                'periodic_apex',struct());raw=problem.Evaluator.evaluate(expected.Decision, ...
                expected.Offsets,lmz.api.RunContext.synchronous(72),problem.FixedConfiguration);
            testCase.verifyEqual(raw.EventStates,expected.EventStates, ...
                'AbsTol',baseline.Tolerances.EventAbsolute);
            testCase.verifyEqual({raw.EventRecords.Name},{'L_TD','L_LO','R_TD','R_LO','APEX'});
            testCase.verifyNotEqual(raw.EventRecords(1).PreState(6),raw.EventRecords(1).PostState(6));
            testCase.verifyNotEqual(raw.EventRecords(3).PreState(8),raw.EventRecords(3).PostState(8));
        end
    end
end
