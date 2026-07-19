classdef FminconSolver
    methods
        function result=solve(~,problem,seed,parameters,options,context)
            if ~isa(problem,'lmz.api.OptimizationProblem'),error('lmz:Optimization:ProblemType','FminconSolver requires OptimizationProblem.');end
            if exist('fmincon','file')~=2,error('lmz:Optimization:ToolboxUnavailable','Optimization Toolbox fmincon is unavailable.');end
            if nargin<5||isempty(options),options=lmz.optimization.OptimizationOptions();elseif isstruct(options),options=lmz.optimization.OptimizationOptions(options);end
            if isa(seed,'lmz.data.Solution'),u0=seed.DecisionValues;sourceSeed=seed.toStruct();else,u0=seed(:);sourceSeed=u0;end
            if nargin<4||isempty(parameters),parameters=problem.getParameterSchema().defaults();end
            [lower,upper]=problem.bounds();lower=lower(:);upper=upper(:);
            if numel(lower)~=numel(u0)||numel(upper)~=numel(u0)
                error('lmz:Optimization:BoundDimension', ...
                    'Optimization bounds must match the decision dimension.');
            end
            fixed=isfinite(lower)&isfinite(upper)&lower==upper;free=~fixed;
            fullTemplate=u0(:);fullTemplate(fixed)=lower(fixed);
            linear=problem.optionalLinearConstraints();
            [A,b,Aeq,beq]=reduceLinearConstraints(linear,free,fullTemplate);
            history=[];
            matlabOptions=optimoptions('fmincon','Algorithm',options.Algorithm,'Display',options.Display, ...
                'MaxIterations',options.MaxIterations,'MaxFunctionEvaluations',options.MaxFunctionEvaluations, ...
                'OptimalityTolerance',options.OptimalityTolerance,'StepTolerance',options.StepTolerance, ...
                'ConstraintTolerance',options.ConstraintTolerance,'OutputFcn',@outputFunction);
            if any(free)
                [freeValues,~,exitFlag,output]=fmincon(@objectiveFunction, ...
                    fullTemplate(free),A,b,Aeq,beq,lower(free),upper(free), ...
                    @constraints,matlabOptions);
                u=expandDecision(freeValues,free,fullTemplate);
            else
                u=fullTemplate;
                exitFlag=1;output=struct('algorithm','fixed-decision', ...
                    'iterations',0,'funcCount',1,'message','All decision variables are fixed.');
            end
            output.freeVariableIndices=find(free);output.fixedVariableIndices=find(fixed);
            [objective,terms,diagnostics]=problem.evaluateObjective(u,parameters,context); solution=problem.makeSolution(u,parameters,[]);
            result=lmz.data.OptimizationResult(solution,objective,terms,exitFlag,output,history,options.toStruct(),sourceSeed,context.RandomSeed, ...
                struct('solver','fmincon','diagnostics',diagnostics,'matlabVersion',version)); context.progress(1,'Optimization complete');
            function value=objectiveFunction(candidate),context.check();full=expandDecision(candidate,free,fullTemplate);[value,~,~]=problem.evaluateObjective(full,parameters,context);end
            function [c,ceq]=constraints(candidate),full=expandDecision(candidate,free,fullTemplate);[c,ceq]=problem.nonlinearConstraints(full,parameters,context);end
            function stop=outputFunction(~,optimValues,state),stop=false;if strcmp(state,'iter'),history(end+1)=optimValues.fval;context.progress(min(0.99,optimValues.iteration/options.MaxIterations),'Optimizing');end;if context.Cancellation.IsCancellationRequested,stop=true;end,end
        end
    end
end

function full=expandDecision(freeValues,free,template)
full=template;full(free)=freeValues(:);
end

function [A,b,Aeq,beq]=reduceLinearConstraints(linear,free,template)
A=linear.A;b=linear.b;Aeq=linear.Aeq;beq=linear.beq;
fixed=~free;
if ~isempty(A)
    b=b-A(:,fixed)*template(fixed);A=A(:,free);
end
if ~isempty(Aeq)
    beq=beq-Aeq(:,fixed)*template(fixed);Aeq=Aeq(:,free);
end
end
