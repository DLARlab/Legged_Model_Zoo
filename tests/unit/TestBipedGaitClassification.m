classdef TestBipedGaitClassification < matlab.unittest.TestCase
    methods (Test)
        function sourceCodesAndBranchSubtypeMatch(testCase)
            data=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
                'slip_biped','source_equivalence.mat'),'baseline');entries=data.baseline.Entries;
            expected=[0 3 1 2 2 3];actual=zeros(size(expected));
            for index=1:numel(entries)
                actual(index)=lmzmodels.slip_biped.GaitClassifier.classify(entries(index).Decision).Code;
            end
            testCase.verifyEqual(actual,expected);
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            testCase.verifyEqual(catalog.loadBranch('AR1.mat',[],true).point(50).Classification.Abbreviation,'AR');
        end
    end
end
