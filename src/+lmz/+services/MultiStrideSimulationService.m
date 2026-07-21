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
                if isempty(request.StridePlan)|| ...
                        sourcePeriodicStridePlan(request.StridePlan)
                    result=obj.simulatePeriodicSource(model,request,context);
                else
                    result=obj.simulateScientificPlan( ...
                        model,request,context);
                end
                return
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
                problem.getDecisionSchema().validateVector( ...
                    request.InitialDecision);
                decision=request.InitialDecision(:);
            end
            parameterValues=problem.getParameterSchema().defaults();
            count=request.NumberOfStrides;
            legacyDefaultPlan=isempty(request.StridePlan);
            if legacyDefaultPlan
                plan=tutorialDefaultPlan(request,decision,parameterValues);
            else
                plan=request.StridePlan.clone();
                if ~strcmp(plan.ModelId,'tutorial_hopper')
                    error('lmz:MultiStride:PlanModel', ...
                        'StridePlan model does not match tutorial_hopper.');
                end
                lmz.multistride.StridePlanValidator.validate(plan,true);
                if count>plan.CompletedStrideCount
                    error('lmz:MultiStride:HeterogeneousPlanIncomplete', ...
                        ['Explicit heterogeneous tutorial plans must supply ' ...
                        'every requested stride.']);
                elseif count<plan.CompletedStrideCount
                    plan=plan.truncate(count);
                end
            end
            initial=plan.InitialState;
            if isempty(initial),initial=[0;decision(4);decision(1);0];end
            model.getPhysicalStateSchema().validateVector(initial);
            time=[];states=[];modes={};records=struct([]);
            boundaries=repmat(struct('StrideIndex',0,'StartTime',0, ...
                'EndTime',0,'StartIndex',0,'EndIndex',0, ...
                'WorldTranslation',0),count,1);
            durations=zeros(count,1);impulses=zeros(count,1);offset=0;
            current=initial(:);
            for stride=1:count
                context.check();spec=plan.StrideSpecs(stride);
                [impactTime,returnTime]=tutorialSchedule(spec.EventSchedule);
                gravity=tutorialGravity(spec,plan,parameterValues(1));
                impulse=tutorialImpulse(spec,decision(3));
                localDecision=struct('initial_x',current(1), ...
                    'horizontal_speed',current(2), ...
                    'apex_height',current(3), ...
                    'initial_vertical_speed',current(4), ...
                    'stride_period',returnTime,'impact_time',impactTime, ...
                    'impulse',impulse, ...
                    'stride_length',current(2)*returnTime);
                hybridRequest=struct('TimeSpan',[0 returnTime], ...
                    'Parameters',struct('gravity',gravity, ...
                    'impulse',impulse),'Decision',localDecision, ...
                    'ProblemId','n_stride_simulation');
                one=lmz.simulation.HybridSimulator().simulate( ...
                    lmzmodels.tutorial_hopper.HopperSystem(), ...
                    hybridRequest,context,struct( ...
                    'MaximumStep',returnTime/80));
                keep=true(numel(one.Time),1);
                if stride>1,keep(1)=false;end
                startIndex=numel(time)+1;
                time=[time;one.Time(keep)+offset]; %#ok<AGROW>
                states=[states;one.States(keep,:)]; %#ok<AGROW>
                modes=[modes;one.Modes(keep)]; %#ok<AGROW>
                records=appendRecords(records,one.EventRecords, ...
                    offset,0,stride);
                boundaries(stride)=struct('StrideIndex',stride, ...
                    'StartTime',offset,'EndTime',offset+returnTime, ...
                    'StartIndex',startIndex,'EndIndex',numel(time), ...
                    'WorldTranslation',current(1));
                durations(stride)=returnTime;impulses(stride)=impulse;
                offset=offset+returnTime;current=one.States(end,:).';
            end
            observables=struct('horizontal_position',states(:,1), ...
                'height',states(:,3),'vertical_speed',states(:,4), ...
                'stride_count',count,'stride_durations',durations, ...
                'impulse_sequence',impulses);
            parameters=struct('gravity',parameterValues(1), ...
                'number_of_strides',count, ...
                'stride_plan',plan.toStruct());
            heterogeneous=numel(unique(round(durations*1e12)))>1|| ...
                numel(unique(round(impulses*1e12)))>1;
            diagnostics=struct('StrideCount',count, ...
                'StrideBoundaries',boundaries, ...
                'PerStrideBoundaries',boundaries, ...
                'CoordinateFrame','continuous_world', ...
                'HeterogeneousStridePlan',heterogeneous, ...
                'PerStrideSchedules',{arrayfun(@(item) ...
                plainSchedule(item.EventSchedule),plan.StrideSpecs, ...
                'UniformOutput',false)}, ...
                'ControlSequence',impulses, ...
                'StrictlyIncreasingTime',all(diff(time)>0), ...
                'HiddenTimingSolve',false);
            if legacyDefaultPlan
                diagnostics.StrideBoundaries=[boundaries.StartTime, ...
                    boundaries(end).EndTime];
            end
            simulation=lmz.api.SimulationResult(time, ...
                model.getPhysicalStateSchema(),states,modes, ...
                observables,parameters,diagnostics,struct( ...
                'modelId','tutorial_hopper', ...
                'problemId','n_stride_simulation', ...
                'source','explicit-heterogeneous-stride-plan'), ...
                'EventRecords',records);
            result=lmz.multistride.MultiStrideResult(plan, ...
                'Simulation',simulation,'CompletionStatus','complete', ...
                'Diagnostics',diagnostics);
            context.progress(1,sprintf( ...
                'Simulated %d explicit tutorial strides.',count));
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

        function result=simulateScientificPlan(~,model,request,context)
            modelId=model.getManifest().id;
            plan=request.StridePlan.clone();
            if ~strcmp(plan.ModelId,modelId)
                error('lmz:MultiStride:PlanModel', ...
                    'StridePlan model does not match %s.',modelId);
            end
            lmz.multistride.StridePlanValidator.validate(plan,true);
            if request.NumberOfStrides>plan.CompletedStrideCount
                error('lmz:MultiStride:HeterogeneousPlanIncomplete', ...
                    ['Explicit scientific plans must supply every ' ...
                    'requested stride.']);
            elseif request.NumberOfStrides<plan.CompletedStrideCount
                plan=plan.truncate(request.NumberOfStrides);
            end
            plan=plan.withPolicies(request.CompletionPolicy, ...
                request.EnergyPolicy,request.FailurePolicy);
            count=plan.CompletedStrideCount;
            parameterSchema=model.getParameterSchema();
            baseParameters=scientificParameterVector( ...
                parameterSchema,plan.DefaultPhysicalParameters, ...
                parameterSchema.defaults());
            time=[];states=[];forces=[];records=struct([]);
            modes=[];observables=struct();offset=0;previous=[];
            boundaries=repmat(struct('StrideIndex',0,'StartTime',0, ...
                'EndTime',0,'StartIndex',0,'EndIndex',0, ...
                'WorldTranslation',0),count,1);
            sections=cell(count,1);schedules=cell(count,1);
            appliedControls=cell(count,1);perStrideParameters=cell(count,1);
            interfaceNorms=zeros(count,1);contactNorms=zeros(count,1);
            sectionNorms=zeros(count,1);accepted=false(count,1);
            energyDiagnostics=cell(count,1);
            for stride=1:count
                context.check();spec=plan.StrideSpecs(stride);
                scientificSectionContinuity(plan,stride);
                candidate=scientificParameterVector(parameterSchema, ...
                    spec.PhysicalParameters,baseParameters);
                if norm(candidate-baseParameters,inf)> ...
                        256*eps(max(1,norm(baseParameters,inf)))
                    error('lmz:MultiStride:PerStridePhysicalParameters', ...
                        ['Scientific heterogeneous plans currently require ' ...
                        'invariant physical parameters; use the documented ' ...
                        'control override fields for stride-local changes.']);
                end
                [parameters,fixed,controls,controlChanged]= ...
                    scientificControls(modelId,candidate,spec);
                seedConfiguration=scientificSectionConfiguration( ...
                    spec,fixed,[],[],[],parameters);
                seedProblem=model.createProblem( ...
                    'periodic_orbit',seedConfiguration);
                if seedProblem.ApexEquivalent
                    error('lmz:MultiStride:ScientificApexPlan', ...
                        ['Explicit heterogeneous scientific plans require a ' ...
                        'non-apex direct section; source-periodic apex plans ' ...
                        'use the homogeneous fast path.']);
                end
                seed=seedProblem.SectionCodec.decode( ...
                    seedProblem.getDecisionSchema().defaults());
                [eventNames,eventTimes,returnTime]=scientificSchedule( ...
                    spec.EventSchedule,seedProblem.SectionCodec);
                initial=scientificInitialState(spec,plan,stride, ...
                    previous,seed.InitialState);
                if stride>1
                    initial(1)=previous(1);
                    previousCoordinates=seedProblem.StartSection.coordinates( ...
                        previous,model.getPhysicalStateSchema());
                    initialCoordinates=seedProblem.StartSection.coordinates( ...
                        initial,model.getPhysicalStateSchema());
                    interfaceNorms(stride)=norm( ...
                        initialCoordinates-previousCoordinates);
                    tolerance=max(1e-8,plan.EnergyPolicy.Tolerance);
                    if interfaceNorms(stride)>tolerance
                        error('lmz:MultiStride:InterfaceStateDiscontinuity', ...
                            ['Stride %d supplied interface state has defect ' ...
                            '%.16g (tolerance %.16g).'], ...
                            stride,interfaceNorms(stride),tolerance);
                    end
                end
                configuration=scientificSectionConfiguration(spec,fixed, ...
                    initial,eventNames,eventTimes,parameters);
                configuration.InitialReturnTime=returnTime;
                problem=model.createProblem('periodic_orbit',configuration);
                decision=problem.getDecisionSchema().defaults();
                evaluation=problem.evaluate( ...
                    decision,parameters,context,true);
                one=evaluation.Simulation;
                if isempty(one)
                    error('lmz:MultiStride:ScientificSimulationMissing', ...
                        'Stride %d did not return a physical simulation.',stride);
                end
                keep=true(numel(one.Time),1);
                if stride>1,keep(1)=false;end
                startIndex=numel(time)+1;
                time=[time;one.Time(keep)-one.Time(1)+offset]; %#ok<AGROW>
                states=[states;one.States(keep,:)]; %#ok<AGROW>
                if stride==1,modes=initializeRepeatedModes(one.Modes);end
                modes=appendModes(modes,one.Modes,keep,stride,numel(one.Time));
                observables=appendObservables( ...
                    observables,one.Observables,keep,numel(one.Time));
                if ~isempty(one.GroundReactionForces)
                    forces=[forces;one.GroundReactionForces(keep,:)]; %#ok<AGROW>
                end
                records=appendRecords(records,one.EventRecords,offset,0,stride);
                duration=one.Time(end)-one.Time(1);
                boundaries(stride)=struct('StrideIndex',stride, ...
                    'StartTime',offset,'EndTime',offset+duration, ...
                    'StartIndex',startIndex,'EndIndex',numel(time), ...
                    'WorldTranslation',one.States(1,1));
                offset=offset+duration;previous=one.States(end,:).';
                contactNorms(stride)=residualBlockNorm( ...
                    evaluation,'contact_geometry');
                sectionNorms(stride)=residualBlockNorm( ...
                    evaluation,'section_periodicity');
                accepted(stride)=logical(fieldOr( ...
                    evaluation.Feasibility,'AcceptedReturnCrossing',false));
                applied=problem.SectionCodec.decode(decision).EventSchedule;
                sections{stride}=struct('StartSectionId',spec.StartSectionId, ...
                    'StopSectionId',spec.StopSectionId, ...
                    'StartStateSide',spec.StartStateSide, ...
                    'StopStateSide',spec.StopStateSide);
                schedules{stride}=applied.toStruct();
                appliedControls{stride}=controls;
                perStrideParameters{stride}=parameters;
                energyDiagnostics{stride}=scientificEnergyDiagnostic( ...
                    modelId,one,plan.EnergyPolicy,spec.DeclaredWork, ...
                    controlChanged,stride);
                context.progress(0.95*stride/count,sprintf( ...
                    'Integrated scientific stride %d/%d.',stride,count));
            end
            observables.stride_count=count;
            observables.stride_durations=arrayfun(@(item) ...
                item.EndTime-item.StartTime,boundaries);
            parameters=parameterSchema.unpack(baseParameters);
            parameters.base_physical_parameters=baseParameters;
            parameters.per_stride_physical_parameters=perStrideParameters;
            parameters.per_stride_controls=appliedControls;
            parameters.stride_plan=plan.toStruct();
            parameters.number_of_strides=count;
            contactTolerance=1e-6;
            timingFeasible=accepted&contactNorms<=contactTolerance;
            diagnostics=struct('ModelId',modelId, ...
                'RequestedStrideCount',request.NumberOfStrides, ...
                'CompletedStrideCount',count, ...
                'HeterogeneousStridePlan',true, ...
                'HomogeneousClosedStrideRepetition',false, ...
                'DirectSectionIntegration',true, ...
                'ApexOracleUsedDuringStridePropagation',false, ...
                'PerStrideSections',{sections}, ...
                'PerStrideSchedules',{schedules}, ...
                'AppliedControlOverrides',{appliedControls}, ...
                'InterfaceDefectNorms',interfaceNorms, ...
                'ContactResidualNorms',contactNorms, ...
                'SectionResidualNorms',sectionNorms, ...
                'AcceptedSectionCrossings',accepted, ...
                'ContactResidualTolerance',contactTolerance, ...
                'PerStrideContactTimingsFeasible',timingFeasible, ...
                'AllInterfaceStatesContinuous',all(interfaceNorms<=1e-8), ...
                'AllContactTimingsFeasible',all(timingFeasible), ...
                'AllSectionsAccepted',all(accepted), ...
                'EnergyDiagnostics',{energyDiagnostics}, ...
                'StrideBoundaries',boundaries, ...
                'StrictlyIncreasingTime',all(diff(time)>0), ...
                'HiddenTimingSolve',false, ...
                'Qualification', ...
                ['Direct same-section returns; mixed section endpoints ' ...
                'require a transition multiple-shooting problem.']);
            provenance=struct('modelId',modelId, ...
                'problemId','n_stride_simulation', ...
                'source','explicit-scientific-heterogeneous-stride-plan', ...
                'directSectionIntegration',true);
            interim=lmz.api.SimulationResult(time, ...
                model.getPhysicalStateSchema(),states,modes,observables, ...
                parameters,diagnostics,provenance, ...
                'EventRecords',records,'GroundReactionForces',forces);
            simulation=attachKinematics(modelId,interim,model);
            result=lmz.multistride.MultiStrideResult(plan, ...
                'Simulation',simulation,'CompletionStatus','complete', ...
                'Diagnostics',diagnostics, ...
                'EnergyDiagnostics',energyDiagnostics);
            context.progress(1,sprintf( ...
                'Integrated %d explicit scientific strides.',count));
        end
    end
end

function plan=tutorialDefaultPlan(request,decision,parameters)
count=request.NumberOfStrides;
schedule=struct('Names',{{'impact','apex'}}, ...
    'Times',[decision(2)/2;decision(2)], ...
    'ReturnTime',decision(2),'OccurrenceOrder',{{'impact','apex'}}, ...
    'Chart','source_periodic_fixed','MinimumGap',0);
specs=lmz.multistride.StrideSpec.empty(0,1);
for stride=1:count
    specs(stride,1)=lmz.multistride.StrideSpec('Index',stride, ...
        'StartSectionId',request.StartSectionId, ...
        'StopSectionId',request.StopSectionId, ...
        'EventSchedule',schedule,'PhysicalParameters',parameters, ...
        'ControlParameters',struct('impulse',decision(3)), ...
        'InitialStateSource','previous_terminal_state', ...
        'CompletionStatus','completed');
end
plan=lmz.multistride.StridePlan('ModelId','tutorial_hopper', ...
    'ProblemId','n_stride_simulation','RequestedStrideCount',count, ...
    'InitialState',[0;decision(4);decision(1);0], ...
    'DefaultPhysicalParameters',parameters,'StrideSpecs',specs, ...
    'CompletionPolicy',request.CompletionPolicy, ...
    'EnergyPolicy',request.EnergyPolicy, ...
    'FailurePolicy',request.FailurePolicy,'Provenance',struct( ...
    'SourceProblemId','periodic_hop','PeriodicDecision',decision(:), ...
    'HomogeneousRepetition',true,'HiddenTimingSolve',false));
end

function [impactTime,returnTime]=tutorialSchedule(schedule)
if isa(schedule,'lmz.schedule.EventSchedule')
    impactTime=schedule.namedTimes({'impact'});
    returnTime=schedule.ReturnTime;
elseif isstruct(schedule)&&isscalar(schedule)&&isfield(schedule,'Times')
    times=schedule.Times(:);
    names=fieldOr(schedule,'Names',{});
    if ischar(names),names={names};end
    impactIndex=find(strcmp(names,'impact'),1);
    if isempty(impactIndex),impactIndex=1;end
    if isempty(times)||impactIndex>numel(times)
        error('lmz:MultiStride:TutorialSchedule', ...
            'Tutorial stride schedule is missing impact time.');
    end
    impactTime=times(impactIndex);
    returnTime=fieldOr(schedule,'ReturnTime',times(end));
else
    error('lmz:MultiStride:TutorialSchedule', ...
        'Tutorial strides require an explicit event schedule.');
end
if ~isnumeric(impactTime)||~isscalar(impactTime)|| ...
        ~isnumeric(returnTime)||~isscalar(returnTime)|| ...
        ~isfinite(impactTime)||~isfinite(returnTime)|| ...
        impactTime<=0||returnTime<=impactTime
    error('lmz:MultiStride:TutorialSchedule', ...
        'Tutorial impact and return times must be finite and ordered.');
end
end

function value=tutorialGravity(spec,plan,fallback)
value=dataScalar(spec.PhysicalParameters,'gravity',NaN);
if isnan(value)
    value=dataScalar(plan.DefaultPhysicalParameters,'gravity',fallback);
end
if ~isfinite(value)||value<=0
    error('lmz:MultiStride:TutorialGravity', ...
        'Tutorial gravity must be finite and positive.');
end
end

function value=tutorialImpulse(spec,fallback)
value=dataScalar(spec.ControlParameters,'impulse',fallback);
if ~isfinite(value)
    error('lmz:MultiStride:TutorialImpulse', ...
        'Tutorial impulse must be finite.');
end
end

function value=dataScalar(source,name,fallback)
value=fallback;
if isnumeric(source)&&isscalar(source)
    value=source;
elseif isnumeric(source)&&~isempty(source)
    value=source(1);
elseif isstruct(source)&&isscalar(source)&&isfield(source,name)&& ...
        isnumeric(source.(name))&&isscalar(source.(name))
    value=source.(name);
end
end

function value=plainSchedule(source)
if isobject(source)&&ismethod(source,'toStruct')
    value=source.toStruct();
else
    value=source;
end
end

function value=sourcePeriodicStridePlan(plan)
value=false;
if isempty(plan),value=true;return,end
if ~isa(plan,'lmz.multistride.StridePlan'),return,end
value=isfield(plan.Provenance,'PeriodicDecision');
if isfield(plan.Provenance,'HomogeneousRepetition')
    value=value&&logical(plan.Provenance.HomogeneousRepetition);
end
end

function value=scientificParameterVector(schema,source,fallback)
if isempty(source)||(isstruct(source)&&isempty(fieldnames(source)))
    value=fallback(:);
elseif isnumeric(source)
    value=source(:);
elseif isstruct(source)&&isscalar(source)
    value=schema.pack(source);
else
    error('lmz:MultiStride:ScientificParameters', ...
        'Scientific physical parameters must be a vector or complete struct.');
end
schema.validateVector(value);
end

function [parameters,fixed,applied,changed]= ...
        scientificControls(modelId,parameters,spec)
source=struct();
if ~isempty(spec.ControlParameters)
    if ~isstruct(spec.ControlParameters)||~isscalar(spec.ControlParameters)
        error('lmz:MultiStride:UnsupportedControlOverride', ...
            'Scientific stride controls must be a scalar named struct.');
    end
    source=spec.ControlParameters;
end
overrideNames=fieldnames(spec.ParameterOverrides);
for index=1:numel(overrideNames)
    source.(overrideNames{index})=spec.ParameterOverrides.(overrideNames{index});
end
switch modelId
    case 'slip_quadruped'
        allowed={'k_leg','k_swing','k_r_leg'};
        schema=lmzmodels.slip_quadruped.ParameterSchema.create();
        base=parameters;
        for index=1:numel(fieldnames(source))
            names=fieldnames(source);name=names{index};
            validateControlName(source,name,allowed);
            parameters(schema.indexOf(name))=source.(name);
        end
        schema.validateVector(parameters);
        unpacked=schema.unpack(parameters);
        applied=struct('k_leg',unpacked.k_leg, ...
            'k_swing',unpacked.k_swing,'k_r_leg',unpacked.k_r_leg);
        fixed=struct();changed=norm(parameters-base,inf)>0;
    case 'slip_biped'
        allowed={'k_leg','omega_swing'};
        fixed=struct('k_leg',20,'omega_swing',6.5);
        names=fieldnames(source);
        for index=1:numel(names)
            name=names{index};validateControlName(source,name,allowed);
            fixed.(name)=source.(name);
        end
        applied=fixed;
        changed=fixed.k_leg~=20||fixed.omega_swing~=6.5;
    otherwise
        error('lmz:MultiStride:ScientificControlModel', ...
            'Scientific controls are unavailable for %s.',modelId);
end
end

function validateControlName(source,name,allowed)
if ~any(strcmp(name,allowed))||~isnumeric(source.(name))|| ...
        ~isscalar(source.(name))||~isfinite(source.(name))||source.(name)<=0
    error('lmz:MultiStride:UnsupportedControlOverride', ...
        'Unsupported or invalid stride-local control override %s.',name);
end
end

function configuration=scientificSectionConfiguration( ...
        spec,fixed,initial,eventNames,eventTimes,parameters)
configuration=struct('StartSectionId',spec.StartSectionId, ...
    'StopSectionId',spec.StopSectionId, ...
    'StartStateSide',spec.StartStateSide, ...
    'StopStateSide',spec.StopStateSide, ...
    'SourceParameterValues',parameters(:));
if ~isempty(fixed),configuration.FixedConfiguration=fixed;end
if ~isempty(initial)
    configuration.InitialSectionState=initial(:);
    configuration.InitialEventNames=eventNames;
    configuration.InitialEventTimes=eventTimes(:);
end
end

function [eventNames,eventTimes,returnTime]= ...
        scientificSchedule(source,codec)
if isa(source,'lmz.schedule.EventSchedule')
    schedule=source;
    names=schedule.names();times=schedule.times();
    returnTime=schedule.ReturnTime;
elseif isstruct(source)&&isscalar(source)&&isfield(source,'Occurrences')
    schedule=lmz.schedule.EventSchedule.fromStruct(source);
    names=schedule.names();times=schedule.times();
    returnTime=schedule.ReturnTime;
elseif isstruct(source)&&isscalar(source)&& ...
        all(isfield(source,{'Names','Times','ReturnTime'}))
    names=source.Names;if ischar(names),names={names};end
    times=source.Times(:);returnTime=source.ReturnTime;
    if ~iscell(names)||numel(names)~=numel(times)
        error('lmz:MultiStride:ScientificSchedule', ...
            'Stride schedule names and times must have equal lengths.');
    end
else
    error('lmz:MultiStride:ScientificSchedule', ...
        'Each scientific stride requires an explicit named event schedule.');
end
if ~isnumeric(returnTime)||~isscalar(returnTime)|| ...
        ~isfinite(returnTime)||returnTime<=0
    error('lmz:MultiStride:ScientificSchedule', ...
        'Stride return time must be finite and positive.');
end
eventNames=codec.EventNames;eventTimes=zeros(numel(eventNames),1);
for index=1:numel(eventNames)
    if index==codec.EndpointEventIndex
        eventTimes(index)=returnTime;continue
    end
    match=find(strcmp(eventNames{index},names),1);
    if isempty(match)
        error('lmz:MultiStride:ScientificScheduleEvent', ...
            'Stride schedule is missing required event %s.',eventNames{index});
    end
    eventTimes(index)=times(match);
end
interior=eventTimes;
if codec.EndpointEventIndex>0
    interior(codec.EndpointEventIndex)=[];
end
if any(~isfinite(eventTimes))||any(interior<=0)||any(interior>=returnTime)
    error('lmz:MultiStride:ScientificScheduleOrder', ...
        'Stride contact times must lie strictly inside the return interval.');
end
end

function initial=scientificInitialState(spec,plan,stride,previous,fallback)
if ~isempty(spec.InitialSectionState)
    initial=spec.InitialSectionState(:);
elseif stride==1&&~isempty(plan.InitialState)
    initial=plan.InitialState(:);
elseif stride>1&&~isempty(previous)
    initial=previous(:);
else
    initial=fallback(:);
end
end

function scientificSectionContinuity(plan,stride)
spec=plan.StrideSpecs(stride);
if ~strcmp(spec.StartSectionId,spec.StopSectionId)|| ...
        ~strcmp(spec.StartStateSide,spec.StopStateSide)
    error('lmz:Shooting:TransitionProblemRequired', ...
        ['A direct stride specification currently requires the same start ' ...
        'and stop section and state side. Use transition multiple shooting ' ...
        'for mixed endpoints.']);
end
if stride>1
    previous=plan.StrideSpecs(stride-1);
    if ~strcmp(previous.StopSectionId,spec.StartSectionId)|| ...
            ~strcmp(previous.StopStateSide,spec.StartStateSide)
        error('lmz:MultiStride:SectionInterface', ...
            'Consecutive stride section identifiers and sides must match.');
    end
end
end

function value=residualBlockNorm(evaluation,name)
value=0;
for index=1:numel(evaluation.ResidualBlocks)
    if strcmp(evaluation.ResidualBlocks(index).Name,name)
        value=norm(evaluation.ResidualBlocks(index).Values);return
    end
end
end

function value=scientificEnergyDiagnostic( ...
        modelId,simulation,policy,declaredWork,controlChanged,stride)
if strcmp(modelId,'slip_biped')&& ...
        isfield(simulation.Observables,'total_energy')&& ...
        ~isempty(simulation.Observables.total_energy)
    energy=simulation.Observables.total_energy;
    delta=energy(end)-energy(1);
    value=policy.assess(delta,declaredWork,true);
    value.StrideIndex=stride;value.EnergyAvailable=true;
    value.Qualification='measured_source_total_energy';
    return
end
if ~strcmp(policy.Id,'allow_non_neutral')&& ...
        (controlChanged||declaredWork~=0)
    error('lmz:MultiStride:UnknownEnergyEffect', ...
        ['Stride %d changes controls or declares work, but this source ' ...
        'model does not expose a total-energy channel. Select ' ...
        'allow_non_neutral explicitly to retain qualified diagnostics.'], ...
        stride);
end
value=struct('Policy',policy.Id,'StrideIndex',stride, ...
    'EnergyAvailable',false,'EnergyDelta',zeros(0,1), ...
    'DeclaredWork',declaredWork,'Mismatch',zeros(0,1), ...
    'Tolerance',policy.Tolerance,'EffectKnown',~controlChanged, ...
    'Accepted',true,'Qualification','source_total_energy_not_exposed');
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
