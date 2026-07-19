classdef TestSlipQuadLoadScientificEquivalence < matlab.unittest.TestCase
    methods (Test)
        function sourceSimulationAndObjective(testCase)
            fixture=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
                'slip_quad_load','source_baselines.mat'),'baseline');baseline=fixture.baseline;
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();simulator=lmzmodels.slip_quad_load.MultiStrideSimulator();
            ids={'individual_1_tr_single','individual_1_tr_to_rl'};
            for index=1:numel(baseline.Entries)
                expected=baseline.Entries(index);dataset=catalog.load(ids{index});context=lmz.api.RunContext.synchronous(80+index);
                actual=simulator.runRaw(dataset.XAccum,context,false);t=baseline.Tolerances;
                testCase.verifyEqual(actual.StrideCount,expected.StrideCount);
                testCase.verifyEqual(actual.Residual,expected.Residual,'AbsTol',t.ResidualAbsolute);
                testCase.verifyEqual(actual.LegacyTime,expected.Time,'AbsTol',t.TimeAbsolute);
                testCase.verifyEqual(actual.LegacyStates,expected.States,'AbsTol',t.StateAbsolute,'RelTol',t.StateRelative);
                testCase.verifyEqual(actual.LegacyGroundReactionForces,expected.GroundReactionForces,'AbsTol',t.GRFAbsolute,'RelTol',t.GRFRelative);
                testCase.verifyEqual(actual.LegacyTuglineForce,expected.TuglineForce,'AbsTol',t.TuglineAbsolute);
                testCase.verifyEqual(actual.Parameters,expected.Parameters,'AbsTol',t.ParameterAbsolute);
                testCase.verifyEqual(actual.EventStates,expected.EventStates,'AbsTol',t.StateAbsolute,'RelTol',t.StateRelative);
                testCase.verifyEqual(actual.XAccumTrue,expected.XAccumTrue,'AbsTol',t.ParameterAbsolute);
                problem=lmzmodels.slip_quad_load.MultiStrideFitProblem(lmzmodels.slip_quad_load.Model(), ...
                    struct('DatasetPath',dataset.Path,'InitialPerturbation',0));
                [objective,terms,diagnostics]=problem.evaluateObjective(dataset.XAccum, ...
                    problem.getParameterSchema().defaults(),lmz.api.RunContext.synchronous(90+index));
                testCase.verifyEqual(objective,expected.Objective,'AbsTol',t.ObjectiveAbsolute);
                testCase.verifyEqual(terms.StrideDuration.Value,expected.ObjectiveTerms.strideduration,'AbsTol',t.ObjectiveAbsolute);
                testCase.verifyEqual(terms.FootfallTiming.Value,expected.ObjectiveTerms.ft,'AbsTol',t.ObjectiveAbsolute);
                testCase.verifyEqual(terms.LoadingForce.Value,expected.ObjectiveTerms.loadingforce,'AbsTol',t.ObjectiveAbsolute);
                testCase.verifyEqual(diagnostics.R2.strideduration,expected.R2.strideduration,'AbsTol',t.R2Absolute);
                testCase.verifyEqual(diagnostics.R2.footfalltiming,expected.R2.footfalltiming,'AbsTol',t.R2Absolute);
                testCase.verifyEqual(diagnostics.R2.loadingforce,expected.R2.loadingforce,'AbsTol',t.R2Absolute);
                testCase.verifyEqual(diagnostics.R2.weighted,expected.R2.weighted,'AbsTol',t.R2Absolute);
            end
        end
        function publicSimulationContract(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();dataset=catalog.load('individual_1_tr_to_rl');
            result=lmzmodels.slip_quad_load.MultiStrideSimulator().run(dataset.XAccum,lmz.api.RunContext.synchronous(93),struct());
            testCase.verifyEqual(size(result.States,2),18);testCase.verifyEqual(size(result.GroundReactionForces,2),12);
            testCase.verifyEqual(numel(result.EventRecords),18);testCase.verifyGreaterThan(min(diff(result.Time)),0);
            testCase.verifyEqual(result.Observables.stride_count,2);testCase.verifySize(result.Observables.tugline_force,[numel(result.Time) 1]);
            testCase.verifyTrue(all(isfield(result.Modes,{'back_left','front_left','back_right','front_right','stride_index'})));
            testCase.verifyTrue(all(isfield(result.Kinematics,{'LoadPosition','RopeStart','RopeEnd','FootX','FootY'})));
        end
        function guardedR2IsFinite(testCase)
            term=struct('Source',ones(1,4),'Target',ones(1,4),'Diagnostics',struct('R2Target',ones(1,4)));
            [r2,diagnostics]=lmzmodels.slip_quad_load.ObjectiveTerms.R2Metrics.compute(term,term,term,[0 0 0]);
            testCase.verifyEqual([r2.strideduration r2.footfalltiming r2.loadingforce r2.weighted],[1 1 1 1]);
            testCase.verifyTrue(diagnostics.ZeroVarianceGuard.ZeroWeight);
        end
    end
end
