classdef TestQuadrupedScientificEquivalence < matlab.unittest.TestCase
    methods (Test)
        function residualTrajectoryGrfAndEvents(testCase)
            fixture=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','slip_quadruped_roadmap_baseline.mat'),'baseline');baseline=fixture.baseline;
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());context=lmz.api.RunContext.synchronous(51);
            for index=1:numel(baseline.Entries)
                expected=baseline.Entries(index);raw=problem.Evaluator.evaluate(expected.Decision,expected.Parameters,context);
                testCase.verifyEqual(raw.Residual,expected.Residual,'AbsTol',baseline.Tolerances.ResidualAbsolute);
                testCase.verifyEqual(raw.LegacyTime,expected.Time,'AbsTol',baseline.Tolerances.TimeAbsolute);
                testCase.verifyEqual(raw.LegacyStates,expected.States,'AbsTol',baseline.Tolerances.StateAbsolute,'RelTol',baseline.Tolerances.StateRelative);
                testCase.verifyEqual(raw.LegacyGroundReactionForces,expected.GroundReactionForces,'AbsTol',baseline.Tolerances.GRFAbsolute,'RelTol',baseline.Tolerances.GRFRelative);
                testCase.verifyEqual(raw.EventStates,expected.EventStates,'AbsTol',baseline.Tolerances.StateAbsolute);
                commonTime=linspace(0,min(raw.LegacyTime(end),expected.Time(end)),401).';
                [expectedTime,expectedIndices]=unique(expected.Time,'last');[actualTime,actualIndices]=unique(raw.LegacyTime,'last');
                expectedStates=interp1(expectedTime,expected.States(expectedIndices,:),commonTime,'linear');actualStates=interp1(actualTime,raw.LegacyStates(actualIndices,:),commonTime,'linear');
                expectedForces=interp1(expectedTime,expected.GroundReactionForces(expectedIndices,:),commonTime,'linear');actualForces=interp1(actualTime,raw.LegacyGroundReactionForces(actualIndices,:),commonTime,'linear');
                testCase.verifyEqual(actualStates,expectedStates,'AbsTol',baseline.Tolerances.StateAbsolute,'RelTol',baseline.Tolerances.StateRelative);
                testCase.verifyEqual(actualForces,expectedForces,'AbsTol',baseline.Tolerances.GRFAbsolute,'RelTol',baseline.Tolerances.GRFRelative);
                gait=lmzmodels.slip_quadruped.GaitClassifier.classify(expected.Decision);testCase.verifyEqual(gait.Abbreviation,expected.GaitAbbreviation);
            end
        end
        function publicSimulationContract(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());u=problem.getDecisionSchema().defaults();p=problem.getParameterSchema().defaults();evaluation=problem.evaluate(u,p,lmz.api.RunContext.synchronous(52),true);simulation=evaluation.Simulation;
            testCase.verifySize(simulation.States,[numel(simulation.Time) 14]);testCase.verifySize(simulation.GroundReactionForces,[numel(simulation.Time) 12]);testCase.verifyEqual(numel(simulation.EventRecords),9);testCase.verifyGreaterThan(min(diff(simulation.Time)),0);testCase.verifyEqual(evaluation.Diagnostics.HiddenEventTimeSolve,false);
        end
    end
end
