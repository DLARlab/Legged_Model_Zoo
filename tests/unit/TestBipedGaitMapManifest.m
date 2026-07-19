classdef TestBipedGaitMapManifest < matlab.unittest.TestCase
    methods (Test)
        function completeManifestHashesAndCounts(testCase)
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();records=catalog.branchRecords();
            testCase.verifyEqual(catalog.Manifest.datasetId,'slip_biped_gaitmap');
            testCase.verifyEqual(catalog.Manifest.sourceCommit, ...
                '4595146c5881a5313bc8fe92de85099193ef9be9');
            testCase.verifyEqual(numel(records),6);testCase.verifyEqual(catalog.Manifest.totalBranchPoints,2967);
            for index=1:numel(records)
                testCase.verifyEqual(lmz.util.FileHash.sha256( ...
                    fullfile(catalog.RootPath,records(index).relativePath)),records(index).sha256);
                testCase.verifyEqual(records(index).rowCount,14);
            end
        end
    end
end
