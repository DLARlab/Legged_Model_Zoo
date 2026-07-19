classdef TestOptimizationWorkflow < matlab.unittest.TestCase
    methods (Test)
        function objectivesDecrease(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            biped=registry.createModel('slip_biped').createProblem( ...
                'trajectory_fit',struct('EnforceConstraints',false));
            values=biped.sourceSeed();values(1)=values(1)+0.05;values(4)=values(4)+0.01;
            verifyDecrease(testCase,biped,values,struct('Algorithm','sqp', ...
                'MaxIterations',3,'MaxFunctionEvaluations',150, ...
                'ConstraintTolerance',0.2,'OptimalityTolerance',1e-3, ...
                'StepTolerance',1e-3),1);
            loadFit=registry.createModel('slip_quad_load').createProblem( ...
                'multi_stride_fit',struct());
            verifyDecrease(testCase,loadFit,loadFit.getDecisionSchema().defaults(), ...
                struct('Algorithm','sqp','MaxIterations',1, ...
                'MaxFunctionEvaluations',30,'OptimalityTolerance',1e-5, ...
                'StepTolerance',1e-5),2);
        end
    end
end

function verifyDecrease(testCase,problem,values,options,randomSeed)
parameters=problem.getParameterSchema().defaults();context=lmz.api.RunContext.synchronous(randomSeed);
seed=problem.makeSolution(values,parameters,[]);
[initial,~,~]=problem.evaluateObjective(values,parameters,context);
result=lmz.services.OptimizationService().run(problem,seed,options,context);
testCase.verifyLessThan(result.Objective,initial);testCase.verifyTrue(isfinite(result.Objective));
end
