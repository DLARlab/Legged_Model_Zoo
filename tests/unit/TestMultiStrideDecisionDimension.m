classdef TestMultiStrideDecisionDimension < matlab.unittest.TestCase
    methods (Test)
        function dimensionIsFortyFourPlusThirteenPerLaterStride(testCase)
            for count=1:5
                expected=44+13*(count-1);
                testCase.verifyEqual( ...
                    lmzmodels.slip_quad_load.MultiStrideDecisionSchema.expectedLength(count),expected);
                schema=lmzmodels.slip_quad_load.MultiStrideDecisionSchema.create(count,zeros(expected,1));
                testCase.verifyEqual(schema.count(),expected);
                testCase.verifyEqual( ...
                    lmzmodels.slip_quad_load.MultiStrideDecisionSchema.strideCount(expected),count);
            end
            testCase.verifyError(@()lmzmodels.slip_quad_load.MultiStrideDecisionSchema.strideCount(58), ...
                'lmz:QuadLoad:XAccumLength');
        end
    end
end
