classdef TestBipedPointMetadata < matlab.unittest.TestCase
    methods (Test)
        function preservesSourceAndClassification(testCase)
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();path=catalog.defaultBranchPath();
            branch=catalog.loadBranch(path,[],true);point=branch.point(30);record=catalog.record(path);
            testCase.verifyEqual(numel(point.DecisionValues),12);
            testCase.verifyEqual(numel(point.ParameterValues),2);
            testCase.verifyEqual(point.Provenance.PointSource.ColumnIndex,30);
            testCase.verifyEqual(point.Provenance.PointSource.SHA256,record.sha256);
            testCase.verifyEqual(point.Classification.Code,0);
            asymmetric=catalog.loadBranch('AR1.mat',[],true).point(50);
            testCase.verifyEqual(asymmetric.Classification.Name,'asymmetric running');
            testCase.verifyEqual(asymmetric.Classification.Code,3);
        end
    end
end
