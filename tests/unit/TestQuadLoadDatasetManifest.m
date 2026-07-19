classdef TestQuadLoadDatasetManifest < matlab.unittest.TestCase
    methods (Test)
        function repositoryContainedDatasetsAreCatalogedAndVerified(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            manifest=catalog.Manifest;records=catalog.records();
            testCase.verifyEqual(manifest.modelId,'slip_quad_load');
            testCase.verifyEqual(manifest.sourceCommit, ...
                '19f3133073c988cc0c3424a647b4adbb60a90b99');
            testCase.verifyEqual(numel(records),2);
            testCase.verifyEqual({records.id}, ...
                {'individual_1_tr_single','individual_1_tr_to_rl'});
            testCase.verifyEqual([records.strideCount],[1 2]);
            testCase.verifyEqual([records.xAccumLength],[44 57]);
            for index=1:numel(records)
                record=records(index);
                testCase.verifyTrue(catalog.validateHash(record.id));
                testCase.verifyEqual(exist(catalog.pathFor(record.id),'file'),2);
                testCase.verifyEqual(exist(catalog.nativePath(record.id),'file'),2);
                dataset=catalog.load(record.id);
                testCase.verifyEqual(dataset.StrideCount,record.strideCount);
                testCase.verifyEqual(numel(dataset.XAccum),record.xAccumLength);
                artifact=lmz.io.ArtifactStore.load(catalog.nativePath(record.id));
                testCase.verifyEqual(artifact.modelId,'slip_quad_load');
                testCase.verifyEqual(numel(artifact.decisionValues),record.xAccumLength);
            end
        end
    end
end
