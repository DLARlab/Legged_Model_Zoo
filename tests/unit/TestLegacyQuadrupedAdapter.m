classdef TestLegacyQuadrupedAdapter < matlab.unittest.TestCase
    methods (Test)
        function exactRoundTrip(testCase)
            raw=reshape(1:87,29,3); branch=lmzmodels.slipquadruped.Results29Adapter.decode(raw);
            testCase.verifyEqual(lmzmodels.slipquadruped.Results29Adapter.encode(branch),raw);
        end
        function rejectsWrongRows(testCase)
            testCase.verifyError(@()lmzmodels.slipquadruped.Results29Adapter.decode(zeros(28,1)),'lmz:LegacyFormat');
        end
    end
end
