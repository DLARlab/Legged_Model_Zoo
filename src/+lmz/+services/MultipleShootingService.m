classdef MultipleShootingService
    %MULTIPLESHOOTINGSERVICE Solve and physically classify a shooting horizon.
    methods
        function result=solve(~,problem,seed,options,context)
            if nargin<3,seed=[];end
            if nargin<4||isempty(options),options=struct();end
            if nargin<5||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if ~isa(problem,'lmz.shooting.MultipleShootingProblem')
                error('lmz:Services:MultipleShootingProblem', ...
                    'MultipleShootingService requires a shooting problem.');
            end
            values=optionStruct(options);
            parameters=problem.getParameterSchema().defaults();
            if isa(seed,'lmz.data.Solution')
                parameters=seed.ParameterValues;
            end
            useInitializer=isempty(seed)||logicalOption(values, ...
                'UseInitializer',false);
            [candidates,history,historyIndices]=initialCandidates( ...
                problem,seed,values,useInitializer);
            solverOptions=removeFields(values,initializerOptionNames());
            tolerance=fieldOr(values,'ResidualTolerance', ...
                fieldOr(problem.Configuration,'ResidualTolerance',1e-7));

            attempts=cell(numel(candidates),1);failures={};
            for index=1:numel(candidates)
                history=recordAttemptStart(history,historyIndices(index),index);
                try
                    [solved,rankDiagnostics]= ...
                        lmz.solvers.RankAwareNonlinearSolver().solve( ...
                        problem,candidates{index},parameters,solverOptions, ...
                        context);
                    report=lmz.shooting.FeasibilityReport.fromSolve( ...
                        solved.Evaluation,rankDiagnostics, ...
                        solved.ExitFlag,tolerance);
                    attempts{index}=struct('SolveResult',solved, ...
                        'RankDiagnostics',rankDiagnostics,'Report',report, ...
                        'CandidateIndex',index);
                    history=recordAttemptResult(history, ...
                        historyIndices(index),report,solved.ExitFlag);
                catch caught
                    if strcmp(caught.identifier,'lmz:Cancelled')
                        rethrow(caught);
                    end
                    failures{end+1,1}=caught; %#ok<AGROW>
                    history=recordAttemptFailure(history, ...
                        historyIndices(index),caught);
                end
            end
            completed=find(~cellfun(@isempty,attempts));
            if isempty(completed)
                rethrow(failures{1});
            end
            selected=selectAttempt(attempts,completed);
            chosen=attempts{selected};
            history=recordSelection(history,historyIndices,selected);
            solved=chosen.SolveResult;
            rankDiagnostics=chosen.RankDiagnostics;
            report=chosen.Report;
            shootingResidual=problem.evaluateShooting( ...
                solved.Solution.DecisionValues, ...
                solved.Solution.ParameterValues,context,true);
            initializerDiagnostics=struct('UseInitializer',useInitializer, ...
                'CandidateCount',numel(candidates), ...
                'CompletedSolveCount',numel(completed), ...
                'FailedSolveCount',numel(candidates)-numel(completed), ...
                'SelectedCandidateIndex',selected, ...
                'SelectedHistoryIndex',historyIndices(selected));
            result=lmz.shooting.ShootingResult(solved,problem.Horizon,report, ...
                'SegmentResults',shootingResidual.SegmentResults, ...
                'InitializerHistory',history, ...
                'Diagnostics',struct('Rank',rankDiagnostics, ...
                'Initializer',initializerDiagnostics, ...
                'ProblemContract',problem.contract()));
            context.progress(1,sprintf('Multiple shooting: %s', ...
                report.Classification));
        end
    end
end

function [candidates,history,indices]=initialCandidates(problem,seed, ...
        options,useInitializer)
history=problemInitializationHistory(problem);candidates={};indices=[];
if ~isempty(seed)
    candidates{end+1,1}=seed;
    history{end+1,1}=struct('Strategy','provided_seed', ...
        'Accepted',true,'Source',seedSource(seed),'Score',NaN);
    indices(end+1,1)=numel(history);
end
if useInitializer
    [templates,initializerOptions]=initializerInputs(options);
    [generated,generatedHistory]=lmz.shooting.ShootingInitializer(). ...
        initialize(problem.ShootingSchema,templates,initializerOptions);
    accepted=find(cellfun(@historyAccepted,generatedHistory));
    if numel(accepted)~=numel(generated)
        error('lmz:Services:ShootingInitializerHistory', ...
            'Initializer candidates and accepted history are inconsistent.');
    end
    offset=numel(history);
    history=[history(:);generatedHistory(:)];
    candidates=[candidates(:);generated(:)];
    indices=[indices(:);offset+accepted(:)];
end
end

function [templates,options]=initializerInputs(values)
options=struct();
fields={'MultistartCount','MultistartScale','RandomSeed', ...
    'SecantFactor','TemplateWeights'};
for index=1:numel(fields)
    if isfield(values,fields{index})
        options.(fields{index})=values.(fields{index});
    end
end
nested=fieldOr(values,'InitializerOptions',struct());
if ~isstruct(nested)||~isscalar(nested)
    error('lmz:Services:ShootingInitializerOptions', ...
        'InitializerOptions must be a scalar struct.');
end
names=fieldnames(nested);
for index=1:numel(names)
    options.(names{index})=nested.(names{index});
end
templates=fieldOr(values,'InitializerTemplates', ...
    fieldOr(options,'Templates',{}));
if isfield(options,'Templates'),options=rmfield(options,'Templates');end
end

function history=problemInitializationHistory(problem)
history={};configuration=problem.Configuration;
if ~isstruct(configuration)|| ...
        ~isfield(configuration,'InitializerDiagnostics')
    return
end
diagnostics=configuration.InitializerDiagnostics;
if ~isstruct(diagnostics)|| ...
        ~isfield(diagnostics,'InitializationHistory')
    return
end
source=diagnostics.InitializationHistory;
if isempty(source),return,end
if isstruct(source),source=num2cell(source);end
if ~iscell(source)
    error('lmz:Services:ShootingProblemInitializerHistory', ...
        'Problem initializer history must be a cell or struct array.');
end
history=source(:);
end

function value=historyAccepted(item)
value=isstruct(item)&&isscalar(item)&&isfield(item,'Accepted')&& ...
    isscalar(item.Accepted)&&logical(item.Accepted);
end

function history=recordAttemptStart(history,index,candidateIndex)
item=history{index};item.SolverAttempted=true;
item.SolverCandidateIndex=candidateIndex;item.Selected=false;
history{index}=item;
end

function history=recordAttemptResult(history,index,report,exitFlag)
item=history{index};item.SolverCompleted=true;item.ExitFlag=exitFlag;
item.Classification=report.Classification;
item.PhysicalConditionsValid=report.PhysicalConditionsValid;
item.ScaledResidualNorm=report.ScaledResidualNorm;
item.MaximumScaledResidual=report.MaximumScaledResidual;
history{index}=item;
end

function history=recordAttemptFailure(history,index,caught)
item=history{index};item.SolverCompleted=false;item.ExitFlag=NaN;
item.Classification='solver_exception';item.ErrorIdentifier=caught.identifier;
item.ErrorMessage=caught.message;history{index}=item;
end

function history=recordSelection(history,indices,selected)
for index=1:numel(indices)
    item=history{indices(index)};item.Selected=index==selected;
    history{indices(index)}=item;
end
end

function selected=selectAttempt(attempts,completed)
successful=completed(cellfun(@(item)item.Report.Success,attempts(completed)));
if ~isempty(successful)
    selected=successful(1);return
end
selected=completed(1);best=attemptRank(attempts{selected});
remaining=completed(2:end);
for cursor=1:numel(remaining)
    index=remaining(cursor);
    candidate=attemptRank(attempts{index});
    if lexicographicallyLess(candidate,best)
        selected=index;best=candidate;
    end
end
end

function value=attemptRank(attempt)
report=attempt.Report;residual=report.ScaledResidualNorm;
if ~isfinite(residual),residual=Inf;end
value=[~report.PhysicalConditionsValid, ...
    ~report.SolverTerminationAcceptable,residual,attempt.CandidateIndex];
end

function value=lexicographicallyLess(left,right)
difference=find(left~=right,1);
value=~isempty(difference)&&left(difference)<right(difference);
end

function value=seedSource(seed)
if isa(seed,'lmz.data.Solution')
    value='solution';
else
    value='decision_vector';
end
end

function value=logicalOption(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~(islogical(value)||isnumeric(value))||~isscalar(value)|| ...
        ~isfinite(value)||~any(value==[0 1])
    error('lmz:Services:ShootingInitializerOption', ...
        '%s must be a logical scalar.',name);
end
value=logical(value);
end

function value=optionStruct(options)
if isa(options,'lmz.solvers.SolverOptions')
    value=options.toStruct();
elseif isstruct(options)&&isscalar(options)
    value=options;
else
    error('lmz:Services:MultipleShootingOptions', ...
        'Multiple-shooting options must be a scalar struct or SolverOptions.');
end
end

function names=initializerOptionNames()
names={'UseInitializer','InitializerTemplates','InitializerOptions', ...
    'MultistartCount','MultistartScale','RandomSeed','SecantFactor', ...
    'TemplateWeights'};
end

function value=removeFields(value,names)
for index=1:numel(names)
    if isfield(value,names{index}),value=rmfield(value,names{index});end
end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
