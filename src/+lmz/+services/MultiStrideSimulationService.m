classdef MultiStrideSimulationService
    %MULTISTRIDESIMULATIONSERVICE Complete and simulate an explicit N plan.
    methods
        function result=simulate(obj,model,request,context)
            if nargin<4||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if ~isa(model,'lmz.api.LeggedModel')|| ...
                    ~isa(request,'lmz.multistride.MultiStrideRequest')
                error('lmz:MultiStride:SimulationRequest', ...
                    'A model and MultiStrideRequest are required.');
            end
            modelId=model.getManifest().id;
            if strcmp(modelId,'tutorial_hopper')
                result=obj.simulateTutorial(model,request,context);return
            end
            if any(strcmp(modelId,{'slip_quadruped','slip_biped'}))
                result=obj.simulatePeriodicSource(model,request,context);return
            end
            if ~strcmp(modelId,'slip_quad_load')
                error('lmz:MultiStride:UnsupportedModel', ...
                    'Native plan completion is unavailable for %s.',modelId);
            end
            builder=lmzmodels.slip_quad_load.QuadLoadStridePlanBuilder();
            plan=obj.initialPlan(builder,request,context);
            completionOptions=struct('ProviderCallback',request.ProviderCallback, ...
                'ParameterOverrides',request.ParameterOverrides, ...
                'DeclaredWork',request.DeclaredWork, ...
                'TimingCorrector',@(p,s,c,r)obj.correctLoadTiming( ...
                model,p,s,c,r), ...
                'CheckpointFcn',@(value)context.checkpoint(value));
            completionOptions.RecoveryLadder= ...
                quadLoadRecoveryLadder(context.RandomSeed);
            completion=lmz.multistride.StridePlanCompletionService().complete( ...
                builder,plan,completionOptions,context);
            if completion.Partial
                result=completion;return
            end
            plan=completion.Plan;
            xAccum=lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(plan);
            simulator=lmzmodels.slip_quad_load.MultiStrideSimulator();
            raw=simulator.runRaw(xAccum,context,false);
            localSimulation=simulator.run(xAccum,context, ...
                struct('EnforceEventTiming',false));
            [simulation,worldDiagnostics]=obj.worldLoadSimulation( ...
                localSimulation,raw,plan);
            timingNorms=zeros(raw.StrideCount,1);
            for stride=1:raw.StrideCount
                rows=(stride-1)*9+(1:9);
                timingNorms(stride)=norm(raw.FirstNineResiduals(rows));
            end
            diagnostics=struct('ModelId',modelId, ...
                'RequestedStrideCount',request.NumberOfStrides, ...
                'CompletedStrideCount',plan.CompletedStrideCount, ...
                'CompletionPolicy',plan.CompletionPolicy.Id, ...
                'EnergyPolicy',plan.EnergyPolicy.Id, ...
                'TimingResidualNorms',timingNorms, ...
                'TimingResidualTolerance',1e-6, ...
                'PerStrideTimingFeasible',timingNorms<=1e-6, ...
                'AllContactTimingsFeasible',all(timingNorms<=1e-6), ...
                'StrideBoundaries',worldDiagnostics.StrideBoundaries, ...
                'WorldTranslations',worldDiagnostics.WorldTranslations, ...
                'StrictlyIncreasingTime',all(diff(simulation.Time)>0), ...
                'ExactLegacyLength',numel(xAccum), ...
                'RequestProvenance',request.Provenance);
            if isfield(request.Provenance,'InputTruncation')
                diagnostics.InputTruncated=true;
                diagnostics.InputTruncation= ...
                    request.Provenance.InputTruncation;
            else
                diagnostics.InputTruncated=false;
            end
            result=lmz.multistride.MultiStrideResult(plan, ...
                'Simulation',simulation,'CompletionStatus','complete', ...
                'Diagnostics',diagnostics,'Checkpoints',completion.Checkpoints, ...
                'XAccum',xAccum, ...
                'EnergyDiagnostics',completion.EnergyDiagnostics);
            context.progress(1,sprintf('Simulated %d completed strides.', ...
                plan.CompletedStrideCount));
        end
    end

    methods (Access=private)
        function plan=initialPlan(~,builder,request,context)
            if isempty(request.StridePlan)
                plan=builder.initialPlan(request,context);
            else
                plan=request.StridePlan.clone();
                if ~strcmp(plan.ModelId,'slip_quad_load')
                    error('lmz:MultiStride:PlanModel', ...
                        'StridePlan model does not match slip_quad_load.');
                end
            end
            if request.NumberOfStrides<plan.CompletedStrideCount
                plan=plan.truncate(request.NumberOfStrides);
            elseif request.NumberOfStrides>plan.CompletedStrideCount
                plan=plan.withRequestedStrideCount(request.NumberOfStrides);
            end
            plan=plan.withPolicies(request.CompletionPolicy, ...
                request.EnergyPolicy,request.FailurePolicy);
        end

        function corrected=correctLoadTiming(~,model,plan,candidate,context, ...
                recoveryAttempt)
            if nargin<6||isempty(recoveryAttempt)
                recoveryAttempt=struct('Strategy','baseline');
            end
            prefix=plan.truncate(plan.CompletedStrideCount);
            prefixVector=lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(prefix);
            raw=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
                prefixVector,context,false);
            transition=lmzmodels.slip_quad_load.QuadLoadStrideTransitionMap();
            local=transition.map(raw.LegacyStates(end,:).', ...
                candidate.PhysicalParameters);
            fixedState=[local(2:14);local(15:16)];
            invariant=candidate.PhysicalParameters.TransitionInvariantVector(:);
            controls=candidate.ControlParameters;
            strategy=fieldOr(recoveryAttempt,'Strategy','baseline');
            if strcmp(strategy,'parameter_homotopy')
                fraction=fieldOr(recoveryAttempt,'HomotopyFraction',0.5);
                previous=plan.StrideSpecs(end).ControlParameters;
                controls.PreSwingStiffness=(1-fraction)* ...
                    previous.PreSwingStiffness(:)+fraction* ...
                    controls.PreSwingStiffness(:);
                controls.PostSwingStiffness=(1-fraction)* ...
                    previous.PostSwingStiffness(:)+fraction* ...
                    controls.PostSwingStiffness(:);
            end
            physical=quadLoadTimingPhysical(invariant,controls);
            times=candidate.EventSchedule.Times(:);
            times=times*fieldOr(recoveryAttempt,'TimeScale',1);
            provider=lmzmodels.slip_quad_load.ContactConstraintProvider();
            schedule=lmz.schedule.EventSchedule.fromCyclic( ...
                provider.eventNames(),times(1:8),times(9), ...
                'StartSectionId',candidate.StartSectionId, ...
                'StopSectionId',candidate.StopSectionId);
            problem=model.createProblem('section_return_timing',struct( ...
                'InitialState',fixedState,'PhysicalParameters',physical, ...
                'EventSchedule',schedule));
            seedEvaluation=problem.evaluate( ...
                problem.getDecisionSchema().defaults(),[],context,false);
            if seedEvaluation.ScaledResidualNorm>0.25
                error('lmz:MultiStride:TimingSeedOutsideTrustRegion', ...
                    ['Stride %d timing seed residual %.16g exceeds the ' ...
                    'validated correction trust region.'], ...
                    candidate.Index,seedEvaluation.ScaledResidualNorm);
            end
            solveOptions=struct('MaxIterations',80, ...
                'MaxFunctionEvaluations',500);
            if strcmp(strategy,'deterministic_multistart')
                solveOptions.MultistartCount=fieldOr( ...
                    recoveryAttempt,'StartCount',4);
                solveOptions.MultistartScale=0.05;
            end
            timing=lmz.services.ContactTimingService().solve( ...
                problem,schedule,solveOptions,context);
            if strcmp(strategy,'parameter_homotopy')&&fraction<1
                finalPhysical=quadLoadTimingPhysical( ...
                    invariant,candidate.ControlParameters);
                finalProblem=model.createProblem('section_return_timing',struct( ...
                    'InitialState',fixedState, ...
                    'PhysicalParameters',finalPhysical, ...
                    'EventSchedule',timing.SolvedSchedule));
                finalSeed=finalProblem.evaluate( ...
                    finalProblem.getDecisionSchema().defaults(),[], ...
                    context,false);
                if finalSeed.ScaledResidualNorm>0.25
                    error('lmz:MultiStride:TimingHomotopyFinalStage', ...
                        ['Stride %d intermediate homotopy timing residual ' ...
                        '%.16g is outside the final-parameter trust region.'], ...
                        candidate.Index,finalSeed.ScaledResidualNorm);
                end
                timing=lmz.services.ContactTimingService().solve( ...
                    finalProblem,timing.SolvedSchedule,solveOptions,context);
            end
            if isempty(timing.Simulation)|| ...
                    any(~isfinite(timing.TerminalState(:)))|| ...
                    norm([timing.ContactResiduals;timing.SectionResidual])>1e-6
                residualNorm=norm([timing.ContactResiduals; ...
                    timing.SectionResidual]);
                error('lmz:MultiStride:TimingCorrectionFailed', ...
                    ['Stride %d timing correction did not find a finite ' ...
                    'section return (residual %.16g).'], ...
                    candidate.Index,residualNorm);
            end
            solved=[timing.SolvedSchedule.namedTimes(provider.eventNames()); ...
                timing.SolvedSchedule.ReturnTime];
            corrected=candidate.EventSchedule;corrected.Times=solved;
            corrected.ReturnTime=solved(9);
            names=corrected.Names(1:9);[~,order]=sort(solved);
            corrected.OccurrenceOrder=names(order).';
            corrected.TimingDiagnostics=timing.SolverDiagnostics;
            corrected.RecoveryAttempt=recoveryAttempt;
            corrected.ContactResidualNorm=norm([timing.ContactResiduals; ...
                timing.SectionResidual]);
        end

        function [simulation,diagnostics]=worldLoadSimulation(~,local,raw,plan)
            count=raw.StrideCount;translations=zeros(count,1);
            for stride=2:count
                previous=raw.StrideBoundaries(stride-1);
                displacement=raw.LegacyStates(previous.RawEndIndex,1);
                translations(stride)=translations(stride-1)+displacement;
            end
            states=local.States;strideIndex=local.Modes.stride_index(:);
            for stride=1:count
                rows=strideIndex==stride;
                states(rows,1)=states(rows,1)+translations(stride);
                states(rows,15)=states(rows,15)+translations(stride);
            end
            records=local.EventRecords;
            for index=1:numel(records)
                stride=records(index).StrideIndex;shift=translations(stride);
                records(index).State=shiftState(records(index).State,shift);
                records(index).PreState=shiftState(records(index).PreState,shift);
                records(index).PostState=shiftState(records(index).PostState,shift);
            end
            boundaries=raw.StrideBoundaries;
            for stride=1:count
                boundaries(stride).WorldTranslation=translations(stride);
            end
            observables=local.Observables;observables.load_position=states(:,15);
            parameters=local.Parameters;
            parameters.stride_plan=plan.toStruct();
            parameters.per_stride_sections=arrayfun(@(s)struct( ...
                'StartSectionId',s.StartSectionId, ...
                'StopSectionId',s.StopSectionId),plan.StrideSpecs);
            details=local.Diagnostics;details.CoordinateFrame='continuous_world';
            details.LocalStates=local.States;
            details.StrideBoundaries=boundaries;
            details.PerStrideSchedules=arrayfun(@(s)s.EventSchedule, ...
                plan.StrideSpecs,'UniformOutput',false);
            interim=lmz.api.SimulationResult(local.Time,local.StateSchema,states, ...
                local.Modes,observables,parameters,details,local.Provenance, ...
                'EventRecords',records, ...
                'GroundReactionForces',local.GroundReactionForces);
            simulation=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
                interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
                interim.Diagnostics,interim.Provenance, ...
                'EventRecords',interim.EventRecords, ...
                'GroundReactionForces',interim.GroundReactionForces, ...
                'Kinematics',lmzmodels.slip_quad_load.KinematicsProvider.compute(interim));
            diagnostics=struct('WorldTranslations',translations, ...
                'StrideBoundaries',boundaries);
        end

        function result=simulateTutorial(~,model,request,context)
            problem=model.createProblem('periodic_hop',struct());
            decision=problem.getDecisionSchema().defaults();
            if ~isempty(request.InitialDecision)
                problem.getDecisionSchema().validateVector(request.InitialDecision);
                decision=request.InitialDecision(:);
            end
            parameterValues=problem.getParameterSchema().defaults();
            one=problem.simulateDecision(decision,parameterValues,context, ...
                'n_stride_simulation');
            count=request.NumberOfStrides;time=[];states=[];modes={};records=struct([]);
            for stride=1:count
                shiftedTime=one.Time+(stride-1)*one.Time(end);
                shiftedStates=one.States;shiftedStates(:,1)=shiftedStates(:,1)+ ...
                    (stride-1)*one.States(end,1);
                keep=true(size(shiftedTime));if stride>1,keep(1)=false;end
                time=[time;shiftedTime(keep)];states=[states;shiftedStates(keep,:)]; %#ok<AGROW>
                modes=[modes;one.Modes(keep)]; %#ok<AGROW>
                strideRecords=one.EventRecords;
                for index=1:numel(strideRecords)
                    strideRecords(index).Time=strideRecords(index).Time+ ...
                        (stride-1)*one.Time(end);
                    strideRecords(index).PreState(1)= ...
                        strideRecords(index).PreState(1)+(stride-1)*one.States(end,1);
                    strideRecords(index).PostState(1)= ...
                        strideRecords(index).PostState(1)+(stride-1)*one.States(end,1);
                    strideRecords(index).StrideIndex=stride;
                end
                if isempty(records),records=strideRecords;else,records=[records;strideRecords];end %#ok<AGROW>
            end
            simulation=lmz.api.SimulationResult(time,one.StateSchema,states,modes, ...
                struct('stride_count',count),one.Parameters, ...
                struct('StrideCount',count,'CoordinateFrame','continuous_world'), ...
                struct('modelId','tutorial_hopper','problemId','n_stride_simulation'), ...
                'EventRecords',records);
            specs=lmz.multistride.StrideSpec.empty(0,1);
            for stride=1:count
                specs(stride,1)=lmz.multistride.StrideSpec('Index',stride, ...
                    'EventSchedule',struct('Names',{{'impact','apex'}}, ...
                    'Times',[decision(2)/2;decision(2)]), ...
                    'PhysicalParameters',parameterValues, ...
                    'ControlParameters',struct('impulse',decision(3)), ...
                    'CompletionStatus','completed');
            end
            plan=lmz.multistride.StridePlan('ModelId','tutorial_hopper', ...
                'ProblemId','n_stride_simulation', ...
                'RequestedStrideCount',count,'InitialState',one.States(1,:).', ...
                'DefaultPhysicalParameters',parameterValues,'StrideSpecs',specs, ...
                'CompletionPolicy',request.CompletionPolicy, ...
                'EnergyPolicy',request.EnergyPolicy);
            result=lmz.multistride.MultiStrideResult(plan, ...
                'Simulation',simulation,'CompletionStatus','complete', ...
                'Diagnostics',struct('StrictlyIncreasingTime',all(diff(time)>0), ...
                'StrideBoundaries',(0:count)*one.Time(end)));
        end

        function result=simulatePeriodicSource(~,model,request,context)
            modelId=model.getManifest().id;
            problem=model.createProblem('periodic_apex',struct());
            decision=sourceDecision(problem,request,modelId);
            parameters=problem.getParameterSchema().defaults();
            evaluation=problem.evaluate(decision,parameters,context,true);
            one=evaluation.Simulation;
            [simulation,boundaries]=repeatSimulation( ...
                modelId,one,request.NumberOfStrides,model);
            plan=periodicPlan(modelId,request,decision,parameters,one);
            diagnostics=struct('ModelId',modelId, ...
                'SourceProblemId','periodic_apex', ...
                'RequestedStrideCount',request.NumberOfStrides, ...
                'CompletedStrideCount',request.NumberOfStrides, ...
                'StrideBoundaries',boundaries, ...
                'SourceResidualNorm',evaluation.ScaledResidualNorm, ...
                'StrictlyIncreasingTime',all(diff(simulation.Time)>0), ...
                'HomogeneousClosedStrideRepetition',true, ...
                'HiddenTimingSolve',false);
            result=lmz.multistride.MultiStrideResult(plan, ...
                'Simulation',simulation,'CompletionStatus','complete', ...
                'Diagnostics',diagnostics);
            context.progress(1,sprintf( ...
                'Repeated %d source-periodic strides.',request.NumberOfStrides));
        end
    end
end

function value=shiftState(value,translation)
wasRow=isrow(value);value=value(:);value([1 15])=value([1 15])+translation;
if wasRow,value=value.';end
end

function decision=sourceDecision(problem,request,modelId)
if isempty(request.StridePlan)
    decision=problem.getDecisionSchema().defaults();
    if ~isempty(request.InitialDecision)
        decision=request.InitialDecision(:);
    end
else
    plan=request.StridePlan;
    if ~strcmp(plan.ModelId,modelId)|| ...
            ~isfield(plan.Provenance,'PeriodicDecision')
        error('lmz:MultiStride:PeriodicPlanDecision', ...
            ['A source-periodic StridePlan must match the model and retain ' ...
            'Provenance.PeriodicDecision.']);
    end
    decision=plan.Provenance.PeriodicDecision(:);
end
problem.getDecisionSchema().validateVector(decision);
end

function plan=periodicPlan(modelId,request,decision,parameters,simulation)
count=request.NumberOfStrides;
records=simulation.EventRecords;
names=cell(numel(records),1);times=zeros(numel(records),1);
for index=1:numel(records)
    names{index}=eventName(records(index),index);
    times(index)=records(index).Time;
end
schedule=struct('Names',{names},'Times',times, ...
    'ReturnTime',simulation.Time(end),'OccurrenceOrder',{names}, ...
    'Chart','source_periodic_fixed','MinimumGap',0);
specs=lmz.multistride.StrideSpec.empty(0,1);
for stride=1:count
    specs(stride,1)=lmz.multistride.StrideSpec('Index',stride, ...
        'StartSectionId',request.StartSectionId, ...
        'StopSectionId',request.StopSectionId, ...
        'EventSchedule',schedule,'PhysicalParameters',parameters, ...
        'ControlParameters',struct(), ...
        'InitialStateSource','source_periodic_symmetry_return', ...
        'CompletionStatus','completed','Diagnostics',struct( ...
        'FixedSchedule',true,'HiddenTimingSolve',false));
end
provenance=struct('SourceProblemId','periodic_apex', ...
    'PeriodicDecision',decision(:),'HomogeneousRepetition',true, ...
    'HiddenTimingSolve',false);
plan=lmz.multistride.StridePlan('ModelId',modelId, ...
    'ProblemId','n_stride_simulation','RequestedStrideCount',count, ...
    'InitialState',simulation.States(1,:).', ...
    'DefaultPhysicalParameters',parameters,'StrideSpecs',specs, ...
    'CompletionPolicy',request.CompletionPolicy, ...
    'EnergyPolicy',request.EnergyPolicy,'FailurePolicy',request.FailurePolicy, ...
    'Provenance',provenance);
end

function [result,boundaries]=repeatSimulation(modelId,one,count,model)
period=one.Time(end)-one.Time(1);
translation=one.States(end,1)-one.States(1,1);
time=[];states=[];forces=[];records=struct([]);
modes=initializeRepeatedModes(one.Modes);
observables=initializeRepeatedObservables(one.Observables);
boundaries=repmat(struct('StrideIndex',0,'StartTime',0,'EndTime',0, ...
    'StartIndex',0,'EndIndex',0,'WorldTranslation',0),count,1);
for stride=1:count
    keep=true(numel(one.Time),1);
    if stride>1
        keep(1)=false;
    end
    offset=(stride-1)*period;
    shift=(stride-1)*translation;
    startIndex=numel(time)+1;
    time=[time;one.Time(keep)-one.Time(1)+offset]; %#ok<AGROW>
    state=one.States(keep,:);state(:,1)=state(:,1)+shift;
    states=[states;state]; %#ok<AGROW>
    modes=appendModes(modes,one.Modes,keep,stride,numel(one.Time));
    observables=appendObservables( ...
        observables,one.Observables,keep,numel(one.Time));
    if ~isempty(one.GroundReactionForces)
        forces=[forces;one.GroundReactionForces(keep,:)]; %#ok<AGROW>
    end
    records=appendRecords(records,one.EventRecords,offset,shift,stride);
    boundaries(stride)=struct('StrideIndex',stride, ...
        'StartTime',offset,'EndTime',offset+period, ...
        'StartIndex',startIndex,'EndIndex',numel(time), ...
        'WorldTranslation',shift);
end
observables.stride_count=count;
observables.stride_durations=repmat(period,count,1);
parameters=one.Parameters;
parameters.number_of_strides=count;
diagnostics=one.Diagnostics;
diagnostics.StrideBoundaries=boundaries;
diagnostics.CoordinateFrame='continuous_world';
diagnostics.HiddenTimingSolve=false;
provenance=one.Provenance;
provenance.problemId='n_stride_simulation';
interim=lmz.api.SimulationResult(time,one.StateSchema,states,modes, ...
    observables,parameters,diagnostics,provenance, ...
    'EventRecords',records,'GroundReactionForces',forces);
result=attachKinematics(modelId,interim,model);
end

function value=initializeRepeatedModes(source)
if iscell(source)
    value=cell(0,1);
elseif isstruct(source)
    value=struct();
else
    value=[];
end
end

function target=appendModes(target,source,keep,stride,sampleCount)
if iscell(source)
    target=[target;source(keep)];return
end
if ~isstruct(source)
    target=source;return
end
names=fieldnames(source);
for index=1:numel(names)
    name=names{index};value=source.(name);
    if numel(value)==sampleCount
        previous=fieldOr(target,name,emptyRows(value));
        target.(name)=[previous;value(keep)];
    elseif ~isfield(target,name)
        target.(name)=value;
    end
end
target.stride_index=[fieldOr(target,'stride_index',[]); ...
    repmat(stride,sum(keep),1)];
end

function value=initializeRepeatedObservables(~)
value=struct();
end

function target=appendObservables(target,source,keep,sampleCount)
if ~isstruct(source)
    return
end
names=fieldnames(source);
for index=1:numel(names)
    name=names{index};value=source.(name);
    if (isnumeric(value)||islogical(value))&&size(value,1)==sampleCount
        previous=fieldOr(target,name,emptyRows(value));
        target.(name)=[previous;value(keep,:)];
    elseif ~isfield(target,name)
        target.(name)=value;
    end
end
end

function target=appendRecords(target,source,timeShift,stateShift,stride)
for index=1:numel(source)
    record=source(index);record.Time=record.Time+timeShift;
    record.StrideIndex=stride;
    fields={'State','PreState','PostState'};
    for fieldIndex=1:numel(fields)
        name=fields{fieldIndex};
        if isfield(record,name)&&~isempty(record.(name))
            wasRow=isrow(record.(name));value=record.(name)(:);
            value(1)=value(1)+stateShift;
            if wasRow,value=value.';end
            record.(name)=value;
        end
    end
    if isempty(target),target=record;else,target(end+1,1)=record;end %#ok<AGROW>
end
end

function value=eventName(record,index)
if isfield(record,'Name')
    value=record.Name;
elseif isfield(record,'Id')
    value=record.Id;
else
    value=sprintf('event_%d',index);
end
value=regexprep(char(value),'[^A-Za-z0-9_]','_');
if isempty(value)||~isletter(value(1))
    value=['event_' value];
end
end

function result=attachKinematics(modelId,interim,model)
if strcmp(modelId,'slip_quadruped')
    kinematics=lmzmodels.slip_quadruped.KinematicsProvider.compute(interim);
elseif strcmp(modelId,'slip_biped')
    kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(interim);
else
    kinematics=model.kinematics(interim);
    if isa(kinematics,'lmz.api.SimulationResult')
        kinematics=struct();
    end
end
result=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
    interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
    interim.Diagnostics,interim.Provenance, ...
    'EventRecords',interim.EventRecords, ...
    'GroundReactionForces',interim.GroundReactionForces, ...
    'Kinematics',kinematics);
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name)
    value=source.(name);
else
    value=fallback;
end
end

function value=emptyRows(source)
value=source([],:);
end

function value=quadLoadRecoveryLadder(randomSeed)
value={struct('Strategy','baseline','SeedPolicy','source_prediction'), ...
    struct('Strategy','step_reduction','StepScale',0.5, ...
    'TimeScale',0.98,'SeedPolicy','reduced_timing_step'), ...
    struct('Strategy','parameter_homotopy', ...
    'HomotopyFraction',0.5,'SeedPolicy','control_parameter_homotopy'), ...
    struct('Strategy','deterministic_multistart','StartCount',4, ...
    'RandomSeed',randomSeed,'StartIndex',1,'TimeScale',0.95, ...
    'SeedPolicy','deterministic_scaled_start')};
end

function value=quadLoadTimingPhysical(invariant,controls)
quadruped=[invariant(1);controls.PreSwingStiffness(:); ...
    controls.PostSwingStiffness(:);invariant(2:6)];
value=[quadruped;invariant(7:12)];
end
