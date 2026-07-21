classdef TestShootingNodeAndSegment < matlab.unittest.TestCase
    methods (Test)
        function recordsRoundTripWithoutExecutableState(testCase)
            [~,horizon]=lmztest.makeAnalyticShootingProblem(2);
            restored=lmz.shooting.ShootingHorizon.fromStruct( ...
                horizon.toStruct());
            testCase.verifyEqual(restored.toStruct(),horizon.toStruct());
            testCase.verifyEqual(restored.nodeCount(),3);
            testCase.verifyEqual(restored.segmentCount(),2);
            testCase.verifyEqual(restored.Segments{1}.ControlParameters, ...
                struct('Gain',0.5,'Offset',1));
        end
    end
end
