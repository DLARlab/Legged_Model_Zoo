classdef TestFootfallTimingTermEquivalence < matlab.unittest.TestCase
    methods (Test)
        function termMatchesCapturedSourceObjective(testCase)
            [dataset,raw,expected,tolerance]=caseData(508);
            term=lmzmodels.slip_quad_load.ObjectiveTerms.FootfallTimingMismatch.evaluate( ...
                raw.Parameters,dataset.Experimental.ft_exp,dataset.TermWeights.ft);
            testCase.verifyEqual(term.Name,'footfall_timing');
            testCase.verifyEqual(term.Weight,dataset.TermWeights.ft);
            testCase.verifyEqual(term.Value,expected.ObjectiveTerms.ft, ...
                'AbsTol',tolerance.ObjectiveAbsolute);
            testCase.verifyEqual(term.Diagnostics.Permutation,[1 2 3 4 7 8 5 6]);
            testCase.verifyTrue(term.Diagnostics.SourceLaterStrideOffsetPreserved);
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
