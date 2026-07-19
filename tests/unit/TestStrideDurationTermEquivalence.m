classdef TestStrideDurationTermEquivalence < matlab.unittest.TestCase
    methods (Test)
        function termMatchesCapturedSourceObjective(testCase)
            [dataset,raw,expected,tolerance]=caseData(507);
            term=lmzmodels.slip_quad_load.ObjectiveTerms.StrideDurationMismatch.evaluate( ...
                raw.Parameters,dataset.Experimental.t_exp,dataset.TermWeights.strideduration);
            testCase.verifyEqual(term.Name,'stride_duration');
            testCase.verifyEqual(term.Weight,dataset.TermWeights.strideduration);
            testCase.verifyEqual(term.Value,expected.ObjectiveTerms.strideduration, ...
                'AbsTol',tolerance.ObjectiveAbsolute);
            testCase.verifyEqual(numel(term.Diagnostics.PerSourceLength),dataset.StrideCount);
            testCase.verifySize(term.Source,size(term.Target));
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
