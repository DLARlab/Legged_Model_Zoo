classdef FsolveSolver < lmz.solvers.RootSolver
    methods
        function result=solve(~,problem,seed,parameters,options,context)
            started=tic;
            if ~isa(problem,'lmz.api.NonlinearEquationProblem'), error('lmz:Solver:ProblemType','FsolveSolver requires NonlinearEquationProblem.'); end
            if exist('fsolve','file')~=2, error('lmz:Solver:ToolboxUnavailable','Optimization Toolbox fsolve is unavailable.'); end
            if nargin<5||isempty(options),options=lmz.solvers.SolverOptions();else,options=lmz.solvers.SolverOptions(options);end
            if nargin<6||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if isa(seed,'lmz.data.Solution'),u0=seed.DecisionValues;sourceSeed=seed.toStruct();else,u0=seed(:);sourceSeed=u0;end
            if nargin<4||isempty(parameters),parameters=problem.getParameterSchema().defaults();end
            scale=problem.scale(u0); q0=u0./scale;
            callbacks=options.Callbacks;
            if isempty(callbacks),callbacks=lmz.solvers.SolveCallbacks();end
            progress=options.Progress;
            if isempty(progress),progress=lmz.data.SolveProgress();end
            userOutputFcn=options.OutputFcn;
            optionValues=struct('Display',options.Display,'Algorithm',options.Algorithm, ...
                'FunctionTolerance',options.FunctionTolerance,'StepTolerance',options.StepTolerance, ...
                'OptimalityTolerance',options.OptimalityTolerance,'MaxIterations',options.MaxIterations, ...
                'MaxFunctionEvaluations',options.MaxFunctionEvaluations, ...
                'OutputFcn',@outputFunction);
            matlabOptions=lmz.compat.Optimization.fsolve(optionValues);
            evaluations=0;residualHistory=zeros(0,1);stopRequested=false;
            try
                [q,~,exitFlag,output]=fsolve(@residual,q0,matlabOptions);
            catch exception
                if strcmp(exception.identifier,'lmz:Cancelled')
                    publish('controlled_stop',snapshot('controlled_stop', ...
                        q0,struct(),'Run cancelled cooperatively.',false));
                else
                    publish('solve_failed',snapshot('solve_failed',q0, ...
                        struct(),exception.message,false));
                end
                rethrow(exception)
            end
            output.ResidualHistory=residualHistory;
            u=problem.canonicalize(q.*scale);
            evaluationContext=context;
            if context.Cancellation.IsCancellationRequested
                evaluationContext=lmz.api.RunContext.synchronous( ...
                    context.RandomSeed);
            end
            evaluation=problem.evaluate(u,parameters,evaluationContext,true);
            solution=problem.makeSolution(u,parameters,evaluation);
            controlled=stopRequested||context.Cancellation.IsCancellationRequested;
            if controlled
                eventName='controlled_stop';
            elseif exitFlag>0
                eventName='solve_completed';
            else
                eventName='solve_failed';
            end
            finalSnapshot=snapshot(eventName,q,output,fieldOr( ...
                output,'message','Nonlinear solve finished.'),exitFlag>0);
            finalSnapshot=lmz.data.SolveIterationSnapshot(mergeStruct( ...
                finalSnapshot.toStruct(),struct( ...
                'ScaledResidual',evaluation.ScaledResidualNorm)));
            publish(eventName,finalSnapshot);
            output.SolveProgress=progress.toStruct();
            result=lmz.data.SolveResult(solution,evaluation,exitFlag,output,options.toStruct(),sourceSeed,context.RandomSeed, ...
                struct('solver','fsolve','matlabVersion',version, ...
                'evaluations',evaluations,'elapsedTime',toc(started), ...
                'problemMetadata',problem.getDescriptor()),progress);
            function value=residual(qValue)
                context.check(); evaluations=evaluations+1; candidate=problem.canonicalize(qValue.*scale); value=problem.residual(candidate,parameters,context); residualHistory(end+1,1)=norm(value); context.progress(min(0.99,evaluations/options.MaxFunctionEvaluations),'Solving nonlinear equations');
                if ~any(strcmp(progress.Events,'seed_evaluated'))
                    seedSnapshot=lmz.data.SolveIterationSnapshot(struct( ...
                        'Stage','seed_evaluated','Iteration',0, ...
                        'FunctionCount',evaluations, ...
                        'DecisionValues',candidate, ...
                        'ScaledResidual',norm(value), ...
                        'Message','Selected seed evaluated.'));
                    stopRequested=publish('seed_evaluated',seedSnapshot)|| ...
                        stopRequested;
                end
            end
            function stop=outputFunction(qValue,optimValues,state)
                stage=state;
                if strcmp(state,'init'),stage='solve_started'; ...
                elseif strcmp(state,'iter'),stage='iteration';end
                current=snapshot(stage,qValue,optimValues, ...
                    outputMessage(state),strcmp(state,'iter'));
                stop=false;
                if strcmp(state,'init')
                    stop=publish('solve_started',current);
                elseif strcmp(state,'iter')
                    stop=publish('iteration',current);
                    accepted=lmz.data.SolveIterationSnapshot(mergeStruct( ...
                        current.toStruct(),struct('Stage','step_accepted', ...
                        'Accepted',true)));
                    stop=publish('step_accepted',accepted)||stop;
                    context.progress(min(0.99,numericField(optimValues, ...
                        {'iteration'},0)/max(1,options.MaxIterations)), ...
                        'Refining the selected solution');
                end
                stop=invokeUserOutput(userOutputFcn,qValue,optimValues,state)||stop;
                if context.Cancellation.IsCancellationRequested,stop=true;end
                stopRequested=stopRequested||stop;
            end
            function value=snapshot(stage,qValue,values,message,accepted)
                if nargin<5,accepted=false;end
                value=lmz.data.SolveIterationSnapshot(struct( ...
                    'Stage',stage, ...
                    'Iteration',numericField(values,{'iteration','iterations'},NaN), ...
                    'FunctionCount',numericField(values, ...
                    {'funccount','funcCount'},evaluations), ...
                    'DecisionValues',problem.canonicalize(qValue.*scale), ...
                    'ScaledResidual',residualNorm(values), ...
                    'StepNorm',numericField(values, ...
                    {'stepsize','stepnorm','step'},NaN), ...
                    'FirstOrderOptimality',numericField(values, ...
                    {'firstorderopt','firstorderoptimality'},NaN), ...
                    'Accepted',logical(accepted),'Message',message));
            end
            function stop=publish(eventName,value)
                progress.record(eventName,value);
                stop=callbacks.notify(eventName,value);
            end
        end
    end
end

function value=residualNorm(values)
value=NaN;
if ~isstruct(values),return,end
names={'fval','residual','resnorm'};
for index=1:numel(names)
    if isfield(values,names{index})&&isnumeric(values.(names{index}))&& ...
            ~isempty(values.(names{index}))
        candidate=values.(names{index});
        if all(isfinite(candidate(:))),value=norm(candidate(:));return,end
    end
end
end

function value=numericField(source,names,fallback)
value=fallback;
if ~isstruct(source),return,end
for index=1:numel(names)
    if isfield(source,names{index})&&isnumeric(source.(names{index}))&& ...
            isscalar(source.(names{index}))&&isfinite(source.(names{index}))
        value=source.(names{index});return
    end
end
end

function value=fieldOr(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name),value=source.(name);end
if isstring(value)&&isscalar(value),value=char(value);end
if ~ischar(value),value=fallback;end
end

function value=outputMessage(state)
switch state
    case 'init',value='Nonlinear solve started.';
    case 'iter',value='Nonlinear solver iteration accepted.';
    case 'done',value='Nonlinear solver callback completed.';
    otherwise,value=['Nonlinear solver state: ' state '.'];
end
end

function stop=invokeUserOutput(callbacks,qValue,optimValues,state)
stop=false;
if isempty(callbacks),return,end
if ~iscell(callbacks),callbacks={callbacks};end
for index=1:numel(callbacks)
    callback=callbacks{index};value=[];
    try
        if nargout(callback)==0
            callback(qValue,optimValues,state);
        else
            value=callback(qValue,optimValues,state);
        end
    catch exception
        if strcmp(exception.identifier,'MATLAB:TooManyOutputs')|| ...
                strcmp(exception.identifier,'MATLAB:maxlhs')
            callback(qValue,optimValues,state);value=[];
        else
            rethrow(exception)
        end
    end
    if ~isempty(value)
        if ~(islogical(value)&&isscalar(value))
            error('lmz:Solver:OutputFcnReturn', ...
                'A solver OutputFcn stop request must be logical scalar.');
        end
        stop=stop||value;
    end
end
end

function value=mergeStruct(value,updates)
names=fieldnames(updates);
for index=1:numel(names),value.(names{index})=updates.(names{index});end
end
