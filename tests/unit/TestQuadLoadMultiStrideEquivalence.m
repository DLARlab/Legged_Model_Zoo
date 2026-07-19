classdef TestQuadLoadMultiStrideEquivalence < matlab.unittest.TestCase
    methods (Test)
        function stitchedTrajectoryAndParametersMatchCapturedSource(testCase)
            fixture=loadFixture();expected=fixture.Entries(2);tolerance=fixture.Tolerances;
            dataset=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default().load( ...
                'individual_1_tr_to_rl');
            actual=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
                dataset.XAccum,lmz.api.RunContext.synchronous(502),false);
            testCase.verifyEqual(actual.StrideCount,2);
            testCase.verifyEqual(numel(actual.Residual),54);
            testCase.verifyEqual(actual.Residual,expected.Residual, ...
                'AbsTol',tolerance.ResidualAbsolute);
            testCase.verifyEqual(actual.LegacyTime,expected.Time, ...
                'AbsTol',tolerance.TimeAbsolute);
            testCase.verifyEqual(actual.LegacyStates,expected.States, ...
                'AbsTol',tolerance.StateAbsolute,'RelTol',tolerance.StateRelative);
            testCase.verifyEqual(actual.Parameters,expected.Parameters, ...
                'AbsTol',tolerance.ParameterAbsolute);
            testCase.verifyEqual(actual.XAccumTrue,expected.XAccumTrue, ...
                'AbsTol',tolerance.ParameterAbsolute);
        end
    end
end
function baseline=loadFixture()
loaded=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
    'slip_quad_load','source_baselines.mat'),'baseline');baseline=loaded.baseline;
end
