classdef TestQuadLoadSingleStrideEquivalence < matlab.unittest.TestCase
    methods (Test)
        function residualTimeAndStatesMatchCapturedSource(testCase)
            fixture=loadFixture();expected=fixture.Entries(1);tolerance=fixture.Tolerances;
            dataset=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default().load( ...
                'individual_1_tr_single');
            actual=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
                dataset.XAccum,lmz.api.RunContext.synchronous(501),false);
            testCase.verifyEqual(actual.StrideCount,1);
            testCase.verifyEqual(numel(actual.Residual),27);
            testCase.verifyEqual(actual.Residual,expected.Residual, ...
                'AbsTol',tolerance.ResidualAbsolute);
            testCase.verifyEqual(actual.LegacyTime,expected.Time, ...
                'AbsTol',tolerance.TimeAbsolute);
            testCase.verifyEqual(actual.LegacyStates,expected.States, ...
                'AbsTol',tolerance.StateAbsolute,'RelTol',tolerance.StateRelative);
            testCase.verifyEqual(actual.Parameters,expected.Parameters, ...
                'AbsTol',tolerance.ParameterAbsolute);
        end
    end
end
function baseline=loadFixture()
loaded=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
    'slip_quad_load','source_baselines.mat'),'baseline');baseline=loaded.baseline;
end
