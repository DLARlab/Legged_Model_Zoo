classdef QuadLoadStridePlanBuilder < lmz.multistride.StridePlanBuilder
    %QUADLOADSTRIDEPLANBUILDER Complete missing legacy-compatible stride blocks.
    properties (SetAccess=private)
        TransitionMap
    end

    methods
        function obj=QuadLoadStridePlanBuilder()
            obj.TransitionMap= ...
                lmzmodels.slip_quad_load.QuadLoadStrideTransitionMap();
        end

        function plan=initialPlan(~,request,context)
            context.check();
            if isempty(request.InitialDecision)
                error('lmz:QuadLoad:InitialDecision', ...
                    'Quad-load plan construction requires InitialDecision.');
            end
            plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
                request.InitialDecision,'StartSectionId',request.StartSectionId, ...
                'StopSectionId',request.StopSectionId, ...
                'CompletionPolicy',request.CompletionPolicy, ...
                'EnergyPolicy',request.EnergyPolicy);
        end

        function plan=completeNext(obj,plan,options,context)
            context.check();
            if plan.CompletedStrideCount<1
                error('lmz:QuadLoad:CompletionSeed', ...
                    'At least one completed stride is required.');
            end
            index=plan.CompletedStrideCount+1;previous=plan.StrideSpecs(end);
            [schedule,prediction]=predictSchedule(plan);
            if isfield(options,'EventSchedule')&&~isempty(options.EventSchedule)
                schedule=normalizeSchedule(options.EventSchedule);
                prediction.OverrideApplied=true;
            end
            controls=obj.TransitionMap.carryControls(previous.ControlParameters,[]);
            overrides=overridesFor(fieldOr(options,'ParameterOverrides',struct()),index);
            if isfield(overrides,'EventSchedule')
                schedule=normalizeSchedule(overrides.EventSchedule);
                overrides=rmfield(overrides,'EventSchedule');
                prediction.OverrideApplied=true;
            end
            if isfield(options,'ControlParameters')
                overrides=mergeStruct(overrides,options.ControlParameters);
            end
            if isfield(overrides,'PostSwingStiffness')
                controls=obj.TransitionMap.carryControls( ...
                    previous.ControlParameters,overrides.PostSwingStiffness);
            end
            if isfield(overrides,'PreSwingStiffness')&& ...
                    ~isequaln(overrides.PreSwingStiffness(:), ...
                    controls.PreSwingStiffness(:))
                error('lmz:QuadLoad:PreSwingTransition', ...
                    'Pre-swing stiffness must equal the previous post-swing values.');
            end
            physical=previous.PhysicalParameters;
            transition=lmz.multistride.ParameterTransitionPolicy().validate( ...
                previous.PhysicalParameters,physical);
            energyState=plan.InitialState;
            changed=~isequaln(abs(previous.ControlParameters.PostSwingStiffness(:)), ...
                abs(controls.PostSwingStiffness(:)));
            if changed
                energyState=fieldOr(options,'TransitionState',[]);
                if isempty(energyState)
                    error('lmz:QuadLoad:EnergyTransitionState', ...
                        'Changed stiffness requires the parameter-activation state.');
                end
            end
            declaredWork=workFor(fieldOr(options,'DeclaredWork',0),index);
            candidate=lmz.multistride.StrideSpec('Index',index, ...
                'StartSectionId',previous.StartSectionId, ...
                'StopSectionId',previous.StopSectionId, ...
                'StartStateSide',previous.StartStateSide, ...
                'StopStateSide',previous.StopStateSide, ...
                'EventSchedule',schedule,'PhysicalParameters',physical, ...
                'ControlParameters',controls,'ParameterOverrides',overrides, ...
                'InitialStateSource','previous_terminal_source_local', ...
                'CompletionStatus','completed','Lineage',struct( ...
                'PreviousStrideIndex',previous.Index,'Method',prediction.Method));
            energyPolicy=lmzmodels.slip_quad_load.QuadLoadEnergyPolicy( ...
                'Id',plan.EnergyPolicy.Id,'Tolerance',plan.EnergyPolicy.Tolerance);
            energy=energyPolicy.validateTransition( ...
                energyState,previous,candidate,declaredWork);
            corrector=fieldOr(options,'TimingCorrector',[]);
            correctionRequired=strcmp(plan.CompletionPolicy.Id, ...
                'carry_forward_and_solve_timings');
            correctionRequested=correctionRequired|| ...
                (strcmp(plan.CompletionPolicy.Id,'predictor_corrector')&& ...
                isa(corrector,'function_handle'));
            if correctionRequired&&~isa(corrector,'function_handle')
                    error('lmz:QuadLoad:TimingCorrectorRequired', ...
                        'Timing-corrected completion requires an explicit corrector.');
            end
            if correctionRequested
                recoveryAttempt=fieldOr(options,'RecoveryAttempt', ...
                    struct('Strategy','baseline'));
                corrected=invokeCorrector(corrector,plan,candidate, ...
                    context,recoveryAttempt);
                schedule=normalizeSchedule(corrected);
                candidate=lmz.multistride.StrideSpec('Index',index, ...
                    'StartSectionId',candidate.StartSectionId, ...
                    'StopSectionId',candidate.StopSectionId, ...
                    'StartStateSide',candidate.StartStateSide, ...
                    'StopStateSide',candidate.StopStateSide, ...
                    'EventSchedule',schedule,'PhysicalParameters',physical, ...
                    'ControlParameters',controls,'ParameterOverrides',overrides, ...
                    'InitialStateSource',candidate.InitialStateSource, ...
                    'CompletionStatus','completed','Lineage',candidate.Lineage);
                prediction.TimingCorrected=true;
            end
            diagnostics=struct('Prediction',prediction, ...
                'ParameterTransition',transition,'Energy',energy, ...
                'RecoveryAttempt',fieldOr(options,'RecoveryAttempt', ...
                struct('Strategy','baseline')), ...
                'CompletedBy','QuadLoadStridePlanBuilder');
            candidate=candidate.withCompletion('completed',diagnostics);
            plan=plan.append(candidate);
        end
    end
end

function [schedule,diagnostics]=predictSchedule(plan)
latest=plan.StrideSpecs(end).EventSchedule;schedule=latest;
diagnostics=struct('Method','carry_forward','UsedSecant',false, ...
    'FallbackReason','','OverrideApplied',false,'TimingCorrected',false);
if ~strcmp(plan.CompletionPolicy.Id,'predictor_corrector')|| ...
        plan.CompletedStrideCount<2
    return
end
previous=plan.StrideSpecs(end-1).EventSchedule;
if ~compatibleCharts(previous,latest)
    diagnostics.Method='carry_forward_after_incompatible_chart';
    diagnostics.FallbackReason='event_order_changed';return
end
candidate=latest;candidate.Times=2*latest.Times(:)-previous.Times(:);
candidate.ReturnTime=candidate.Times(9);
if ~validPrediction(candidate)
    diagnostics.Method='carry_forward_after_invalid_secant';
    diagnostics.FallbackReason='positive_gap_validation_failed';return
end
schedule=candidate;diagnostics.Method='schema_aware_secant';
diagnostics.UsedSecant=true;
end
function value=compatibleCharts(first,second)
required={'Names','Times','OccurrenceOrder','Chart'};
value=isstruct(first)&&isstruct(second)&&all(isfield(first,required))&& ...
    all(isfield(second,required))&&isequal(first.Names,second.Names)&& ...
    isequal(first.OccurrenceOrder,second.OccurrenceOrder)&& ...
    strcmp(first.Chart,second.Chart)&&numel(first.Times)==numel(second.Times);
end
function value=validPrediction(schedule)
times=schedule.Times(:);period=times(end);
if numel(times)~=9||any(~isfinite(times))||period<=0|| ...
        any(times(1:8)<=0)||any(times(1:8)>=period)
    value=false;return
end
[sorted,order]=sort(times);names=schedule.Names(order);
minimumGap=max(1e-10,fieldOr(schedule,'MinimumGap',0));
value=all(diff([0;sorted])>minimumGap)&& ...
    isequal(names(:),schedule.OccurrenceOrder(:));
end
function value=normalizeSchedule(source)
if isstruct(source)&&isfield(source,'SolvedSchedule')
    source=source.SolvedSchedule;
end
if ~isstruct(source)||~all(isfield(source,{'Names','Times'}))
    error('lmz:QuadLoad:CompletionSchedule', ...
        'Completed event schedule must expose Names and Times.');
end
value=source;value.Times=value.Times(:);
if numel(value.Times)~=9||any(~isfinite(value.Times))
    error('lmz:QuadLoad:CompletionSchedule', ...
        'Completed event schedule must contain nine finite times.');
end
if ~isfield(value,'ReturnTime'),value.ReturnTime=value.Times(9);end
if ~isfield(value,'Chart'),value.Chart='legacy_named_cyclic';end
if ~isfield(value,'MinimumGap'),value.MinimumGap=0;end
if ~isfield(value,'OccurrenceOrder')
    [~,order]=sort(value.Times);value.OccurrenceOrder=value.Names(order);
end
end
function value=overridesFor(source,index)
value=struct();
if isempty(source),return,end
if iscell(source)
    if index<=numel(source)&&~isempty(source{index}),value=source{index};end
elseif isstruct(source)
    field=sprintf('stride%d',index);
    names=fieldnames(source);
    strideFields=cellfun(@(name)~isempty(regexp(name, ...
        '^stride[0-9]+$','once')),names);
    if any(strideFields)
        if ~all(strideFields)
            error('lmz:QuadLoad:ParameterOverrides', ...
                'Per-stride override containers cannot mix direct fields.');
        end
        if isfield(source,field),value=source.(field);else,return,end
    else
        value=source;
    end
else
    error('lmz:QuadLoad:ParameterOverrides','Parameter overrides are invalid.');
end
if ~isstruct(value)
    error('lmz:QuadLoad:ParameterOverrides','Stride override must be a struct.');
end
allowed={'PreSwingStiffness','PostSwingStiffness','EventSchedule'};
if ~all(ismember(fieldnames(value),allowed))
    error('lmz:MultiStride:UnknownEnergyEffect', ...
        'Unknown quad-load override has no transition or energy contract.');
end
end
function value=workFor(source,index)
if isempty(source)
    value=0;
elseif isscalar(source)
    value=source;
elseif isnumeric(source)&&index<=numel(source)
    value=source(index);
else
    error('lmz:QuadLoad:DeclaredWork','Declared work does not cover the stride.');
end
if ~isnumeric(value)||~isreal(value)||~isscalar(value)||~isfinite(value)
    error('lmz:QuadLoad:DeclaredWork','Declared work must be finite and real.');
end
end
function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end

function value=invokeCorrector(callback,plan,candidate,context,recoveryAttempt)
argumentCount=nargin(callback);
if argumentCount<0||argumentCount>=4
    value=callback(plan,candidate,context,recoveryAttempt);
else
    value=callback(plan,candidate,context);
end
end
function value=mergeStruct(first,second)
if ~isstruct(second),error('lmz:QuadLoad:ControlOverrides','Controls must be a struct.');end
value=first;names=fieldnames(second);
for index=1:numel(names),value.(names{index})=second.(names{index});end
end
