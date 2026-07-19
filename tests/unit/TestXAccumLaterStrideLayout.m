classdef TestXAccumLaterStrideLayout < matlab.unittest.TestCase
    methods (Test)
        function exactNamedThirteenEntryContract(testCase)
            expected={'tBL_TD','tBL_LO','tFL_TD','tFL_LO','tBR_TD','tBR_LO', ...
                'tFR_TD','tFR_LO','tAPEX','swing_post_BL','swing_post_FL', ...
                'swing_post_BR','swing_post_FR'};
            testCase.verifyEqual(lmzmodels.slip_quad_load.LaterStrideLayout.baseNames(),expected);
            expectedNames=cellfun(@(name)['stride2_' name],expected,'UniformOutput',false);
            testCase.verifyEqual(lmzmodels.slip_quad_load.LaterStrideLayout.names(2),expectedNames);
            secondIndices=lmzmodels.slip_quad_load.LaterStrideLayout.globalIndices(2);
            thirdIndices=lmzmodels.slip_quad_load.LaterStrideLayout.globalIndices(3);
            testCase.verifyEqual(secondIndices.Block,45:57);
            testCase.verifyEqual(secondIndices.EventTiming,45:53);
            testCase.verifyEqual(secondIndices.PostSwingStiffness,54:57);
            testCase.verifyEqual(thirdIndices.Block,58:70);
            dataset=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default().load( ...
                'individual_1_tr_to_rl');later=dataset.Decoded.LaterStrides(1);
            testCase.verifyEqual(later.StrideIndex,2);
            testCase.verifyEqual(later.Vector,dataset.XAccum(45:57));
            testCase.verifyEqual(later.EventTiming,dataset.XAccum(45:53));
            testCase.verifyEqual(later.PostSwingStiffness,dataset.XAccum(54:57));
            testCase.verifyError(@()lmzmodels.slip_quad_load.LaterStrideLayout.names(1), ...
                'lmz:QuadLoad:StrideIndex');
        end
    end
end
