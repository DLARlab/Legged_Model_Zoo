classdef TestLoadingForceTermEquivalence < matlab.unittest.TestCase
    methods (Test)
        function sourceResamplingAndNormMatchCapturedObjective(testCase)
            [dataset,raw,expected,tolerance]=caseData(509);
            term=lmzmodels.slip_quad_load.ObjectiveTerms.LoadingForceMismatch.evaluate( ...
                raw,dataset.Experimental.loading_force_exp,dataset.TermWeights.loadingforce);
            testCase.verifyEqual(term.Name,'loading_force');
            testCase.verifyEqual(term.Weight,dataset.TermWeights.loadingforce);
            testCase.verifyEqual(term.Value,expected.ObjectiveTerms.loadingforce, ...
                'AbsTol',tolerance.ObjectiveAbsolute);
            testCase.verifyEqual(numel(term.Diagnostics.Methods),dataset.StrideCount);
            testCase.verifySize(term.Source,size(term.Target));
            testCase.verifyTrue(all(ismember(term.Diagnostics.Methods, ...
                {'constant','spline','makima'})));
        end
    end
end
function [dataset,raw,expected,tolerance]=caseData(seed)
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset=catalog.load('individual_1_tr_to_rl');
raw=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
    dataset.XAccum,lmz.api.RunContext.synchronous(seed),true);
loaded=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
    'slip_quad_load','source_baselines.mat'),'baseline');
expected=loaded.baseline.Entries(2);tolerance=loaded.baseline.Tolerances;
end
