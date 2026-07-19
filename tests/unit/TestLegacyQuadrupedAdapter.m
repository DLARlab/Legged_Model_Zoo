classdef TestLegacyQuadrupedAdapter < matlab.unittest.TestCase
    methods (Test)
        function exactRoundTrip(testCase)
            raw=reshape(1:87,29,3); branch=lmzmodels.slip_quadruped.Results29Adapter.decode(raw);
            testCase.verifyEqual(lmzmodels.slip_quadruped.Results29Adapter.encode(branch),raw);
            testCase.verifyEqual(branch.modelId,'slip_quadruped');
        end
        function rejectsWrongRows(testCase)
            testCase.verifyError(@()lmzmodels.slip_quadruped.Results29Adapter.decode(zeros(28,1)), ...
                'lmz:slip_quadruped:LegacyFormat');
        end
    end
end
