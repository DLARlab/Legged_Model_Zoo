classdef SolveService
    %SOLVESERVICE Execute a nonlinear solve through the public problem contract.
    methods
        function result=solve(~,problem,seed,options,context)
            started=tic;
            if ~isa(problem,'lmz.api.NonlinearEquationProblem'),error('lmz:Services:ProblemType','SolveService requires a nonlinear problem.');end
            if nargin<4||isempty(options),options=struct();end
            if nargin<5||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            rawOptions=optionStruct(options);
            solverOptions=lmz.solvers.SolverOptions(options);
            callbacks=solverOptions.Callbacks;
            if isempty(callbacks),callbacks=lmz.solvers.SolveCallbacks();end
            progress=solverOptions.Progress;
            if isempty(progress),progress=lmz.data.SolveProgress();end
            solverOptions.Callbacks=callbacks;solverOptions.Progress=progress;
            parameters=problem.getParameterSchema().defaults(); if isa(seed,'lmz.data.Solution'),parameters=seed.ParameterValues;end
            if isa(seed,'lmz.data.Solution'),seedDecision=seed.DecisionValues; ...
            else,seedDecision=seed(:);end
            selected=lmz.data.SolveIterationSnapshot(struct( ...
                'Stage','seed_selected','Iteration',0,'FunctionCount',0, ...
                'DecisionValues',seedDecision, ...
                'Message','Solve seed selected.'));
            publish(callbacks,progress,'seed_selected',selected);
            if isa(seed,'lmz.data.Solution')
                tolerance=1e-7;if isfield(rawOptions,'AcceptExistingTolerance'),tolerance=rawOptions.AcceptExistingTolerance;end
                initial=problem.evaluate(seed.DecisionValues,parameters,context,false);
                evaluated=lmz.data.SolveIterationSnapshot(struct( ...
                    'Stage','seed_evaluated','Iteration',0, ...
                    'FunctionCount',1,'DecisionValues',seed.DecisionValues, ...
                    'ScaledResidual',initial.ScaledResidualNorm, ...
                    'Message','Selected seed evaluated.'));
                publish(callbacks,progress,'seed_evaluated',evaluated);
                if initial.ScaledResidualNorm<=tolerance&& ...
                        physicallyValid(initial)
                    evaluation=problem.evaluate(seed.DecisionValues,parameters,context,true);
                    solution=problem.makeSolution(seed.DecisionValues,parameters,evaluation);
                    output=struct('algorithm','accepted-existing-seed','iterations',0, ...
                        'funcCount',2,'message','Seed already satisfies the requested tolerance.');
                    completed=lmz.data.SolveIterationSnapshot(struct( ...
                        'Stage','solve_completed','Iteration',0, ...
                        'FunctionCount',2,'DecisionValues',seed.DecisionValues, ...
                        'ScaledResidual',evaluation.ScaledResidualNorm, ...
                        'Accepted',true,'Message',output.message));
                    publish(callbacks,progress,'solve_completed',completed);
                    output.SolveProgress=progress.toStruct();
                    result=lmz.data.SolveResult(solution,evaluation,1,output, ...
                        persistentOptions(rawOptions), ...
                        seed.toStruct(),context.RandomSeed,struct('solver','accept-existing', ...
                        'tolerance',tolerance,'matlabVersion',version, ...
                        'evaluations',2,'elapsedTime',toc(started), ...
                        'problemMetadata',problem.getDescriptor()),progress);
                    context.progress(1,'Existing seed accepted as solved.');return
                end
            end
            result=lmz.solvers.FsolveSolver().solve(problem,seed,parameters, ...
                solverOptions,context);context.progress(1,'Solve complete');
        end
    end
end

function value=physicallyValid(evaluation)
value=logical(evaluation.PhysicalValidity);
if isstruct(evaluation.Feasibility)&& ...
        isfield(evaluation.Feasibility,'Valid')
    value=value&&logical(evaluation.Feasibility.Valid);
end
end

function publish(callbacks,progress,eventName,snapshot)
progress.record(eventName,snapshot);callbacks.notify(eventName,snapshot);
end

function value=optionStruct(options)
if isa(options,'lmz.solvers.SolverOptions')
    value=options.toStruct();
elseif isstruct(options)&&isscalar(options)
    value=options;
else
    error('lmz:Services:SolveOptions', ...
        'Solve options must be a scalar struct or SolverOptions.');
end
end

function value=persistentOptions(value)
runtime={'OutputFcn','Callbacks','Progress'};
for index=1:numel(runtime)
    if isfield(value,runtime{index}),value=rmfield(value,runtime{index});end
end
end
