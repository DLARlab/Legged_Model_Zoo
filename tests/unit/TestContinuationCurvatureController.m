classdef TestContinuationCurvatureController < matlab.unittest.TestCase
    methods (Test)
        function thresholdResponseShrinksNextStep(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(731);
            result=lmz.services.ContinuationService().run(problem,pair, ...
                struct('MaximumPoints',4,'BothDirections',false, ...
                'InitialStep',0.08,'MinimumStep',0.005,'MaximumStep',0.08, ...
                'CurvatureThreshold',-1,'ShrinkFactor',0.5),context);
            accepted=result.Snapshots([result.Snapshots.Accepted]);
            testCase.verifyEqual(accepted(3).StepSize,0.08,'AbsTol',1e-12);
            testCase.verifyEqual(accepted(4).StepSize,0.04,'AbsTol',1e-12);
            testCase.verifyEqual(accepted(3).Diagnostics.Curvature,0, ...
                'AbsTol',1e-12);
        end
    end
end
