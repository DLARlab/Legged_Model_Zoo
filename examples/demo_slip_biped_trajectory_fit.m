projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('slip_biped');
% The published Main.m workflow uses the penalized unconstrained objective.
problem=model.createProblem('trajectory_fit',struct('EnforceConstraints',false));
context=lmz.api.RunContext.synchronous(23);
sourceSeed=problem.sourceSeed();
initial=sourceSeed;initial(1)=initial(1)+0.05;initial(4)=initial(4)+0.01;
parameters=problem.getParameterSchema().defaults();
[initialObjective,initialTerms]=problem.evaluateObjective(initial,parameters,context);
seed=problem.makeSolution(initial,parameters,[]);
warningState=warning('off','MATLAB:ode45:IntegrationTolNotMet');
warningCleanup=onCleanup(@()warning(warningState));
options=struct('Algorithm','sqp','MaxIterations',3,'MaxFunctionEvaluations',150, ...
    'ConstraintTolerance',0.2,'OptimalityTolerance',1e-3,'StepTolerance',1e-3);
optimizationResult=lmz.services.OptimizationService().run(problem,seed,options,context);
optimizedSimulation=problem.simulateDecision( ...
    optimizationResult.Solution.DecisionValues,context);
output=struct('InitialDecision',initial,'InitialObjective',initialObjective, ...
    'InitialTerms',initialTerms,'OptimizationResult',optimizationResult, ...
    'OptimizedSimulation',optimizedSimulation, ...
    'ObjectiveDecrease',initialObjective-optimizationResult.Objective, ...
    'SuccessMarker','LMZ_BIPED_TRAJECTORY_FIT_OK');
if output.ObjectiveDecrease<=0
    error('lmz:Example:BipedFit','Short trajectory fit did not decrease the objective.');
end
fprintf('%s initial=%.6f final=%.6f decrease=%.6f\n',output.SuccessMarker, ...
    output.InitialObjective,optimizationResult.Objective,output.ObjectiveDecrease);
clear warningCleanup directoryCleanup
