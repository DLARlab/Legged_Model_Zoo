classdef TestHorizonPartialPreservation < matlab.unittest.TestCase
    methods (Test)
        function physicalFailureDoesNotInventSegmentSimulation(testCase)
            configuration=struct('InvalidSegment',2);
            [problem,~,~,seed]=lmztest.makeAnalyticShootingProblem(3, ...
                'Configuration',configuration);
            residual=problem.evaluateShooting(seed,[], ...
                lmz.api.RunContext.synchronous(1006),true);
            testCase.verifyFalse(residual.Feasibility.Valid);
            testCase.verifyFalse(residual.Feasibility.PhysicalValidity);
            testCase.verifyEqual(numel(residual.SegmentResults),3);
            testCase.verifyEqual( ...
                residual.SegmentResults{1}.Simulation.SegmentIndex,1);
            testCase.verifyFalse( ...
                residual.SegmentResults{2}.PhysicalValidity);
            testCase.verifyEqual( ...
                residual.Diagnostics.SegmentEvaluationCount,3);
        end
    end
end
