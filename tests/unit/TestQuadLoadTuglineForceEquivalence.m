classdef TestQuadLoadTuglineForceEquivalence < matlab.unittest.TestCase
    methods (Test)
        function unilateralTuglineTraceMatchesCapturedSource(testCase)
            fixture=loadFixture();expected=fixture.Entries(2);tolerance=fixture.Tolerances;
            dataset=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default().load( ...
                'individual_1_tr_to_rl');
            actual=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
                dataset.XAccum,lmz.api.RunContext.synchronous(505),false);
            testCase.verifyEqual(actual.LegacyTuglineForce,expected.TuglineForce, ...
                'AbsTol',tolerance.TuglineAbsolute);
            testCase.verifyGreaterThanOrEqual(min(actual.TuglineForce),0);
            publicResult=lmzmodels.slip_quad_load.MultiStrideSimulator().run( ...
                dataset.XAccum,lmz.api.RunContext.synchronous(506),struct());
            testCase.verifyEqual(publicResult.Observables.tugline_force,actual.TuglineForce, ...
                'AbsTol',tolerance.TuglineAbsolute);
        end
    end
end
function baseline=loadFixture()
loaded=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
    'slip_quad_load','source_baselines.mat'),'baseline');baseline=loaded.baseline;
end
