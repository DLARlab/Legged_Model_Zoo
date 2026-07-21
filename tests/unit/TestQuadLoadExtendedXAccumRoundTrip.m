classdef TestQuadLoadExtendedXAccumRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function exactNinetySixEntryCodecClaimRemainsStructural(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            dataset=catalog.load('individual_1_tr_to_rl');
            source=dataset.XAccum;
            later=source(45:57);
            extended=[source;later;later;later];
            testCase.verifyEqual(numel(extended),96);
            decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(extended);
            encoded=lmzmodels.slip_quad_load.XAccumAdapter.encode(decoded);
            testCase.verifyEqual(decoded.StrideCount,5);
            testCase.verifyEqual(encoded,extended,'AbsTol',0);
            testCase.verifyFalse(lmzmodels.slip_quad_load. ...
                QuadLoadFeasibilityEvidence().horizonStatus(). ...
                fiveStrideRootFound);
        end
    end
end
