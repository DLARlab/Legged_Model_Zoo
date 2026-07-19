classdef TestObjectiveMetrics < matlab.unittest.TestCase
    methods(Test)
        function zeroVariance(t),[r,d]=lmz.problems.ObjectiveTerm.rSquared(ones(3,1),ones(3,1));t.verifyTrue(isnan(r));t.verifyEqual(d,'zero_variance');end
        function zeroWeights(t),[r,v]=lmz.problems.ObjectiveTerm.weightedMetric([1;2],[0;0]);t.verifyFalse(v);t.verifyTrue(isnan(r));end
    end
end
