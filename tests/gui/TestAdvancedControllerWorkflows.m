classdef TestAdvancedControllerWorkflows < matlab.unittest.TestCase
    methods (Test)
        function branchSolveContinueOptimize(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');testCase.verifyEqual(controller.State.Datasets{1}.Branch.pointCount(),7);controller.selectBranchPoint(3);solved=controller.solveWorkingSolution(struct());testCase.verifyLessThan(solved.Evaluation.ScaledResidualNorm,1e-9);controller.makeSecondSeed(0.03);continued=controller.runContinuation(struct('MaximumPoints',6,'BothDirections',false));testCase.verifyEqual(continued.Branch.pointCount(),6);
            controller.selectModel('slip_quad_load');optimized=controller.runOptimization(struct());testCase.verifyLessThan(optimized.Objective,1e-10);
        end
    end
end
