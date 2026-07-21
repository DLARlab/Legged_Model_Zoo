classdef StridePlanCompletionService
    %STRIDEPLANCOMPLETIONSERVICE Noninteractive, checkpointable completion loop.
    methods
        function result=complete(~,builder,plan,options,context)
            if nargin<4||isempty(options),options=struct();end
            if nargin<5||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if ~isa(builder,'lmz.multistride.StridePlanBuilder')
                error('lmz:MultiStride:CompletionBuilder', ...
                    'Completion requires a StridePlanBuilder.');
            end
            lmz.multistride.StridePlanValidator.validate(plan);
            checkpoints={};energyDiagnostics={};recoveryHistory={};
            policy=plan.CompletionPolicy.Id;
            if plan.CompletedStrideCount==plan.RequestedStrideCount
                result=lmz.multistride.MultiStrideResult(plan, ...
                    'CompletionStatus','complete');return
            end
            if strcmp(policy,'error_if_missing')
                error('lmz:MultiStride:MissingStrideSpecification', ...
                    'Stride %d is not specified.',plan.CompletedStrideCount+1);
            end
            if strcmp(policy,'request_user')
                missing=missingDiagnostic(plan,'request_user');
                result=lmz.multistride.MultiStrideResult(plan, ...
                    'CompletionStatus','missing_stride_specification', ...
                    'Diagnostics',missing);return
            end
            callback=fieldOr(options,'ProviderCallback',[]);
            if strcmp(policy,'provider_callback')&&~isa(callback,'function_handle')
                missing=missingDiagnostic(plan,'provider_callback');
                result=lmz.multistride.MultiStrideResult(plan, ...
                    'CompletionStatus','missing_stride_specification', ...
                    'Diagnostics',missing);return
            end
            while plan.CompletedStrideCount<plan.RequestedStrideCount
                context.check();nextIndex=plan.CompletedStrideCount+1;
                stepOptions=options;
                if strcmp(policy,'provider_callback')
                    supplied=callback(plan,nextIndex);
                    if ~isstruct(supplied)
                        error('lmz:MultiStride:ProviderResult', ...
                            'Provider callback must return a struct.');
                    end
                    stepOptions=mergeStruct(stepOptions,supplied);
                end
                ladder=recoveryLadder(stepOptions);attempts=emptyAttempts();
                completed=false;lastException=[];
                for attemptIndex=1:numel(ladder)
                    attemptOptions=stepOptions;
                    attemptOptions.RecoveryAttempt=ladder{attemptIndex};
                    before=plan.CompletedStrideCount;
                    try
                        candidate=builder.completeNext( ...
                            plan,attemptOptions,context);
                        if candidate.CompletedStrideCount~=before+1
                            error('lmz:MultiStride:CompletionProgress', ...
                                'Builder must append exactly one stride.');
                        end
                        plan=candidate;completed=true;
                        attempts(end+1)=attemptRecord(attemptIndex, ...
                            ladder{attemptIndex},true,[],before); %#ok<AGROW>
                        break
                    catch exception
                        lastException=exception;
                        attempts(end+1)=attemptRecord(attemptIndex, ...
                            ladder{attemptIndex},false,exception,before); %#ok<AGROW>
                    end
                end
                recoveryHistory{end+1}=struct('StrideIndex',nextIndex, ...
                    'Succeeded',completed,'Attempts',attempts); %#ok<AGROW>
                if ~completed
                    if strcmp(plan.FailurePolicy,'error')
                        rethrow(lastException)
                    end
                    checkpoint=failureCheckpoint(plan,nextIndex);
                    if isempty(checkpoints)||checkpoints{end}. ...
                            CompletedStrideCount~=plan.CompletedStrideCount
                        checkpoints{end+1}=checkpoint; %#ok<AGROW>
                        checkpointFcn=fieldOr(options,'CheckpointFcn',[]);
                        if isa(checkpointFcn,'function_handle')
                            checkpointFcn(checkpoint);
                        end
                    end
                    failure=struct('Identifier',lastException.identifier, ...
                        'Message',lastException.message, ...
                        'StrideIndex',nextIndex,'RecoveryAttempts',attempts, ...
                        'RecoveryLadderExhausted',true, ...
                        'ResumeCheckpoint',checkpoint);
                    diagnostics=struct('RecoveryHistory',{recoveryHistory}, ...
                        'RecoveryLadderExhausted',true, ...
                        'LastCompletedStrideCount',plan.CompletedStrideCount, ...
                        'FailedStrideIndex',nextIndex, ...
                        'ResumeCheckpoint',checkpoint);
                    result=lmz.multistride.MultiStrideResult(plan, ...
                        'CompletionStatus','failed','Failure',failure, ...
                        'Diagnostics',diagnostics,'Checkpoints',checkpoints, ...
                        'EnergyDiagnostics',energyDiagnostics);return
                end
                diagnostics=plan.StrideSpecs(end).Diagnostics;
                if isfield(diagnostics,'Energy')
                    energyDiagnostics{end+1}=diagnostics.Energy; %#ok<AGROW>
                end
                checkpoint=struct('CompletedStrideCount', ...
                    plan.CompletedStrideCount,'Plan',plan.toStruct(), ...
                    'Kind','completed_stride');
                checkpoints{end+1}=checkpoint; %#ok<AGROW>
                checkpointFcn=fieldOr(options,'CheckpointFcn',[]);
                if isa(checkpointFcn,'function_handle'),checkpointFcn(checkpoint);end
                context.progress(plan.CompletedStrideCount/plan.RequestedStrideCount, ...
                    sprintf('Completed stride %d of %d.', ...
                    plan.CompletedStrideCount,plan.RequestedStrideCount));
            end
            diagnostics=struct('RecoveryHistory',{recoveryHistory}, ...
                'RecoveryLadderExhausted',false, ...
                'LastCompletedStrideCount',plan.CompletedStrideCount);
            result=lmz.multistride.MultiStrideResult(plan, ...
                'CompletionStatus','complete','Checkpoints',checkpoints, ...
                'Diagnostics',diagnostics, ...
                'EnergyDiagnostics',energyDiagnostics);
        end

        function result=resume(obj,builder,checkpoint,options,context)
            if nargin<4||isempty(options),options=struct();end
            if nargin<5||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if isa(checkpoint,'lmz.multistride.StridePlan')
                plan=checkpoint;
            elseif isstruct(checkpoint)&&isscalar(checkpoint)&& ...
                    isfield(checkpoint,'Plan')
                stored=checkpoint.Plan;
                if isa(stored,'lmz.multistride.StridePlan')
                    plan=stored;
                else
                    plan=lmz.multistride.StridePlan.fromStruct(stored);
                end
                if isfield(checkpoint,'CompletedStrideCount')&& ...
                        checkpoint.CompletedStrideCount~= ...
                        plan.CompletedStrideCount
                    error('lmz:MultiStride:CheckpointCount', ...
                        'Checkpoint count does not match its stored stride plan.');
                end
            else
                error('lmz:MultiStride:CompletionCheckpoint', ...
                    'Resume requires a StridePlan or completion checkpoint.');
            end
            result=obj.complete(builder,plan,options,context);
        end
    end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=mergeStruct(first,second)
value=first;names=fieldnames(second);
for index=1:numel(names),value.(names{index})=second.(names{index});end
end
function value=missingDiagnostic(plan,policy)
value=struct('Code','MissingStrideSpecification', ...
    'Policy',policy,'MissingStrideIndex',plan.CompletedStrideCount+1, ...
    'RequestedStrideCount',plan.RequestedStrideCount, ...
    'CompletedStrideCount',plan.CompletedStrideCount);
end

function value=recoveryLadder(options)
if ~isfield(options,'RecoveryLadder')||isempty(options.RecoveryLadder)
    value={struct('Strategy','baseline')};return
end
source=options.RecoveryLadder;
if isstruct(source),source=num2cell(source);end
if ~iscell(source)||isempty(source)
    error('lmz:MultiStride:RecoveryLadder', ...
        'RecoveryLadder must contain named strategy structs.');
end
value=cell(size(source));
for index=1:numel(source)
    item=source{index};
    if ~isstruct(item)||~isscalar(item)||~isfield(item,'Strategy')|| ...
            ~(ischar(item.Strategy)|| ...
            (isstring(item.Strategy)&&isscalar(item.Strategy)))
        error('lmz:MultiStride:RecoveryLadder', ...
            'Every recovery attempt requires a Strategy label.');
    end
    item.Strategy=char(item.Strategy);value{index}=item;
end
end

function value=emptyAttempts()
value=struct('AttemptIndex',{},'Strategy',{},'Parameters',{}, ...
    'StartedFromCompletedStrideCount',{},'Succeeded',{}, ...
    'Identifier',{},'Message',{},'TerminationStage',{});
end

function value=attemptRecord(index,specification,succeeded,exception,count)
identifier='';message='';stage='completed';
if ~succeeded
    identifier=exception.identifier;message=exception.message;
    if strcmp(identifier,'lmz:MultiStride:TimingSeedOutsideTrustRegion')
        stage='timing_seed_trust_region_gate';
    else
        stage='builder_completion';
    end
end
value=struct('AttemptIndex',index,'Strategy',specification.Strategy, ...
    'Parameters',specification, ...
    'StartedFromCompletedStrideCount',count, ...
    'Succeeded',logical(succeeded),'Identifier',identifier, ...
    'Message',message,'TerminationStage',stage);
end

function value=failureCheckpoint(plan,failedStride)
value=struct('CompletedStrideCount',plan.CompletedStrideCount, ...
    'Plan',plan.toStruct(),'Kind','recovery_ladder_exhausted', ...
    'FailedStrideIndex',failedStride);
end
