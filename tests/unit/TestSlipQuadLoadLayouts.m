classdef TestSlipQuadLoadLayouts < matlab.unittest.TestCase
    methods (Test)
        function exactFirstAndLaterContracts(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            single=catalog.load('individual_1_tr_single');transition=catalog.load('individual_1_tr_to_rl');
            testCase.verifyEqual(numel(lmzmodels.slip_quad_load.FirstStrideLayout.names()),44);
            testCase.verifyEqual(lmzmodels.slip_quad_load.LaterStrideLayout.baseNames(), ...
                {'tBL_TD','tBL_LO','tFL_TD','tFL_LO','tBR_TD','tBR_LO','tFR_TD','tFR_LO','tAPEX', ...
                'swing_post_BL','swing_post_FL','swing_post_BR','swing_post_FR'});
            testCase.verifyEqual(single.StrideCount,1);testCase.verifyEqual(transition.StrideCount,2);
            testCase.verifyEqual(single.Decoded.Schema.count(),44);testCase.verifyEqual(transition.Decoded.Schema.count(),57);
            testCase.verifyEqual(transition.Decoded.LaterStrides(1).EventTiming,transition.XAccum(45:53));
            testCase.verifyEqual(transition.Decoded.LaterStrides(1).PostSwingStiffness,transition.XAccum(54:57));
            testCase.verifyEqual(lmzmodels.slip_quad_load.XAccumAdapter.encode(single.Decoded),single.XAccum);
            testCase.verifyEqual(lmzmodels.slip_quad_load.XAccumAdapter.encode(transition.Decoded),transition.XAccum);
            testCase.verifyError(@()lmzmodels.slip_quad_load.XAccumAdapter.decode(zeros(45,1)),'lmz:QuadLoad:XAccumLength');
        end
        function manifestHashesAndNativeArtifacts(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();records=catalog.records();
            testCase.verifyEqual(numel(records),2);
            for index=1:numel(records)
                testCase.verifyTrue(catalog.validateHash(records(index).id));
                testCase.verifyEqual(exist(catalog.nativePath(records(index).id),'file'),2);
                artifact=lmz.io.ArtifactStore.load(catalog.nativePath(records(index).id));
                testCase.verifyEqual(artifact.modelId,'slip_quad_load');
                testCase.verifyEqual(numel(artifact.decisionValues),records(index).xAccumLength);
            end
        end
    end
end
