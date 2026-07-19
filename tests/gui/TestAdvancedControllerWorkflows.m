classdef TestAdvancedControllerWorkflows < matlab.unittest.TestCase
    methods (Test)
        function branchSolveContinueOptimize(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');testCase.verifyEqual(controller.State.Datasets{1}.Branch.pointCount(),891);solved=controller.solveWorkingSolution(struct());testCase.verifyLessThan(solved.Evaluation.ScaledResidualNorm,1e-7);pair=controller.makeAdjacentSeedPair(1,struct());continued=controller.runContinuation(struct('MaximumPoints',3,'BothDirections',false,'InitialStep',pair.AchievedRadius));testCase.verifyEqual(continued.Branch.pointCount(),3);
            controller.selectModel('slip_quad_load');optimized=controller.runOptimization(struct());testCase.verifyLessThan(optimized.Objective,1e-10);
        end
    end
end
