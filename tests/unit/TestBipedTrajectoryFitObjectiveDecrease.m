classdef TestBipedTrajectoryFitObjectiveDecrease < matlab.unittest.TestCase
    methods (Test)
        function shortGenericFitDecreasesPenalizedObjective(testCase)
            model=lmzmodels.slip_biped.Model();
            problem=model.createProblem('trajectory_fit',struct('EnforceConstraints',false));
            context=lmz.api.RunContext.synchronous(78);initial=problem.sourceSeed();
            initial(1)=initial(1)+0.05;initial(4)=initial(4)+0.01;
            parameters=problem.getParameterSchema().defaults();
            [initialObjective,~,initialDiagnostics]=problem.evaluateObjective(initial,parameters,context);
            seed=problem.makeSolution(initial,parameters,[]);
            warningState=warning('off','MATLAB:ode45:IntegrationTolNotMet');
            cleanup=onCleanup(@()warning(warningState));
            result=lmz.optimization.FminconSolver().solve(problem,seed,parameters,struct( ...
                'Algorithm','sqp','MaxIterations',3,'MaxFunctionEvaluations',150, ...
                'ConstraintTolerance',0.2,'OptimalityTolerance',1e-3, ...
                'StepTolerance',1e-3),context);
            testCase.verifyLessThan(result.Objective,initialObjective);
            [~,~,finalDiagnostics]=problem.evaluateObjective( ...
                result.Solution.DecisionValues,parameters,context);
            testCase.verifyLessThan(norm(finalDiagnostics.ConstraintResidual),0.2);
            testCase.verifyLessThan(norm(initialDiagnostics.ConstraintResidual),0.2);
            simulation=problem.simulateDecision(result.Solution.DecisionValues,context);
            testCase.verifyGreaterThan(numel(simulation.Time),100);clear cleanup
        end
    end
end
