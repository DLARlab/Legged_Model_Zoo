classdef TestBipedAllBranchesImport < matlab.unittest.TestCase
    methods (Test)
        function importsEveryNativeBranch(testCase)
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branches=catalog.loadAll([],true);
            counts=cellfun(@(x)x.pointCount(),branches);
            testCase.verifyEqual(counts,[215 1121 1015 51 73 492]);
            testCase.verifyEqual(sum(counts),2967);
            for index=1:numel(branches),testCase.verifyClass(branches{index},'lmz.data.SolutionBranch');end
        end
    end
end
