classdef TestAdvancedControllerWorkflows < matlab.unittest.TestCase
    methods (Test)
        function branchSolveContinueOptimize(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');testCase.verifyEqual(controller.State.Datasets{1}.Branch.pointCount(),891);solved=controller.solveWorkingSolution(struct());testCase.verifyLessThan(solved.Evaluation.ScaledResidualNorm,1e-7);pair=controller.makeAdjacentSeedPair(1,struct());continued=controller.runContinuation(struct('MaximumPoints',3,'BothDirections',false,'InitialStep',pair.AchievedRadius));testCase.verifyEqual(continued.Branch.pointCount(),3);
            controller.selectModel('slip_quad_load');model=controller.Registry.createModel('slip_quad_load');problem=model.createProblem('multi_stride_fit',struct());seed=problem.makeSolution(problem.getDecisionSchema().defaults(),[],[]);[initial,~,~]=problem.evaluateObjective(seed.DecisionValues,seed.ParameterValues,lmz.api.RunContext.synchronous(0));options=struct('Algorithm','sqp','MaxIterations',1,'MaxFunctionEvaluations',30,'OptimalityTolerance',1e-5,'StepTolerance',1e-5);optimized=controller.runOptimization(options);testCase.verifyLessThan(optimized.Objective,initial);testCase.verifyEqual(numel(optimized.Output.freeVariableIndices),4);
        end
    end
end
