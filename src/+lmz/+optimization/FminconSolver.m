classdef FminconSolver
    methods
        function result=solve(~,problem,seed,parameters,options,context)
            if ~isa(problem,'lmz.api.OptimizationProblem'),error('lmz:Optimization:ProblemType','FminconSolver requires OptimizationProblem.');end
            if exist('fmincon','file')~=2,error('lmz:Optimization:ToolboxUnavailable','Optimization Toolbox fmincon is unavailable.');end
            if nargin<5||isempty(options),options=lmz.optimization.OptimizationOptions();elseif isstruct(options),options=lmz.optimization.OptimizationOptions(options);end
            if isa(seed,'lmz.data.Solution'),u0=seed.DecisionValues;sourceSeed=seed.toStruct();else,u0=seed(:);sourceSeed=u0;end
            if nargin<4||isempty(parameters),parameters=problem.getParameterSchema().defaults();end
            [lower,upper]=problem.bounds(); linear=problem.optionalLinearConstraints(); history=[];
            matlabOptions=optimoptions('fmincon','Algorithm',options.Algorithm,'Display',options.Display, ...
                'MaxIterations',options.MaxIterations,'MaxFunctionEvaluations',options.MaxFunctionEvaluations, ...
                'OptimalityTolerance',options.OptimalityTolerance,'StepTolerance',options.StepTolerance, ...
                'ConstraintTolerance',options.ConstraintTolerance,'OutputFcn',@outputFunction);
            [u,objective,exitFlag,output]=fmincon(@objectiveFunction,u0,linear.A,linear.b,linear.Aeq,linear.beq,lower,upper,@constraints,matlabOptions);
            [objective,terms,diagnostics]=problem.evaluateObjective(u,parameters,context); solution=problem.makeSolution(u,parameters,[]);
            result=lmz.data.OptimizationResult(solution,objective,terms,exitFlag,output,history,options.toStruct(),sourceSeed,context.RandomSeed, ...
                struct('solver','fmincon','diagnostics',diagnostics,'matlabVersion',version)); context.progress(1,'Optimization complete');
            function value=objectiveFunction(candidate),context.check();[value,~,~]=problem.evaluateObjective(candidate,parameters,context);end
            function [c,ceq]=constraints(candidate),[c,ceq]=problem.nonlinearConstraints(candidate,parameters,context);end
            function stop=outputFunction(~,optimValues,state),stop=false;if strcmp(state,'iter'),history(end+1)=optimValues.fval;context.progress(min(0.99,optimValues.iteration/options.MaxIterations),'Optimizing');end;if context.Cancellation.IsCancellationRequested,stop=true;end,end
        end
    end
end
