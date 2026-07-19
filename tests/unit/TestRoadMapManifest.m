classdef TestRoadMapManifest < matlab.unittest.TestCase
    methods (Test)
        function completeManifestAndHashes(testCase)
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();records=catalog.allRecords();
            testCase.verifyEqual(catalog.Manifest.datasetId,'slip_quadruped_roadmap');
            testCase.verifyEqual(catalog.Manifest.sourceCommit,'2c106101383ecee1b2a9d695efe09fbd72d5718a');
            testCase.verifyEqual(numel(records),11);testCase.verifyEqual(numel(catalog.branchRecords()),9);
            for index=1:numel(records)
                path=fullfile(catalog.RootPath,records(index).relativePath);
                testCase.verifyEqual(lmz.util.FileHash.sha256(path),records(index).sha256);
                testCase.verifyTrue(isfield(records(index),'inferredGaitSummary'));
            end
        end
        function pkPointCountAndDefault(testCase)
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();record=catalog.record('PK_20_2.mat');
            testCase.verifyEqual(record.pointCount,891);testCase.verifyEqual(catalog.recommendedSeedIndex('PK_20_2.mat'),267);
            testCase.verifyEqual(catalog.Manifest.totalBranchPoints,3443);
        end
    end
end
