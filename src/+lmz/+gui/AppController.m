classdef AppController < handle
    %APPCONTROLLER Headless coordinator for demo and RoadMap workflows.
    properties (SetAccess=private)
        Registry
        Workflows
        State
        Context
        Events
    end
    properties (Access=private)
        StateListeners = {}
    end
    methods
        function obj=AppController(registry,context,eventBus)
            if nargin<1,registry=lmz.registry.ModelRegistry.discover();end
            if nargin<2,context=lmz.api.RunContext.synchronous(0);end
            if nargin<3||isempty(eventBus),eventBus=lmz.gui.PresentationEventBus();end
            obj.Registry=registry;
            obj.Workflows=lmz.workflow.WorkflowRegistry. ...
                fromModelRegistry(registry);
            obj.Context=context;obj.Events=eventBus;
            obj.State=lmz.gui.AppState();obj.observeState();
            ids=obj.Registry.listModels();obj.selectModel(ids{1});
        end
        function ids=modelIds(obj),ids=obj.Registry.listModels();end
        function ids=workflowIds(obj)
            ids=obj.Workflows.list(obj.State.ModelId);
        end
        function values=workflowDescriptors(obj)
            ids=obj.workflowIds();
            values=lmz.workflow.WorkflowDescriptor.empty(0,1);
            for index=1:numel(ids)
                values(index,1)=obj.Workflows.get( ...
                    obj.State.ModelId,ids{index});
            end
        end
        function contribution=workbenchContribution(obj)
            contribution=obj.Workflows.getWorkbench(obj.State.ModelId);
        end
        function id=layoutProfileId(obj)
            id=obj.State.LayoutProfileId;
        end
        function setLayoutProfile(obj,id)
            profile=lmz.gui.layout.LayoutProfileRegistry.get(char(id));
            obj.State.LayoutProfileId=profile.Id;
        end
        function session=selectWorkflow(obj,workflowId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            descriptor=obj.Workflows.get(obj.State.ModelId,char(workflowId));
            session=lmz.workflow.WorkflowRunner().initialize( ...
                descriptor,obj.Context);
            selection=lmz.services.BranchService().selectPoint( ...
                session.Dataset,session.SeedIndex);
            obj.invalidateDerived();
            obj.State.WorkflowId=descriptor.Id;
            obj.State.WorkflowSession=session;
            obj.State.DataSourceId=descriptor.DataSourceId;
            obj.State.WorkbenchContribution=descriptor.Workbench;
            obj.State.LayoutProfileId=descriptor.LayoutProfileId;
            obj.State.ProblemId=descriptor.ProblemId;
            obj.State.ProblemConfiguration=descriptor.ProblemConfiguration;
            obj.State.SolveMode=obj.solveModeForProblem(descriptor.ProblemId);
            obj.State.Datasets={session.Dataset};
            obj.State.ActiveDatasetId=session.Dataset.Id;
            obj.State.Selection=selection;
            obj.State.LockedSelection=selection;
            obj.State.HoverSelection=[];
            obj.State.WorkingSolution=session.WorkingSolution;
            obj.State.WorkingEvaluation=session.InitialEvaluation;
            obj.State.AxisVariables=completeAxisNames( ...
                descriptor.AxisPreset.coordinateNames());
            obj.State.ContinuationDirectionMode= ...
                descriptor.ContinuationPreset.DirectionMode;
            obj.State.OscillatorIndex=session.SeedIndex;
            obj.State.Status=sprintf('Workflow %s initialized at point %d.', ...
                descriptor.Label,session.SeedIndex);
        end
        function records=dataSourceDescriptors(obj)
            sources=obj.Workflows.listDataSources(obj.State.ModelId);
            template=struct('id','','label','','dataSourceId','', ...
                'isDefault',false,'path','','sourceHash','', ...
                'pointCount',NaN);
            records=repmat(template,0,1);
            for sourceIndex=1:numel(sources)
                source=sources(sourceIndex);provider=source.createProvider();
                listed=providerRecords(provider.list(source,obj.Registry));
                for recordIndex=1:numel(listed)
                    raw=listed{recordIndex};item=template;
                    item.id=providerRecordField(raw,{'id','Id','name'},'');
                    item.label=providerRecordField(raw, ...
                        {'label','Label','name'},item.id);
                    item.dataSourceId=source.Id;
                    item.isDefault=strcmp(item.id,source.DefaultDatasetId);
                    item.path=providerRecordField(raw, ...
                        {'path','sourcePath','Path'},'');
                    item.sourceHash=providerRecordField(raw, ...
                        {'sourceHash','SourceHash'},'');
                    item.pointCount=providerRecordField(raw, ...
                        {'pointCount','PointCount'},NaN);
                    records(end+1,1)=item; %#ok<AGROW>
                end
            end
        end
        function dataset=loadDataSource(obj,datasetId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            [source,provider]=obj.registeredSourceForDataset(char(datasetId));
            dataset=lmz.services.BranchService().loadDataSource( ...
                obj.Workflows,obj.State.ModelId,source.Id,char(datasetId));
            retained=obj.writableDatasets();
            obj.State.WorkflowId='';obj.State.WorkflowSession=[];
            obj.State.DataSourceId=source.Id;
            obj.State.Datasets=[{dataset} retained];
            obj.State.ActiveDatasetId=dataset.Id;
            obj.applyRegisteredAxisPreset(source);
            index=provider.recommendedPoint(source,dataset);
            obj.lockBranchPoint(dataset.Id,index);
            obj.State.Status=sprintf('Registered dataset loaded: %s (%d points).', ...
                dataset.Name,dataset.Branch.pointCount());
        end
        function datasets=loadAllDataSources(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            sources=obj.Workflows.listDataSources(obj.State.ModelId);
            datasets={};defaultDataset=[];defaultIndex=1;defaultSource=[];
            for sourceIndex=1:numel(sources)
                source=sources(sourceIndex);provider=source.createProvider();
                loaded=lmz.services.BranchService().loadAllDataSource( ...
                    obj.Workflows,obj.State.ModelId,source.Id);
                for datasetIndex=1:numel(loaded)
                    datasets{end+1}=loaded{datasetIndex}; %#ok<AGROW>
                    if isempty(defaultDataset)
                        defaultDataset=loaded{datasetIndex};
                        defaultIndex=provider.recommendedPoint( ...
                            source,loaded{datasetIndex});
                        defaultSource=source;
                    end
                end
            end
            if isempty(datasets)
                error('lmz:GUI:NoRegisteredData', ...
                    'The selected model has no registered datasets.');
            end
            obj.State.WorkflowId='';obj.State.WorkflowSession=[];
            obj.State.DataSourceId=defaultSource.Id;
            obj.State.Datasets=[datasets obj.writableDatasets()];
            obj.State.ActiveDatasetId=defaultDataset.Id;
            obj.applyRegisteredAxisPreset(defaultSource);
            obj.lockBranchPoint(defaultDataset.Id,defaultIndex);
            obj.State.Status=sprintf('Loaded %d registered datasets.', ...
                numel(datasets));
        end
        function preset=axisPreset(obj)
            axisValue=[];
            if ~isempty(obj.State.WorkflowId)
                descriptor=obj.Workflows.get( ...
                    obj.State.ModelId,obj.State.WorkflowId);
                axisValue=descriptor.AxisPreset;
            else
                contribution=obj.workbenchContribution();
                sourceId=obj.State.DataSourceId;
                if ~isempty(sourceId)
                    source=obj.Workflows.getDataSource( ...
                        obj.State.ModelId,sourceId);
                    id=fieldOr(source.Metadata,'axisPresetId','');
                    if ~isempty(id)&&contribution.hasAxisPreset(id)
                        axisValue=contribution.axisPreset(id);
                    end
                end
                if isempty(axisValue)&&~isempty(contribution.AxisPresets)
                    axisValue=contribution.AxisPresets(1);
                end
            end
            if isempty(axisValue)
                names=completeAxisNames(obj.State.AxisVariables);
                limits={'auto','auto','auto'};
            else
                names=completeAxisNames(axisValue.coordinateNames());
                limits={axisLimitText(axisValue.XLimits), ...
                    axisLimitText(axisValue.YLimits), ...
                    axisLimitText(axisValue.ZLimits)};
            end
            preset=struct('Coordinates',{names},'Limits',{limits});
        end
        function labels=continuationDirectionLabels(obj)
            contribution=obj.workbenchContribution();
            labels=contribution.DirectionLabels;
            descriptor=obj.activeWorkflowDescriptor();
            if ~isempty(descriptor)
                labels=mergeOptions(labels, ...
                    descriptor.ContinuationPreset.DirectionLabels);
            end
            if ~isfield(labels,'forward'),labels.forward='forward';end
            if ~isfield(labels,'backward'),labels.backward='backward';end
            if ~isfield(labels,'both'),labels.both='both directions';end
        end
        function options=solveDefaultOptions(obj)
            options=obj.workbenchContribution().DefaultSolveOptions;
            descriptor=obj.activeWorkflowDescriptor();
            if ~isempty(descriptor)
                options=mergeOptions(options,descriptor.SolveOptions);
            end
        end
        function options=continuationDefaultOptions(obj)
            options=obj.workbenchContribution().DefaultContinuationOptions;
            descriptor=obj.activeWorkflowDescriptor();
            if ~isempty(descriptor)
                options=mergeOptions( ...
                    options,descriptor.ContinuationPreset.Options);
            end
        end
        function values=homotopyPreset(obj)
            values=struct();descriptor=obj.activeWorkflowDescriptor();
            if ~isempty(descriptor),values=descriptor.HomotopyPreset.Values;end
        end
        function values=familyScanPreset(obj)
            values=struct();descriptor=obj.activeWorkflowDescriptor();
            if ~isempty(descriptor),values=descriptor.FamilyScanPreset.Values;end
        end
        function value=generatedSeedRadius(obj)
            value=0.01;
            descriptor=obj.activeWorkflowDescriptor();
            if ~isempty(descriptor)
                value=descriptor.SeedPreset.GeneratedRadius;
            end
        end
        function result=runContinuationDirection(obj,mode,options)
            if nargin<3||isempty(options),options=struct();end
            mode=char(mode);
            if ~any(strcmp(mode,{'forward','backward','both'}))
                error('lmz:GUI:ContinuationDirection', ...
                    'Continuation direction must be forward, backward, or both.');
            end
            defaults=obj.continuationDefaultOptions();
            options=mergeOptions(defaults,options);
            if isfield(options,'DirectionMode')
                options=rmfield(options,'DirectionMode');
            end
            obj.State.ContinuationDirectionMode=mode;
            if isempty(obj.State.SeedPair)
                obj.makeAdjacentSeedPair(+1,struct());
            end
            original=obj.State.SeedPair;
            cleanup=onCleanup(@()restoreSeedPair(obj,original));
            if strcmp(mode,'backward')
                obj.State.SeedPair=reverseSolutionPair(original);
                options.BothDirections=false;
            else
                options.BothDirections=strcmp(mode,'both');
            end
            result=obj.runContinuation(options);
            clear cleanup
        end
        function selectModel(obj,modelId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);else,obj.Context.Pause.resume();end
            model=obj.Registry.createModel(modelId);manifest=model.getManifest();problems=model.listProblems();
            obj.State.ModelId=manifest.id;obj.State.ProblemId=problems{1};
            obj.State.WorkflowId='';obj.State.WorkflowSession=[];
            obj.State.DataSourceId='';
            contribution=obj.Workflows.getWorkbench(manifest.id);
            obj.State.WorkbenchContribution=contribution;
            obj.State.LayoutProfileId=contribution.LayoutProfileId;
            obj.State.ProblemConfiguration=obj.defaultProblemConfiguration( ...
                manifest.id,problems{1});
            obj.State.SolveMode=obj.solveModeForProblem(problems{1});
            obj.State.Simulation=[];
            examples=obj.builtInExamples();
            if isempty(examples)
                obj.State.ExampleId='';
            elseif ~any(strcmp(obj.State.ExampleId,examples))
                obj.State.ExampleId=examples{1};
            end
            obj.State.CandidateSimulation=[];obj.State.Datasets={};obj.State.Selection=[];
            obj.State.LockedSelection=[];obj.State.HoverSelection=[];obj.State.WorkingSolution=[];
            obj.State.WorkingEvaluation=[];
            obj.State.SolvedSolution=[];obj.State.SolveResult=[];
            obj.State.SolveProgress=[];
            obj.State.ShootingResult=[];obj.State.TimingResult=[];
            obj.State.SectionTransferResult=[];
            obj.State.SeedPair=[];
            obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            obj.State.HomotopyResult=[];obj.State.FamilyScanResult=[];
            obj.State.ContinuationDirectionMode='both';
            obj.State.OverlayState=struct();
            obj.State.OptimizationResult=[];obj.State.RequestedStrideCount=1;
            obj.State.StridePlan=[];obj.State.MultiStrideResult=[];
            obj.State.CompletionPolicy='error_if_missing';
            obj.State.FailurePolicy='return_partial';
            obj.State.EnergyNeutralOnly=true;obj.State.PlanValidation=struct();
            obj.State.StrideParameterOverrides=struct();obj.State.DeclaredWork=0;
            obj.State.CurrentRun=[];obj.State.RecordingState=struct();
            obj.State.Status=['Selected ' manifest.id];
            sources=obj.Workflows.listDataSources(manifest.id);
            if isempty(sources)
                obj.initializeGenericModel(model,problems{1});
            else
                source=obj.Workflows.defaultDataSource(manifest.id);
                obj.State.DataSourceId=source.Id;
                obj.loadDataSource(source.DefaultDatasetId);
            end
        end
        function ids=problemIds(obj),ids=obj.Registry.createModel(obj.State.ModelId).listProblems();end

        function ids=sectionIds(obj)
            try
                catalog=obj.Registry.getPoincareSectionRegistry( ...
                    obj.State.ModelId);
                ids=catalog.listSections();
            catch
                ids={};
            end
        end

        function value=sectionDescriptor(obj,sectionId)
            catalog=obj.Registry.getPoincareSectionRegistry(obj.State.ModelId);
            value=catalog.descriptor(char(sectionId)).toStruct();
        end

        function value=timingEditorData(obj)
            value=struct('Available',false,'EventNames',{{}}, ...
                'FreeMask',false(0,1),'ReturnTimeFree',false, ...
                'FixedInitialState',zeros(0,1), ...
                'FixedPhysicalParameters',zeros(0,1));
            try
                problem=obj.problem(obj.State.ProblemId);
            catch
                return
            end
            if ~isa(problem,'lmz.schedule.SectionReturnTimingProblem'),return,end
            schedule=problem.InputSchedule;
            value=struct('Available',true,'EventNames',{schedule.names()}, ...
                'FreeMask',schedule.freeMask(), ...
                'ReturnTimeFree',~schedule.ReturnTimeFixed, ...
                'FixedInitialState',problem.FixedInitialState, ...
                'FixedPhysicalParameters',problem.FixedPhysicalParameters);
        end

        function configuration=configureSections(obj,changes)
            if ~isstruct(changes)||~isscalar(changes)
                error('lmz:GUI:SectionConfiguration', ...
                    'Section configuration must be a scalar struct.');
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            catalog=obj.Registry.getPoincareSectionRegistry(obj.State.ModelId);
            configuration=obj.State.ProblemConfiguration;
            names=fieldnames(changes);
            allowed={'StartSectionId','StopSectionId','StartStateSide', ...
                'StopStateSide','CrossingDirection','MinimumReturnTime', ...
                'RequiredEventSequence','ReturnOccurrence','SymmetryId'};
            if ~all(ismember(names,allowed))
                unknown=names{find(~ismember(names,allowed),1)};
                error('lmz:GUI:SectionConfiguration', ...
                    'Unknown section configuration field %s.',unknown);
            end
            for index=1:numel(names)
                configuration.(names{index})=changes.(names{index});
            end
            if ~isfield(configuration,'StartSectionId')
                configuration.StartSectionId='apex';
            end
            if ~isfield(configuration,'StopSectionId')
                configuration.StopSectionId=configuration.StartSectionId;
            end
            if ~catalog.hasSection(configuration.StartSectionId)|| ...
                    ~catalog.hasSection(configuration.StopSectionId)
                error('lmz:GUI:UnknownSection', ...
                    'Configured start or stop section is not in the model catalog.');
            end
            sameSection=strcmp(configuration.StartSectionId, ...
                configuration.StopSectionId);
            if strcmp(obj.State.ProblemId,'section_transition')&&sameSection
                error('lmz:GUI:TransitionSections', ...
                    ['section_transition requires distinct endpoints; use ' ...
                    'multiple_shooting for same-section periodic closure.']);
            elseif strcmp(obj.State.ProblemId,'multiple_shooting')&& ...
                    ~sameSection
                error('lmz:GUI:PeriodicShootingSections', ...
                    ['multiple_shooting requires the same start and stop ' ...
                    'section; use section_transition for direct mixed ' ...
                    'endpoints.']);
            end
            start=catalog.descriptor(configuration.StartSectionId);
            stop=catalog.descriptor(configuration.StopSectionId);
            configuration=completeSectionConfiguration( ...
                configuration,start,stop,catalog);
            model=obj.Registry.createModel(obj.State.ModelId);
            problem=model.createProblem(obj.State.ProblemId, ...
                obj.problemConfigurationForCreation( ...
                obj.State.ProblemId,configuration));
            changed=~isequaln(configuration,obj.State.ProblemConfiguration);
            if changed
                if isa(problem,'lmz.api.SimulationProblem')|| ...
                        isa(problem, ...
                        'lmz.multistride.NStrideSimulationProblem')
                    replacement=obj.makeTutorialSolution(obj.State.ProblemId);
                else
                    replacement=problem.makeSolution( ...
                        problem.getDecisionSchema().defaults(), ...
                        problem.getParameterSchema().defaults(),[]);
                end
                obj.invalidateDerived();
                obj.State.ProblemConfiguration=configuration;
                obj.State.WorkingSolution=replacement;
                obj.State.Status=sprintf( ...
                    'Configured return from %s to %s.', ...
                    configuration.StartSectionId,configuration.StopSectionId);
            end
        end

        function setSolveMode(obj,mode)
            mode=char(mode);
            modes={'Periodic orbit','Contact timings only', ...
                'N-stride periodic orbit','Timing sequence', ...
                'Multiple shooting','Horizon feasibility'};
            if ~any(strcmp(mode,modes))
                error('lmz:GUI:SolveMode','Unknown solve mode %s.',mode);
            end
            ids=obj.problemIds();target='';
            switch mode
                case 'Periodic orbit'
                    if any(strcmp(ids,'periodic_orbit'))
                        target='periodic_orbit';
                    elseif any(strcmp(ids,'periodic_apex'))
                        target='periodic_apex';
                    elseif any(strcmp(ids,'periodic_hop'))
                        target='periodic_hop';
                    end
                case 'Contact timings only'
                    if any(strcmp(ids,'section_return_timing'))
                        target='section_return_timing';
                    end
                case 'N-stride periodic orbit'
                    if any(strcmp(ids,'n_stride_periodic'))
                        target='n_stride_periodic';
                    end
                case 'Timing sequence'
                    if any(strcmp(ids,'contact_timing_sequence'))
                        target='contact_timing_sequence';
                    end
                case {'Multiple shooting','Horizon feasibility'}
                    if strcmp(mode,'Multiple shooting')&& ...
                            strcmp(obj.State.ProblemId,'section_transition')
                        target='section_transition';
                    else
                        candidates={'multiple_shooting', ...
                            'multiple_shooting_horizon'};
                        for index=1:numel(candidates)
                            if any(strcmp(ids,candidates{index}))
                                target=candidates{index};break
                            end
                        end
                    end
            end
            if isempty(target)
                error('lmz:GUI:SolveModeUnavailable', ...
                    '%s is unavailable for %s.',mode,obj.State.ModelId);
            end
            obj.selectProblem(target);
            obj.State.SolveMode=mode;
            if strcmp(mode,'Horizon feasibility')
                obj.setShootingSettings(struct( ...
                    'ShootingFormulation','horizon_feasibility', ...
                    'Formulation','feasibility'));
            end
        end

        function configuration=setShootingSettings(obj,changes)
            if ~isstruct(changes)||~isscalar(changes)
                error('lmz:GUI:ShootingConfiguration', ...
                    'Shooting settings must be a scalar struct.');
            end
            allowed={'ShootingFormulation','Formulation','Solver', ...
                'InterfaceStateMask','EventFreeMask','ControlFreeMask', ...
                'EnergyWorkMode','ResidualTolerance','HorizonLength', ...
                'TemplateInitializer'};
            names=fieldnames(changes);
            if ~all(ismember(names,allowed))
                unknown=names{find(~ismember(names,allowed),1)};
                error('lmz:GUI:ShootingConfiguration', ...
                    'Unknown shooting setting %s.',unknown);
            end
            configuration=obj.State.ProblemConfiguration;
            for index=1:numel(names)
                configuration.(names{index})=changes.(names{index});
            end
            if strcmp(obj.State.ProblemId,'section_transition')
                if isfield(changes,'ShootingFormulation')&& ...
                        ~strcmp(changes.ShootingFormulation, ...
                        'multiple_shooting')
                    error('lmz:GUI:TransitionFormulation', ...
                        ['section_transition is a direct multiple-shooting ' ...
                        'formulation.']);
                end
                if isfield(changes,'Formulation')&& ...
                        ~strcmp(changes.Formulation,'transition')
                    error('lmz:GUI:TransitionFormulation', ...
                        ['section_transition must retain the transition ' ...
                        'horizon formulation.']);
                end
                if isfield(changes,'HorizonLength')&& ...
                        changes.HorizonLength~=1
                    error('lmz:GUI:TransitionHorizon', ...
                        ['section_transition is one direct segment; select ' ...
                        'multiple_shooting for a periodic multi-segment ' ...
                        'horizon.']);
                end
                configuration.ShootingFormulation='multiple_shooting';
                configuration.Formulation='transition';
                configuration.HorizonLength=1;
            end
            configuration=validateShootingConfiguration(configuration);
            model=obj.Registry.createModel(obj.State.ModelId);
            problem=model.createProblem(obj.State.ProblemId, ...
                obj.problemConfigurationForCreation( ...
                obj.State.ProblemId,configuration));
            if ~isa(problem,'lmz.shooting.MultipleShootingProblem')
                error('lmz:GUI:ShootingProblem', ...
                    'Selected problem does not support multiple shooting.');
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.invalidateDerived();
            obj.State.ProblemConfiguration=configuration;
            obj.State.WorkingSolution=problem.makeSolution( ...
                problem.getDecisionSchema().defaults(), ...
                problem.getParameterSchema().defaults(),[]);
            obj.State.Status=sprintf( ...
                'Rebuilt %d-segment shooting problem.', ...
                problem.Horizon.segmentCount());
        end

        function value=shootingEditorData(obj)
            configuration=validateShootingConfiguration( ...
                obj.State.ProblemConfiguration);
            value=struct('Available',false,'Configuration',configuration, ...
                'UnknownCount',0,'ResidualCount',0,'SegmentCount',0, ...
                'NodeCount',0,'Diagnostics',struct(), ...
                'NativeConfiguration',struct(), ...
                'ResidualClassification','not-run','EventNames',{{}}, ...
                'EventFreeMask',false(0,1),'ReturnTimeFree',false, ...
                'InitializerDescriptors', ...
                    obj.shootingInitializerDescriptors());
            try
                problem=obj.problem(obj.State.ProblemId);
            catch
                return
            end
            if ~isa(problem,'lmz.shooting.MultipleShootingProblem'),return,end
            value.Available=true;
            value.NativeConfiguration=problem.Configuration;
            value.UnknownCount=problem.unknownDimension();
            value.ResidualCount=problem.residualDimension();
            value.SegmentCount=problem.Horizon.segmentCount();
            value.NodeCount=problem.Horizon.nodeCount();
            schedule=problem.Horizon.Segments{1}.EventSchedule;
            if isa(schedule,'lmz.schedule.EventSchedule')
                value.EventNames=schedule.names();
                value.EventFreeMask=schedule.freeMask();
                value.ReturnTimeFree=~schedule.ReturnTimeFixed;
            end
            if ~isempty(obj.State.ShootingResult)
                value.Diagnostics=obj.State.ShootingResult.Diagnostics;
                value.ResidualClassification= ...
                    obj.State.ShootingResult.FeasibilityReport.Classification;
            end
        end

        function values=shootingInitializerDescriptors(obj)
            model=obj.Registry.createModel(obj.State.ModelId);
            values=model.getShootingInitializerDescriptors( ...
                obj.State.ProblemId);
        end

        function rendered=renderOptimizationDiagnostics(obj, ...
                sensitivityAxes,r2Axes,result)
            model=obj.Registry.createModel(obj.State.ModelId);
            rendered=model.renderOptimizationDiagnostics( ...
                sensitivityAxes,r2Axes,result);
        end

        function rows=sectionCombinationData(obj)
            rows=struct('StartSectionId',{},'StopSectionId',{}, ...
                'StartStateSide',{},'StopStateSide',{}, ...
                'Classification',{},'Reason',{}, ...
                'EditableStatePlane',{},'Composite',{}, ...
                'StatePlaneSummary',{},'CompositeSummary',{});
            ids=obj.sectionIds();
            for first=1:numel(ids)
                start=obj.sectionDescriptor(ids{first});
                for second=1:numel(ids)
                    stop=obj.sectionDescriptor(ids{second});
                    same=strcmp(ids{first},ids{second});
                    classification='unsupported';reason= ...
                        'mixed endpoints require a model transition codec';
                    transitionProblem=strcmp(obj.State.ProblemId, ...
                        'section_transition');
                    periodicShooting=strcmp(obj.State.ProblemId, ...
                        'multiple_shooting');
                    if transitionProblem&&same
                        classification='unsupported';
                        reason=['section_transition requires distinct ' ...
                            'endpoints; select multiple_shooting for ' ...
                            'same-section periodic closure'];
                    elseif transitionProblem&& ...
                            scientificTransitionKind(start.kind)&& ...
                            scientificTransitionKind(stop.kind)
                        [classification,qualification]= ...
                            scientificTransitionSupport(start,stop);
                        if strcmp(classification,'validated')
                            reason=['tested direct section_transition with an ' ...
                                'explicit terminal target; ' qualification];
                        else
                            reason=['section_transition adapter available; ' ...
                                'this exact pair is not numerically validated'];
                        end
                    elseif same
                        if strcmp(stop.validationStatus,'tested')|| ...
                                strcmp(stop.validationStatus,'source-equivalent')
                            classification='validated';reason='catalog tested';
                        else
                            classification='experimental';
                            reason='catalog section is not yet source-validated';
                        end
                    elseif strcmp(ids{first},'apex')&& ...
                            strcmp(ids{second},'stride_boundary')
                        if strcmp(obj.State.ProblemId, ...
                                'section_return_timing')
                            classification='validated';
                            reason=['timing only: tested direct ' ...
                                'apex-to-stride-boundary return'];
                        else
                            classification='unsupported';
                            reason=['unsupported by ' ...
                                'multiple_shooting_horizon; select Contact ' ...
                                'timings only for this direct return'];
                        end
                    elseif periodicShooting&& ...
                            any(strcmp('section_transition',obj.problemIds()))
                        reason=['multiple_shooting is same-section periodic ' ...
                            'closure; select section_transition for direct ' ...
                            'mixed endpoints'];
                    end
                    statePlaneSummary=sectionStatePlaneSummary(stop);
                    compositeSummary=sectionCompositeSummary(stop);
                    reason=appendSectionSummary(reason,statePlaneSummary, ...
                        compositeSummary);
                    rows(end+1,1)=struct( ...
                        'StartSectionId',ids{first}, ...
                        'StopSectionId',ids{second}, ...
                        'StartStateSide',start.stateSide, ...
                        'StopStateSide',stop.stateSide, ...
                        'Classification',classification,'Reason',reason, ...
                        'EditableStatePlane',strcmp(stop.kind,'state_plane'), ...
                        'Composite',strcmp(stop.kind,'composite'), ...
                        'StatePlaneSummary',statePlaneSummary, ...
                        'CompositeSummary',compositeSummary); %#ok<AGROW>
                end
            end
        end

        function setEventFreeMask(obj,freeMask,returnTimeFree)
            if ~islogical(freeMask)||~isvector(freeMask)|| ...
                    ~islogical(returnTimeFree)||~isscalar(returnTimeFree)
                error('lmz:GUI:EventMask','Event free mask is invalid.');
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            configuration=obj.State.ProblemConfiguration;
            configuration.FixedEventMask=~freeMask(:);
            configuration.FreeReturnTime=logical(returnTimeFree);
            if isfield(configuration,'FreeEvents')
                configuration=rmfield(configuration,'FreeEvents');
            end
            obj.invalidateDerived();
            obj.State.ProblemConfiguration=configuration;
            obj.State.Status='Updated explicit fixed/free event mask.';
        end

        function result=transferWorkingSolution(obj,targetSectionId)
            if isempty(obj.State.WorkingSolution)
                error('lmz:GUI:SectionTransferSeed', ...
                    'A working solution is required for section transfer.');
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            model=obj.Registry.createModel(obj.State.ModelId);
            result=lmz.services.SectionTransferService().transfer(model, ...
                obj.State.WorkingSolution,char(targetSectionId),obj.Context);
            obj.invalidateDerived();
            obj.State.SectionTransferResult=result;
            obj.State.WorkingSolution=result.Solution;
            obj.State.Simulation=result.Simulation;
            obj.State.Status=sprintf('Transferred orbit to %s.',targetSectionId);
        end

        function setStrideSettings(obj,count,completion,failure,energyNeutral)
            if ~isnumeric(count)||~isscalar(count)||~isfinite(count)|| ...
                    count<1||count~=fix(count)
                error('lmz:GUI:StrideCount', ...
                    'Requested stride count must be a positive integer.');
            end
            lmz.multistride.MissingStridePolicy.from(completion);
            if ~any(strcmp(char(failure),{'return_partial','error'}))
                error('lmz:GUI:FailurePolicy','Failure policy is invalid.');
            end
            if ~(islogical(energyNeutral)&&isscalar(energyNeutral))
                error('lmz:GUI:EnergyPolicy', ...
                    'Energy-neutral selection must be logical.');
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            plan=obj.State.StridePlan;
            if ~isempty(plan)
                if count<plan.CompletedStrideCount
                    plan=plan.truncate(count);
                elseif count>plan.CompletedStrideCount
                    plan=plan.withRequestedStrideCount(count);
                end
                plan=plan.withPolicies(completion,plan.EnergyPolicy,failure);
            end
            obj.State.RequestedStrideCount=count;
            obj.State.CompletionPolicy=char(completion);
            obj.State.FailurePolicy=char(failure);
            obj.State.EnergyNeutralOnly=logical(energyNeutral);
            obj.State.StridePlan=plan;obj.State.MultiStrideResult=[];
            obj.State.PlanValidation=struct();
            obj.State.Status=sprintf('Requested %d strides.',count);
        end

        function setStrideOverrides(obj,overrides,declaredWork)
            if ~isstruct(overrides)||~isnumeric(declaredWork)|| ...
                    ~isreal(declaredWork)||any(~isfinite(declaredWork(:)))
                error('lmz:GUI:StrideOverrides', ...
                    'Stride overrides or declared work are invalid.');
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.StrideParameterOverrides=overrides;
            obj.State.DeclaredWork=declaredWork;
            obj.State.MultiStrideResult=[];obj.State.PlanValidation=struct();
            obj.State.Status='Per-stride overrides stored; validate energy next.';
        end

        function schedule=strideScheduleOverride(obj,index,timing)
            if ~isnumeric(index)||~isscalar(index)||index<1||index~=fix(index)|| ...
                    ~isnumeric(timing)||~isvector(timing)|| ...
                    any(~isfinite(timing(:)))||isempty(timing)
                error('lmz:GUI:EventSeed', ...
                    'Stride index and event-time seed are invalid.');
            end
            model=obj.Registry.createModel(obj.State.ModelId);
            provider=model.getMultiStrideProvider();
            if isempty(provider)
                error('lmz:GUI:EventSeed', ...
                    'The selected model has no registered schedule provider.');
            end
            schedule=provider.scheduleOverride( ...
                obj.State.StridePlan,index,timing(:));
        end

        function result=completeStridePlan(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            model=obj.Registry.createModel(obj.State.ModelId);
            configuration=obj.multiStrideConfiguration();
            problem=model.createProblem('n_stride_simulation',configuration);
            result=problem.simulate(obj.Context);
            if ~isa(result,'lmz.multistride.MultiStrideResult')
                error('lmz:GUI:MultiStrideResult', ...
                    'N-stride problem returned an invalid result.');
            end
            obj.State.MultiStrideResult=result;obj.State.StridePlan=result.Plan;
            obj.State.PlanValidation= ...
                lmz.multistride.StridePlanValidator.validate(result.Plan);
            if ~isempty(result.Simulation),obj.State.Simulation=result.Simulation;end
            obj.State.Status=sprintf('%s: %d of %d strides completed.', ...
                result.CompletionStatus,result.CompletedStrideCount, ...
                result.RequestedStrideCount);
        end

        function report=validateStridePlan(obj,requireComplete)
            if nargin<2,requireComplete=false;end
            if isempty(obj.State.StridePlan)
                error('lmz:GUI:MissingStridePlan','No stride plan is available.');
            end
            report=lmz.multistride.StridePlanValidator.validate( ...
                obj.State.StridePlan,logical(requireComplete));
            obj.State.PlanValidation=report;
            obj.State.Status='Stride plan validation complete.';
        end

        function report=validateStrideEnergy(obj)
            if isempty(obj.State.StridePlan)
                error('lmz:GUI:EnergyPreviewUnavailable', ...
                    'Energy preview requires a loaded stride plan.');
            end
            model=obj.Registry.createModel(obj.State.ModelId);
            provider=model.getMultiStrideProvider();
            if isempty(provider)
                error('lmz:GUI:EnergyPreviewUnavailable', ...
                    'The selected model has no registered energy provider.');
            end
            report=provider.previewEnergy(obj.State.StridePlan, ...
                obj.State.RequestedStrideCount,obj.State.EnergyNeutralOnly, ...
                obj.State.StrideParameterOverrides,obj.State.DeclaredWork, ...
                obj.Context);
            obj.State.PlanValidation=report;
            obj.State.Status=sprintf( ...
                'Energy preview accepted %d pending transitions.', ...
                numel(diagnostics));
        end

        function result=simulateStridePlan(obj)
            if isempty(obj.State.StridePlan)
                result=obj.completeStridePlan();return
            end
            obj.validateStridePlan(true);
            result=obj.completeStridePlan();
        end

        function saveStridePlan(obj,path)
            if isempty(obj.State.StridePlan)
                error('lmz:GUI:MissingStridePlan','No stride plan is available.');
            end
            lmz.io.ArtifactStore.save(path,obj.State.StridePlan.toArtifact());
            obj.State.Status=sprintf('Saved stride plan to %s.',path);
        end

        function plan=loadStridePlan(obj,path)
            artifact=lmz.io.ArtifactStore.load(path);
            plan=lmz.multistride.StridePlan.fromArtifact(artifact);
            if ~strcmp(plan.ModelId,obj.State.ModelId)
                error('lmz:GUI:StridePlanModel', ...
                    'Stride plan belongs to %s, not %s.', ...
                    plan.ModelId,obj.State.ModelId);
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.StridePlan=plan;
            obj.State.RequestedStrideCount=plan.RequestedStrideCount;
            obj.State.CompletionPolicy=plan.CompletionPolicy.Id;
            obj.State.FailurePolicy=plan.FailurePolicy;
            obj.State.EnergyNeutralOnly= ...
                ~strcmp(plan.EnergyPolicy.Id,'allow_non_neutral');
            obj.State.PlanValidation= ...
                lmz.multistride.StridePlanValidator.validate(plan);
            obj.State.Status=sprintf('Loaded %d-stride plan.', ...
                plan.RequestedStrideCount);
        end
        function solution=selectProblem(obj,problemId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            model=obj.Registry.createModel(obj.State.ModelId);
            problemIds=model.listProblems();
            if ~any(strcmp(problemId,problemIds))
                error('lmz:GUI:UnknownProblem', ...
                    'Unknown problem %s for selected model %s.', ...
                    problemId,obj.State.ModelId);
            end
            configuration=obj.defaultProblemConfiguration( ...
                obj.State.ModelId,problemId);
            problem=model.createProblem(problemId, ...
                obj.problemConfigurationForCreation(problemId,configuration));
            obj.invalidateDerived();
            obj.State.WorkflowId='';obj.State.WorkflowSession=[];
            obj.State.ProblemId=problemId;
            obj.State.ProblemConfiguration=configuration;
            obj.State.SolveMode=obj.solveModeForProblem(problemId);
            obj.State.HoverSelection=[];

            [dataset,index]=obj.problemDataset(problemId);
            if ~isempty(dataset)
                solution=obj.lockBranchPoint(dataset.Id,index);
                obj.State.Status=sprintf('Selected %s using %s point %d.', ...
                    problemId,dataset.Name,index);
                return
            end

            obj.State.Selection=[];
            obj.State.LockedSelection=[];
            if isa(problem,'lmz.api.SimulationProblem')|| ...
                    isa(problem,'lmz.multistride.NStrideSimulationProblem')
                solution=obj.makeTutorialSolution(problemId);
            else
                solution=problem.makeSolution( ...
                    problem.getDecisionSchema().defaults(), ...
                    problem.getParameterSchema().defaults(),[]);
            end
            obj.State.WorkingSolution=solution;
            obj.State.Status=sprintf('Selected %s.',problemId);
        end
        function setExample(obj,exampleId)
            obj.State.ExampleId=char(exampleId);
        end
        function setContinuationPreview(obj,value)
            obj.State.ContinuationPreview=value;
        end
        function examples=builtInExamples(obj)
            try
                examples=lmz.services.DataService().listBuiltInExamples(obj.State.ModelId);
            catch
                examples={};
            end
        end
        function value=canSimulateDemo(obj)
            value=~isempty(obj.simulationProblemIds());
        end
        function result=simulate(obj,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows({'simulate','simulation'},'simulation');
            [problem,defaultOptions]=obj.demoProblem();
            if nargin<2||isempty(options)|| ...
                    (isstruct(options)&&isempty(fieldnames(options)))
                options=defaultOptions;
            end
            result=lmz.services.SimulationService().simulate(problem,struct(),options,obj.Context);
            obj.State.Simulation=result;
            obj.State.Status=sprintf('%s demonstration simulation complete.', ...
                problem.Id);
        end
        function capabilities=capabilities(obj)
            capabilities=obj.problemCapabilities();
            descriptor=obj.activeWorkflowDescriptor();
            if isempty(descriptor),return,end
            capabilities=restrictWorkflowCapabilities( ...
                capabilities,descriptor);
        end
        function capabilities=problemCapabilities(obj,problemId)
            if nargin<2||isempty(problemId),problemId=obj.State.ProblemId;end
            descriptor=obj.Registry.getProblemDescriptor(obj.State.ModelId,problemId);
            capabilities=descriptor.capabilities;
        end
        function names=homotopyParameterNames(obj)
            solution=obj.State.WorkingSolution;
            if isempty(solution),names={};return,end
            schema=solution.ParameterSchema;
            selectable=arrayfun(@(spec)strcmp(spec.Activity,'active'),schema.Specs);
            names=schema.names();names=names(selectable);
        end

        function dataset=loadBuiltInBranch(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            branch=lmz.services.BranchService().loadBuiltInBranch(obj.Registry,obj.State.ModelId);
            dataset=lmz.data.BranchDataset([obj.State.ModelId ' built-in'],branch,'ReadOnly',true);
            obj.State.Datasets={dataset};obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=loadGaitMap(obj,file)
            if nargin<2||isempty(file)
                source=obj.Workflows.defaultDataSource(obj.State.ModelId);
                file=source.DefaultDatasetId;
            end
            dataset=obj.loadDataSource(file);
        end
        function datasets=loadAllGaitMapBranches(obj)
            datasets=obj.loadAllDataSources();
        end
        function dataset=loadScientificLoadDataset(obj,file)
            if nargin<2||isempty(file)
                source=obj.Workflows.defaultDataSource(obj.State.ModelId);
                file=source.DefaultDatasetId;
            end
            dataset=obj.loadDataSource(file);
        end
        function datasets=loadAllScientificLoadDatasets(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            datasets=obj.loadAllDataSources();
            % Retain the historical wrapper contract: loading every
            % load-pulling dataset leaves the first (single-stride) record
            % selected.  The generic registered loader intentionally uses a
            % descriptor's default dataset instead.
            strideCounts=cellfun(@(item)fieldOr( ...
                item.Metadata,'StrideCount',Inf),datasets);
            [~,selected]=min(strideCounts);
            dataset=datasets{selected};
            datasetId=fieldOr(dataset.Metadata,'DatasetId','');
            [source,provider]=obj.registeredSourceForDataset(datasetId);
            obj.State.DataSourceId=source.Id;
            obj.State.ActiveDatasetId=dataset.Id;
            obj.applyRegisteredAxisPreset(source);
            obj.lockBranchPoint(dataset.Id, ...
                provider.recommendedPoint(source,dataset));
            obj.State.Status=sprintf( ...
                'Loaded %d scientific load datasets; selected %s.', ...
                numel(datasets),dataset.Name);
        end
        function dataset=loadRoadMap(obj,file)
            if nargin<2||isempty(file)
                source=obj.Workflows.defaultDataSource(obj.State.ModelId);
                file=source.DefaultDatasetId;
            end
            dataset=obj.loadDataSource(file);
        end
        function datasets=loadAllRoadMapBranches(obj)
            datasets=obj.loadAllDataSources();
        end
        function dataset=openBranch(obj,path)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            variables=whos('-file',path);names={variables.name};service=lmz.services.BranchService();
            if isscalar(names)&&strcmp(names{1},'artifact')
                branch=service.loadNativeBranch(path);readOnly=false;
            else
                branch=[];sources=obj.Workflows.listDataSources( ...
                    obj.State.ModelId);
                for sourceIndex=1:numel(sources)
                    source=sources(sourceIndex);provider=source.createProvider();
                    adapter=provider.legacyAdapter(source,obj.Registry);
                    if isa(adapter, ...
                            'lmz.workflow.LegacyDataAdapterProvider')&& ...
                            adapter.canLoad(path)
                        model=obj.Registry.createModel(obj.State.ModelId);
                        problem=model.createProblem(source.ProblemId,struct());
                        branch=adapter.importBranch(path,problem);break
                    end
                end
                if isempty(branch)
                    error('lmz:GUI:BranchFile', ...
                        ['No registered legacy adapter for the selected ' ...
                        'model accepts this MAT file.']);
                end
                readOnly=true;
            end
            if ~strcmp(branch.ModelId,obj.State.ModelId)
                error('lmz:GUI:BranchModel', ...
                    'The branch belongs to %s, not selected model %s.', ...
                    branch.ModelId,obj.State.ModelId);
            end
            [~,name,extension]=fileparts(path);style=struct();classification=branch.Classifications{1};if isfield(classification,'Color'),style.Color=classification.Color;end;if isfield(classification,'LineStyle'),style.LineStyle=classification.LineStyle;end
            dataset=lmz.data.BranchDataset([name extension],branch,'SourcePath',path,'ReadOnly',readOnly,'DisplayStyle',style,'Metadata',struct('Status','user-loaded','PointCount',branch.pointCount()));
            obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function datasets=openBranchFolder(obj,folder)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            entries=dir(fullfile(folder,'*.mat'));datasets={};errors={};
            for index=1:numel(entries)
                path=fullfile(entries(index).folder,entries(index).name);
                try
                    datasets{end+1}=obj.openBranch(path); %#ok<AGROW>
                catch exception
                    errors{end+1}=sprintf('%s: %s',entries(index).name,exception.message); %#ok<AGROW>
                end
            end
            if isempty(datasets)
                if isempty(errors),message='No MAT files were found.';else,message=strjoin(errors,newline);end
                error('lmz:GUI:BranchFolder','No supported branches loaded from %s. %s',folder,message);
            end
            obj.State.Status=sprintf('Loaded %d branch datasets from %s.',numel(datasets),folder);
        end
        function dataset=reloadActiveDataset(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.activeDataset();path=dataset.SourcePath;
            if isempty(path)||exist(path,'file')~=2,error('lmz:GUI:ReloadPath','The active dataset has no reloadable source file.');end
            variables=whos('-file',path);names={variables.name};service=lmz.services.BranchService();
            if any(strcmp(names,'results'))||any(strcmp(names,'X_accum'))
                branch=service.reloadLegacySource(obj.problem(dataset.Branch.ProblemId),path);
            elseif isscalar(names)&&strcmp(names{1},'artifact')
                branch=service.loadNativeBranch(path);
            else
                error('lmz:GUI:ReloadType','The active dataset source is not a supported branch file.');
            end
            oldIndex=1;if ~isempty(obj.State.LockedSelection)&&strcmp(obj.State.LockedSelection.DatasetId,dataset.Id),oldIndex=obj.State.LockedSelection.PointIndex;end
            dataset.Branch=branch;dataset.Metadata.PointCount=branch.pointCount();
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','dataset-reloaded','DatasetId',dataset.Id));
            obj.lockBranchPoint(dataset.Id,min(oldIndex,branch.pointCount()));
            obj.State.Status=sprintf('Reloaded %s from disk.',dataset.Name);
        end
        function removeDataset(obj,datasetId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            keep=true(1,numel(obj.State.Datasets));for index=1:numel(obj.State.Datasets),if strcmp(obj.State.Datasets{index}.Id,datasetId),keep(index)=false;end,end
            obj.State.Datasets=obj.State.Datasets(keep);
            if isempty(obj.State.Datasets),obj.State.ActiveDatasetId='';obj.State.LockedSelection=[];obj.State.Selection=[];obj.State.WorkingSolution=[];obj.invalidateDerived();return,end
            obj.State.ActiveDatasetId=obj.State.Datasets{1}.Id;obj.lockBranchPoint(obj.State.ActiveDatasetId,1);
        end
        function setDatasetVisibility(obj,datasetId,visible)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.findDataset(datasetId);dataset.Visible=logical(visible);
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','visibility','DatasetId',dataset.Id));
            obj.State.Status=sprintf('%s visibility: %s.',dataset.Name,onOff(dataset.Visible));
        end
        function setAllDatasetsVisible(obj,visible)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            for index=1:numel(obj.State.Datasets)
                obj.State.Datasets{index}.Visible=logical(visible);
            end
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','visibility-all'));
            obj.State.Status=sprintf('All dataset visibility: %s.',onOff(visible));
        end
        function showOnlyActiveDataset(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            for index=1:numel(obj.State.Datasets)
                obj.State.Datasets{index}.Visible=strcmp( ...
                    obj.State.Datasets{index}.Id,obj.State.ActiveDatasetId);
            end
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','visibility-active-only'));
            obj.State.Status='Only the active dataset is visible.';
        end
        function dataset=plotDataset(obj,datasetId,visible),if nargin<3,visible=true;end;dataset=obj.findDataset(datasetId);obj.setDatasetVisibility(datasetId,visible);end
        function dataset=addWorkingSolutionToDataset(obj,name)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            solution=obj.State.WorkingSolution;
            if isempty(solution),error('lmz:GUI:NoWorkingSolution','No working solution is available.');end
            branch=lmz.data.SolutionBranch.fromSolutions(solution);dataset=lmz.data.BranchDataset(name,branch,'ReadOnly',false,'Metadata',struct('Status','working/user'));obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=addBranchDataset(obj,name,branch)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~isa(branch,'lmz.data.SolutionBranch'),error('lmz:GUI:BranchType','A native SolutionBranch is required.');end
            dataset=lmz.data.BranchDataset(name,branch,'ReadOnly',false,'Metadata',struct('Status','generated/user','PointCount',branch.pointCount()));
            obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=activeDataset(obj),dataset=obj.findDataset(obj.State.ActiveDatasetId);end
        function solution=lockedSolution(obj)
            if isempty(obj.State.LockedSelection),solution=[];return,end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            solution=dataset.Branch.point(obj.State.LockedSelection.PointIndex);
        end
        function setActiveDataset(obj,datasetId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.findDataset(datasetId);obj.State.ActiveDatasetId=dataset.Id;
            index=1;if ~isempty(obj.State.LockedSelection)&&strcmp(obj.State.LockedSelection.DatasetId,dataset.Id),index=obj.State.LockedSelection.PointIndex;end
            obj.lockBranchPoint(dataset.Id,index);
        end
        function setAxisVariables(obj,x,y,z)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.activeDataset();known=dataset.Branch.coordinateNames();
            values={x,y};if nargin>=4&&~isempty(z),values{3}=z;else,values{3}='';end
            for index=1:2+(~isempty(values{3})),if ~any(strcmp(values{index},known)),error('lmz:GUI:AxisVariable','Unknown coordinate %s.',values{index});end,end
            if isequal(obj.State.AxisVariables,values),return,end
            obj.State.AxisVariables=values;
        end
        function values=axisValues(obj,datasetId)
            if nargin<2||isempty(datasetId),dataset=obj.activeDataset();else,dataset=obj.findDataset(datasetId);end
            names=obj.State.AxisVariables;values=struct('X',dataset.Branch.coordinate(names{1}), ...
                'Y',dataset.Branch.coordinate(names{2}),'Z',[]);
            if numel(names)>=3&&~isempty(names{3}),values.Z=dataset.Branch.coordinate(names{3});end
        end
        function selection=hoverNearestPoint(obj,datasetId,coordinates,target)
            dataset=obj.findDataset(datasetId);index=dataset.Branch.nearestPoint(coordinates,target);
            solution=dataset.Branch.point(index);selection=lmz.data.Selection(dataset.Id,index,solution.Id,'hover');
            obj.State.HoverSelection=selection;
        end
        function [selection,details]=hoverNearestVisiblePoint(obj,coordinates,target)
            visible={};
            for index=1:numel(obj.State.Datasets),if obj.State.Datasets{index}.Visible,visible{end+1}=obj.State.Datasets{index};end,end %#ok<AGROW>
            if isempty(visible),error('lmz:GUI:NoVisibleDataset','No visible dataset is available.');end
            dimensions=numel(coordinates);target=target(1:dimensions);ranges=zeros(dimensions,2);
            for axisIndex=1:dimensions
                allValues=[];for datasetIndex=1:numel(visible),allValues=[allValues visible{datasetIndex}.Branch.coordinate(coordinates{axisIndex})];end %#ok<AGROW>
                ranges(axisIndex,:)=[min(allValues) max(allValues)];
            end
            scales=max(ranges(:,2)-ranges(:,1),sqrt(eps));best=Inf;bestDataset=[];bestIndex=1;
            for datasetIndex=1:numel(visible)
                count=visible{datasetIndex}.Branch.pointCount();matrix=zeros(dimensions,count);
                for axisIndex=1:dimensions,matrix(axisIndex,:)=visible{datasetIndex}.Branch.coordinate(coordinates{axisIndex});end
                distances=sqrt(sum(((matrix-target(:))./scales).^2,1));[distance,index]=min(distances);
                if distance<best,best=distance;bestDataset=visible{datasetIndex};bestIndex=index;end
            end
            solution=bestDataset.Branch.point(bestIndex);selection=lmz.data.Selection(bestDataset.Id,bestIndex,solution.Id,'hover');obj.State.HoverSelection=selection;
            coordinateValues=arrayfun(@(axisIndex)bestDataset.Branch.coordinate(coordinates{axisIndex}),1:dimensions,'UniformOutput',false);
            details=struct('Dataset',bestDataset,'Solution',solution,'Coordinates',{coordinates}, ...
                'Values',{coordinateValues}, ...
                'NormalizedDistance',best);
            for axisIndex=1:dimensions,details.Values{axisIndex}=details.Values{axisIndex}(bestIndex);end
        end
        function solution=lockBranchPoint(obj,datasetId,index)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.findDataset(datasetId);selection=lmz.services.BranchService().selectPoint(dataset,index);
            solution=dataset.Branch.point(index);obj.State.ActiveDatasetId=dataset.Id;
            obj.invalidateDerived();
            obj.State.Selection=selection;obj.State.LockedSelection=selection;obj.State.WorkingSolution=solution;
            obj.State.ProblemId=solution.ProblemId;
            obj.State.ProblemConfiguration=obj.defaultProblemConfiguration( ...
                obj.State.ModelId,solution.ProblemId);
            obj.State.SolveMode=obj.solveModeForProblem(solution.ProblemId);
            obj.State.OscillatorIndex=index;obj.State.Status=sprintf('Locked %s point %d.',dataset.Name,index);
        end
        function solution=selectBranchPoint(obj,index),solution=obj.lockBranchPoint(obj.State.ActiveDatasetId,index);end
        function solution=selectByIndex(obj,index),solution=obj.selectBranchPoint(round(index));end
        function solution=selectByPercentage(obj,percentage)
            dataset=obj.activeDataset();percentage=max(0,min(100,percentage));
            index=1+round(percentage/100*(dataset.Branch.pointCount()-1));solution=obj.selectBranchPoint(index);
        end
        function solution=workingSolution(obj),solution=obj.State.WorkingSolution;end
        function comparison=compareSolutions(obj,first,second),comparison=lmz.services.SolutionService().compare(obj.problem(first.ProblemId),first,second);end
        function solution=editWorkingValue(obj,name,value)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            solution=obj.State.WorkingSolution;
            if any(strcmp(name,solution.DecisionSchema.names()))
                values=solution.DecisionValues;
                values(solution.DecisionSchema.indexOf(name))=value;
                solution=solution.withDecisionValues(values);
            elseif any(strcmp(name,solution.ParameterSchema.names()))
                values=solution.ParameterValues;
                values(solution.ParameterSchema.indexOf(name))=value;
                solution=solution.withParameterValues(values);
            else
                error('lmz:GUI:WorkingValue', ...
                    'Unknown working value %s.',name);
            end
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
        end
        function solution=restoreWorkingSolution(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if isempty(obj.State.LockedSelection),error('lmz:GUI:NoSelection','No locked branch point.');end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            solution=dataset.Branch.point(obj.State.LockedSelection.PointIndex);obj.invalidateDerived();obj.State.WorkingSolution=solution;
        end
        function evaluation=evaluateWorkingSolution(obj,includeSimulation)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<2,includeSimulation=false;end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            if isa(problem,'lmz.api.OptimizationProblem')
                solution=obj.State.WorkingSolution;
                [objective,terms,diagnostics]=problem.evaluateObjective( ...
                    solution.DecisionValues,solution.ParameterValues,obj.Context);
                values=objectiveValues(terms);blocks=lmz.data.ResidualBlock( ...
                    'objective_terms',values,ones(size(values)));
                diagnostics.Objective=objective;diagnostics.ObjectiveTerms=terms;
                simulation=[];
                if includeSimulation&&ismethod(problem,'simulateDecision')
                    simulation=problem.simulateDecision(solution.DecisionValues,obj.Context);
                end
                evaluation=lmz.data.ProblemEvaluation(blocks,'Simulation',simulation, ...
                    'Diagnostics',diagnostics,'Feasibility',struct('Valid',true));
            else
                evaluation=lmz.services.EvaluationService().evaluate( ...
                    problem,obj.State.WorkingSolution,includeSimulation,obj.Context);
            end
            obj.State.WorkingEvaluation=evaluation;obj.applyEvaluation(problem,evaluation);
            if includeSimulation,obj.State.CandidateSimulation=evaluation.Simulation;obj.State.Simulation=evaluation.Simulation;end
        end
        function simulation=simulateWorkingSolution(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows({'simulate','simulation'},'simulation');
            solution=obj.State.WorkingSolution;
            if isempty(solution)||~strcmp(solution.ProblemId,obj.State.ProblemId)
                error('lmz:GUI:WorkingProblemMismatch', ...
                    'The working solution does not match selected problem %s.', ...
                    obj.State.ProblemId);
            end
            problem=obj.problem(obj.State.ProblemId);
            if isa(problem,'lmz.api.SimulationProblem')
                options=obj.simulationOptions(problem.Id);
                simulation=lmz.services.SimulationService().simulate( ...
                    problem,struct(),options,obj.Context);
            elseif isa(problem,'lmz.multistride.NStrideSimulationProblem')
                outcome=problem.simulate(obj.Context);
                obj.State.MultiStrideResult=outcome;
                obj.State.StridePlan=outcome.Plan;
                simulation=outcome.Simulation;
            else
                simulation=lmz.services.SolutionService().simulate( ...
                    problem,solution,obj.Context);
            end
            obj.State.CandidateSimulation=simulation;
            obj.State.Simulation=simulation;
            obj.State.Status=sprintf('%s simulation complete.',obj.State.ProblemId);
        end
        function [solution,diagnostics]=projectWorkingSolution(obj,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<2,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            userCallbacks=lmz.solvers.SolveCallbacks( ...
                fieldOr(options,'Callbacks',[]));
            progress=fieldOr(options,'Progress',[]);
            if isempty(progress),progress=lmz.data.SolveProgress();end
            options.Progress=progress;
            options.Callbacks=lmz.solvers.SolveCallbacks( ...
                @(eventName,snapshot)obj.solveProgressUpdate( ...
                eventName,snapshot,userCallbacks));
            obj.State.SolveProgress=progress;
            [solution,diagnostics]=lmz.services.SeedService().project( ...
                problem,obj.State.WorkingSolution,options,obj.Context);
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
            obj.State.SolveProgress=progress;
        end
        function result=solveWorkingSolution(obj,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows({'solve','root_solve'},'root solve');
            if nargin<2||isempty(options),options=struct();end
            options=mergeOptions(obj.solveDefaultOptions(),options);
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            obj.State.SeedPair=[];obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            if isa(problem,'lmz.schedule.SectionReturnTimingProblem')
                seed=problem.InputSchedule;
                if ~isempty(obj.State.WorkingSolution)&& ...
                        numel(obj.State.WorkingSolution.DecisionValues)== ...
                        problem.unknownDimension()
                    seed=obj.State.WorkingSolution;
                end
                result=lmz.services.ContactTimingService().solve( ...
                    problem,seed,options,obj.Context);
                evaluation=problem.evaluate( ...
                    problem.decisionFromSchedule(result.SolvedSchedule),[], ...
                    obj.Context,true);
                solution=problem.makeSolution( ...
                    problem.decisionFromSchedule(result.SolvedSchedule),[], ...
                    evaluation);
                obj.State.TimingResult=result;obj.State.SolveResult=[];
                obj.State.SolvedSolution=solution;obj.State.WorkingSolution=solution;
                obj.State.WorkingEvaluation=evaluation;
                obj.State.Simulation=result.Simulation;
                obj.State.Status='Contact timing solve complete';
                return
            end
            if isa(problem,'lmz.shooting.MultipleShootingProblem')
                if ~isfield(options,'Solver')
                    options.Solver=fieldOr( ...
                        obj.State.ProblemConfiguration,'Solver','auto');
                end
                result=lmz.services.MultipleShootingService().solve( ...
                    problem,obj.State.WorkingSolution,options,obj.Context);
                obj.State.ShootingResult=result;
                obj.State.SolveResult=result.SolveResult;
                obj.State.SolvedSolution=result.SolveResult.Solution;
                obj.State.WorkingSolution=result.SolveResult.Solution;
                obj.State.WorkingEvaluation=result.SolveResult.Evaluation;
                obj.State.Status=sprintf('Multiple shooting: %s.', ...
                    result.FeasibilityReport.Classification);
                return
            end
            if obj.Context.Cancellation.IsCancellationRequested
                obj.Context=lmz.api.RunContext.synchronous( ...
                    obj.Context.RandomSeed);
            end
            if ~isstruct(options)||~isscalar(options)
                error('lmz:GUI:SolveOptions', ...
                    'GUI solve options must be a scalar struct.');
            end
            userCallbacks=lmz.solvers.SolveCallbacks( ...
                fieldOr(options,'Callbacks',[]));
            progress=lmz.data.SolveProgress();
            options.Progress=progress;
            options.Callbacks=lmz.solvers.SolveCallbacks( ...
                @(eventName,snapshot)obj.solveProgressUpdate( ...
                eventName,snapshot,userCallbacks));
            obj.State.SolveProgress=progress;
            obj.State.CurrentRun=struct('Kind','solve','Context',obj.Context);
            obj.Context.Pause.resume();
            clear presentationUpdate
            cleanup=onCleanup(@()obj.finishCurrentRun());
            if obj.workflowSessionOwnsWorkingSolution()
                result=obj.State.WorkflowSession.solve(options);
            else
                result=lmz.services.SolveService().solve(problem, ...
                    obj.State.WorkingSolution,options,obj.Context);
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.SolveResult=result;obj.State.SolveProgress=result.Progress;
            obj.State.SolvedSolution=result.Solution;
            obj.State.WorkingSolution=result.Solution;
            obj.State.WorkingEvaluation=result.Evaluation;
            obj.State.Status='Solve complete';clear cleanup
        end
        function solution=perturbWorkingSolution(obj,magnitude,mode,seed)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<3||isempty(mode),mode='schema-scaled';end;if nargin<4,seed=0;end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            solution=lmz.services.SeedService().perturb(problem,obj.State.WorkingSolution,magnitude,mode,seed);
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
            obj.State.Status=sprintf('Applied reproducible %s noise (seed %d).',mode,seed);
        end
        function pair=makeAdjacentSeedPair(obj,direction,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows( ...
                {'seed_pair','seeds','continuation'},'seed construction');
            if nargin<2,direction=1;end;if nargin<3,options=struct();end
            if obj.hasActiveWorkflowSession()
                pair=obj.State.WorkflowSession.makeAdjacentSeedPair( ...
                    direction,options);
            else
                dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
                problem=obj.problem(dataset.Branch.ProblemId);
                pair=lmz.services.SeedService().adjacentBranchPair( ...
                    problem,dataset.Branch, ...
                    obj.State.LockedSelection.PointIndex,direction, ...
                    options,obj.Context);
            end
            obj.State.SeedPair=pair;obj.State.Status='Adjacent RoadMap seed pair ready';
        end
        function pair=makeManualSeedPair(obj,firstIndex,secondIndex,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows( ...
                {'seed_pair','seeds','continuation'},'seed construction');
            if nargin<4,options=struct();end
            dataset=obj.activeDataset();problem=obj.problem(dataset.Branch.ProblemId);
            pair=lmz.services.SeedService().branchPair(problem,dataset.Branch,firstIndex,secondIndex,options,obj.Context);
            obj.State.SeedPair=pair;obj.State.Status=sprintf('Manual RoadMap seed pair %d to %d ready.',firstIndex,secondIndex);
        end
        function pair=makeSecondSeed(obj,radius)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows( ...
                {'seed_pair','seeds','continuation'},'seed construction');
            if nargin<2||isempty(radius),radius=obj.generatedSeedRadius();end
            if obj.workflowSessionOwnsWorkingSolution()
                pair=obj.State.WorkflowSession.makeSecondSeed( ...
                    radius,struct());
            else
                problem=obj.problem(obj.State.WorkingSolution.ProblemId);
                pair=lmz.services.SeedService().makeSecondSeed( ...
                    problem,obj.State.WorkingSolution,radius,struct(),obj.Context);
            end
            obj.State.SeedPair=pair;
        end
        function result=runContinuation(obj,options)
            obj.assertWorkflowAllows( ...
                {'continuation','continue'},'continuation');
            if nargin<2||isempty(options),options=struct();end
            if isempty(obj.State.SeedPair),obj.makeAdjacentSeedPair(1,struct());end
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);end
            options=mergeOptions(obj.continuationDefaultOptions(),options);
            options=obj.wrapContinuationCallbacks(options);
            obj.Context.Pause.resume();problem=obj.problem(obj.State.SeedPair.First.ProblemId);obj.State.CurrentRun=struct('Kind','continuation','Context',obj.Context);
            cleanup=onCleanup(@()obj.finishCurrentRun());
            if obj.workflowSessionOwnsSeedPair()
                sessionOptions=options;
                sessionOptions.DirectionMode= ...
                    obj.State.ContinuationDirectionMode;
                result=obj.State.WorkflowSession.continueBranch( ...
                    sessionOptions);
            else
                result=lmz.services.ContinuationService().run( ...
                    problem,obj.State.SeedPair,options,obj.Context);
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.ContinuationResult=result;obj.State.Status='Continuation complete';clear cleanup
        end
        function pauseCurrentRun(obj)
            if isempty(obj.State.CurrentRun),return,end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.CurrentRun.Context.Pause.pause();
            obj.Events.publish(lmz.gui.PresentationEvents.RunStateChanged, ...
                struct('Busy',true,'Paused',true,'Kind',obj.State.CurrentRun.Kind));
            obj.State.Status='Run paused';
        end
        function resumeCurrentRun(obj)
            if isempty(obj.State.CurrentRun),return,end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.CurrentRun.Context.Pause.resume();
            obj.Events.publish(lmz.gui.PresentationEvents.RunStateChanged, ...
                struct('Busy',true,'Paused',false,'Kind',obj.State.CurrentRun.Kind));
            obj.State.Status='Run resumed';
        end
        function stopCurrentRun(obj)
            if isempty(obj.State.CurrentRun),return,end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.CurrentRun.Context.Cancellation.cancel();
            obj.Events.publish(lmz.gui.PresentationEvents.RunStateChanged, ...
                struct('Busy',true,'CancellationRequested',true, ...
                'Kind',obj.State.CurrentRun.Kind));
            obj.State.Status='Stop requested';
        end
        function result=resumeCheckpoint(obj,path,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows( ...
                {'continuation','continue'},'checkpoint resume');
            if nargin<3,options=struct();end
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);end
            problem=obj.problem(obj.State.ProblemId);result=lmz.services.ContinuationService().resumeCheckpoint(problem,path,options,obj.Context);
            obj.State.ContinuationResult=result;obj.State.Status='Checkpoint resumed';
        end
        function result=runParameterHomotopy(obj,parameterName,targets,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows( ...
                {'parameter_homotopy','homotopy'},'parameter homotopy');
            if nargin<4,options=struct();end
            if obj.Context.Cancellation.IsCancellationRequested
                obj.Context=lmz.api.RunContext.synchronous( ...
                    obj.Context.RandomSeed);
            end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            obj.Context.Pause.resume();
            obj.State.CurrentRun=struct( ...
                'Kind','parameter_homotopy','Context',obj.Context);
            clear presentationUpdate
            cleanup=onCleanup(@()obj.finishCurrentRun());
            if obj.workflowSessionOwnsWorkingSolution()
                result=obj.State.WorkflowSession.parameterHomotopy( ...
                    parameterName,targets,options);
            else
                result=lmz.services.ContinuationService().parameterHomotopy( ...
                    problem,obj.State.WorkingSolution,parameterName,targets, ...
                    options,obj.Context);
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.HomotopyResult=result;
            obj.State.Status='Parameter homotopy complete';clear cleanup
        end
        function report=runBranchFamilyScan(obj,parameterName,targets,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.assertWorkflowAllows( ...
                {'branch_family','family_scan'},'branch-family scan');
            if nargin<4,options=struct();end
            if obj.Context.Cancellation.IsCancellationRequested
                obj.Context=lmz.api.RunContext.synchronous( ...
                    obj.Context.RandomSeed);
            end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            obj.Context.Pause.resume();
            obj.State.CurrentRun=struct( ...
                'Kind','branch_family','Context',obj.Context);
            clear presentationUpdate
            cleanup=onCleanup(@()obj.finishCurrentRun());
            if obj.workflowSessionOwnsWorkingSolution()
                report=obj.State.WorkflowSession.branchFamilyScan( ...
                    parameterName,targets,options);
            else
                report=lmz.services.ContinuationService().branchFamilyScan( ...
                    problem,obj.State.WorkingSolution,parameterName,targets, ...
                    options,obj.Context);
            end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.FamilyScanResult=report;
            obj.State.Status='Branch-family scan complete';clear cleanup
        end
        function result=runOptimization(obj,options)
            obj.assertWorkflowAllows( ...
                {'optimize','optimization'},'optimization');
            if nargin<2,options=struct();end
            id=obj.State.ProblemId;
            capabilities=obj.problemCapabilities(id);
            if ~capabilities.optimize
                error('lmz:GUI:UnsupportedOptimization', ...
                    'Selected problem %s does not support optimization.',id);
            end
            model=obj.Registry.createModel(obj.State.ModelId);
            if strcmp(id,'trajectory_fit')
                problem=model.createProblem(id,struct('EnforceConstraints',false));
                if isempty(fieldnames(options))
                    options=struct('Algorithm','sqp', ...
                        'MaxIterations',3,'MaxFunctionEvaluations',150, ...
                        'ConstraintTolerance',0.2,'OptimalityTolerance',1e-3, ...
                        'StepTolerance',1e-3);
                end
            elseif strcmp(id,'multi_stride_fit')
                problem=model.createProblem(id,struct());
                if isempty(fieldnames(options))
                    options=struct('Algorithm','sqp', ...
                        'MaxIterations',1,'MaxFunctionEvaluations',30, ...
                        'OptimalityTolerance',1e-5,'StepTolerance',1e-5);
                end
            elseif strcmp(id,'n_stride_fit')
                if isempty(obj.State.StridePlan)
                    error('lmz:GUI:MissingStridePlan', ...
                        ['Complete and validate the shared stride plan before ' ...
                        'running N-stride optimization.']);
                end
                lmz.multistride.StridePlanValidator.validate( ...
                    obj.State.StridePlan,true);
                configuration=struct('StridePlan',obj.State.StridePlan, ...
                    'NumberOfStrides',obj.State.StridePlan.RequestedStrideCount);
                if isfield(options,'ReferenceExtensionPolicy')
                    configuration.ReferenceExtensionPolicy= ...
                        options.ReferenceExtensionPolicy;
                    options=rmfield(options,'ReferenceExtensionPolicy');
                end
                problem=model.createProblem(id,configuration);
                if isempty(fieldnames(options))
                    options=struct('Algorithm','sqp', ...
                        'MaxIterations',1,'MaxFunctionEvaluations',30, ...
                        'OptimalityTolerance',1e-5,'StepTolerance',1e-5);
                end
            else
                problem=model.createProblem(id,struct());
            end
            seed=obj.State.WorkingSolution;
            if isempty(seed)||~strcmp(seed.ProblemId,id)
                seed=problem.makeSolution(problem.getDecisionSchema().defaults(), ...
                    problem.getParameterSchema().defaults(),[]);
            end
            if obj.Context.Cancellation.IsCancellationRequested
                obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);
            end
            obj.Context.Pause.resume();obj.State.CurrentRun=struct('Kind','optimization','Context',obj.Context);
            cleanup=onCleanup(@()obj.finishCurrentRun());
            result=lmz.services.OptimizationService().run(problem,seed,options,obj.Context);
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.OptimizationResult=result;obj.State.WorkingSolution=result.Solution;
            obj.State.ProblemId=id;obj.State.Status='Optimization complete';clear cleanup
        end
        function saveBranch(~,path,branch),lmz.services.BranchService().saveNativeBranch(path,branch);end
        function exportLegacyBranch(~,path,branch),lmz.services.BranchService().exportLegacyBranch(path,branch);end
        function saveWorkingSolution(obj,path),lmz.io.ArtifactStore.save(path,obj.State.WorkingSolution.toArtifact());obj.State.Status=sprintf('Saved solution to %s.',path);end
        function recordAnimation(obj,format,path,renderer,options)
            if nargin<5,options=struct();end
            service=lmz.services.RecorderService();recordContext=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);
            obj.State.RecordingState=struct('Active',true,'Format',format,'Path',path,'Context',recordContext);
            cleanup=onCleanup(@()obj.finishRecording());
            switch lower(format)
                case 'gif',service.recordGif(renderer,path,options,recordContext);
                case {'mp4','mpeg-4'},service.recordMP4(renderer,path,options,recordContext);
                case 'keyframes',service.exportKeyframes(renderer,path, ...
                        fieldOr(options,'NormalizedTimes',[0 .25 .5 .75 1]), ...
                        recordContext,fieldOr(options,'Metadata',struct()), ...
                        fieldOr(options,'DPI',150),options);
                otherwise,error('lmz:GUI:RecordingFormat','Unknown recording format %s.',format);
            end
            clear cleanup
        end
        function recordAxesGif(obj,axesHandle,frameFcn,path,options)
            if nargin<5,options=struct();end
            recordContext=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);obj.State.RecordingState=struct('Active',true,'Format','axes-gif','Path',path,'Context',recordContext);
            cleanup=onCleanup(@()obj.finishRecording());lmz.services.RecorderService().recordAxesGif(axesHandle,frameFcn,path,options,recordContext);clear cleanup
        end
        function exportPlot(~,axesHandle,path,options)
            if nargin<4,options=struct();end
            lmz.services.RecorderService().exportPlot(axesHandle,path,options);
        end
        function stopRecording(obj),if isstruct(obj.State.RecordingState)&&isfield(obj.State.RecordingState,'Active')&&obj.State.RecordingState.Active&&isfield(obj.State.RecordingState,'Context'),obj.State.RecordingState.Context.Cancellation.cancel();end,end
        function names=bodyTrajectoryNames(obj)
            if isempty(obj.State.Simulation),names={};return,end
            available=obj.State.Simulation.StateSchema.names();candidates={{'x','y'},{'quad_x','quad_y'}};names={};
            for index=1:numel(candidates),pair=candidates{index};if all(ismember(pair,available)),names=pair;return,end,end
        end
    end
    methods (Access=private)
        function [source,provider]=registeredSourceForDataset(obj,datasetId)
            sources=obj.Workflows.listDataSources(obj.State.ModelId);
            order=1:numel(sources);
            if ~isempty(obj.State.DataSourceId)
                preferred=find(arrayfun(@(item)strcmp( ...
                    item.Id,obj.State.DataSourceId),sources),1);
                if ~isempty(preferred)
                    order=[preferred order(order~=preferred)];
                end
            end
            for sourceIndex=order
                candidate=sources(sourceIndex);
                candidateProvider=candidate.createProvider();
                records=providerRecords(candidateProvider.list( ...
                    candidate,obj.Registry));
                matched=cellfun(@(record)providerRecordMatches( ...
                    record,datasetId),records);
                if any(matched)|| ...
                        strcmp(datasetId,candidate.DefaultDatasetId)
                    source=candidate;provider=candidateProvider;return
                end
            end
            error('lmz:GUI:UnknownRegisteredDataset', ...
                'No registered data source provides %s.',datasetId);
        end

        function applyRegisteredAxisPreset(obj,source)
            contribution=obj.workbenchContribution();
            id=fieldOr(source.Metadata,'axisPresetId','');
            if ~isempty(id)&&contribution.hasAxisPreset(id)
                names=contribution.axisPreset(id).coordinateNames();
                obj.State.AxisVariables=completeAxisNames(names);
            end
        end

        function observeState(obj)
            mappings={ ...
                'ModelId',lmz.gui.PresentationEvents.ModelChanged; ...
                'WorkflowId',lmz.gui.PresentationEvents.WorkflowChanged; ...
                'WorkflowSession',lmz.gui.PresentationEvents.WorkflowChanged; ...
                'DataSourceId',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'LayoutProfileId',lmz.gui.PresentationEvents.LayoutChanged; ...
                'WorkbenchContribution',lmz.gui.PresentationEvents.LayoutChanged; ...
                'ProblemId',lmz.gui.PresentationEvents.ProblemChanged; ...
                'ProblemConfiguration', ...
                    lmz.gui.PresentationEvents.ProblemConfigurationChanged; ...
                'SolveMode',lmz.gui.PresentationEvents.ProblemConfigurationChanged; ...
                'ExampleId',lmz.gui.PresentationEvents.ExampleChanged; ...
                'RoadMapCatalog',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'Datasets',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'ActiveDatasetId',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'HoverSelection',lmz.gui.PresentationEvents.HoverChanged; ...
                'LockedSelection',lmz.gui.PresentationEvents.SelectionChanged; ...
                'Selection',lmz.gui.PresentationEvents.SelectionChanged; ...
                'WorkingSolution',lmz.gui.PresentationEvents.WorkingSolutionChanged; ...
                'WorkingEvaluation',lmz.gui.PresentationEvents.WorkingSolutionChanged; ...
                'Simulation',lmz.gui.PresentationEvents.SimulationChanged; ...
                'CandidateSimulation',lmz.gui.PresentationEvents.SimulationChanged; ...
                'SolvedSolution',lmz.gui.PresentationEvents.SolveResultChanged; ...
                'SolveResult',lmz.gui.PresentationEvents.SolveResultChanged; ...
                'SolveProgress',lmz.gui.PresentationEvents.SolveProgressChanged; ...
                'ShootingResult',lmz.gui.PresentationEvents.SolveResultChanged; ...
                'TimingResult',lmz.gui.PresentationEvents.SolveResultChanged; ...
                'SectionTransferResult', ...
                    lmz.gui.PresentationEvents.ProblemConfigurationChanged; ...
                'SeedPair',lmz.gui.PresentationEvents.SeedPairChanged; ...
                'ContinuationPreview',lmz.gui.PresentationEvents.ContinuationChanged; ...
                'ContinuationResult',lmz.gui.PresentationEvents.ContinuationChanged; ...
                'HomotopyResult',lmz.gui.PresentationEvents.ContinuationChanged; ...
                'FamilyScanResult',lmz.gui.PresentationEvents.ContinuationChanged; ...
                'ContinuationDirectionMode', ...
                    lmz.gui.PresentationEvents.ContinuationChanged; ...
                'OverlayState',lmz.gui.PresentationEvents.OverlayChanged; ...
                'OptimizationResult',lmz.gui.PresentationEvents.OptimizationChanged; ...
                'RequestedStrideCount',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'StridePlan',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'MultiStrideResult',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'CompletionPolicy',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'FailurePolicy',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'EnergyNeutralOnly',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'StrideParameterOverrides', ...
                    lmz.gui.PresentationEvents.StridePlanChanged; ...
                'DeclaredWork',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'PlanValidation',lmz.gui.PresentationEvents.StridePlanChanged; ...
                'AxisVariables',lmz.gui.PresentationEvents.BranchViewChanged; ...
                'OscillatorIndex',lmz.gui.PresentationEvents.SelectionChanged; ...
                'CurrentRun',lmz.gui.PresentationEvents.RunStateChanged; ...
                'RecordingState',lmz.gui.PresentationEvents.RunStateChanged; ...
                'Status',lmz.gui.PresentationEvents.StatusChanged; ...
                'StatusMessages',lmz.gui.PresentationEvents.StatusChanged};
            bus=obj.Events;
            for index=1:size(mappings,1)
                propertyName=mappings{index,1};topic=mappings{index,2};
                listener=addlistener(obj.State,propertyName,'PostSet', ...
                    @(~,~)bus.publish(topic,struct('Property',propertyName)));
                obj.StateListeners{end+1}=listener;
            end
        end

        function configuration=defaultProblemConfiguration(obj,modelId,problemId)
            catalog=[];
            try
                catalog=obj.Registry.getPoincareSectionRegistry(modelId);
                defaults=catalog.DefaultSectionByProblem;
                if isfield(defaults,problemId)
                    sectionId=defaults.(problemId);
                elseif catalog.hasSection('apex')
                    sectionId='apex';
                else
                    ids=catalog.listSections();sectionId=ids{1};
                end
                if strcmp(problemId,'section_transition')
                    [startId,stopId]=defaultTransitionSections( ...
                        catalog,sectionId);
                    start=catalog.descriptor(startId);
                    stop=catalog.descriptor(stopId);
                    configuration=completeSectionConfiguration(struct( ...
                        'StartSectionId',startId,'StopSectionId',stopId), ...
                        start,stop,catalog);
                else
                    descriptor=catalog.descriptor(sectionId);
                    configuration=completeSectionConfiguration(struct( ...
                        'StartSectionId',sectionId, ...
                        'StopSectionId',sectionId), ...
                        descriptor,descriptor,catalog);
                end
            catch
                configuration=struct();
            end
            configuration.StrideCount=1;
            if any(strcmp(problemId,{'multiple_shooting', ...
                    'multiple_shooting_horizon','section_transition'}))
                configuration.ShootingFormulation='multiple_shooting';
                if strcmp(problemId,'section_transition')
                    configuration.Formulation='transition';
                    configuration.EventFreeMask=false;
                    horizonLength=1;
                else
                    configuration.Formulation='periodic';
                    configuration.EventFreeMask=[true true];
                    horizonLength=max(2,obj.State.RequestedStrideCount);
                end
                configuration.Solver='auto';
                configuration.InterfaceStateMask=true;
                configuration.ControlFreeMask=false;
                configuration.EnergyWorkMode='diagnostic_only';
                if strcmp(problemId,'multiple_shooting_horizon')
                    configuration.EnergyWorkMode='energy_neutral';
                end
                configuration.ResidualTolerance=1e-7;
                configuration.HorizonLength=horizonLength;
                configuration.TemplateInitializer='schema_defaults';
                model=obj.Registry.createModel(modelId);
                hasTransition=any(strcmp( ...
                    model.listProblems(),'section_transition'));
                if strcmp(problemId,'multiple_shooting')&& ...
                        hasTransition&&~isempty(catalog)
                    descriptor=catalog.descriptor( ...
                        configuration.StartSectionId);
                    coordinateCount=numel(descriptor.CoordinateNames);
                    configuration.InterfaceStateMask= ...
                        defaultScientificInterfaceMask( ...
                        coordinateCount,horizonLength);
                    configuration.EventFreeMask=false;
                end
            end
            if any(strcmp(problemId,{'n_stride_simulation', ...
                    'n_stride_periodic','contact_timing_sequence'}))
                configuration.NumberOfStrides=max(1, ...
                    obj.State.RequestedStrideCount);
            end
        end

        function value=solveModeForProblem(~,problemId)
            if strcmp(problemId,'section_return_timing')
                value='Contact timings only';
            elseif strcmp(problemId,'n_stride_periodic')
                value='N-stride periodic orbit';
            elseif strcmp(problemId,'contact_timing_sequence')
                value='Timing sequence';
            elseif any(strcmp(problemId,{'multiple_shooting', ...
                    'multiple_shooting_horizon','section_transition'}))
                value='Multiple shooting';
            else
                value='Periodic orbit';
            end
        end

        function value=problemConfigurationForCreation(obj,problemId,value)
            if strcmp(problemId,'n_stride_simulation')
                allowed={'NumberOfStrides','InitialDecision','StridePlan', ...
                    'CompletionPolicy','EnergyPolicy','EnergyNeutralOnly', ...
                    'FailurePolicy','StartSectionId','StopSectionId', ...
                    'ProviderCallback','ParameterOverrides','DeclaredWork', ...
                    'MaximumStrides','Provenance'};
                names=fieldnames(value);remove=names(~ismember(names,allowed));
                if ~isempty(remove),value=rmfield(value,remove);end
            elseif strcmp(problemId,'multiple_shooting_horizon')
                count=fieldOr(value,'HorizonLength', ...
                    fieldOr(value,'NumberOfStrides',3));
                value.NumberOfStrides=count;
                value.FreeNodeMask=loadNodeMask(fieldOr(value, ...
                    'InterfaceStateMask',true),count);
                value.FreeControlMask=loadControlMask(fieldOr(value, ...
                    'ControlFreeMask',false),count);
                value.EnergyMode=fieldOr(value,'EnergyWorkMode', ...
                    'diagnostic_only');
                initializer=fieldOr(value,'TemplateInitializer', ...
                    'schema_defaults');
                [templateId,value.InitializationStrategy, ...
                    value.UseTemplateControls]=loadInitializer(initializer);
                if ~isempty(templateId),value.TemplateId=templateId;end
            elseif strcmp(problemId,'multiple_shooting')&& ...
                    any(strcmp(obj.Registry.createModel( ...
                    obj.State.ModelId).listProblems(),'section_transition'))
                count=fieldOr(value,'HorizonLength',2);
                catalog=obj.Registry.getPoincareSectionRegistry( ...
                    obj.State.ModelId);
                sectionId=fieldOr(value,'StartSectionId', ...
                    catalog.DefaultSectionByProblem.multiple_shooting);
                descriptor=catalog.descriptor(sectionId);
                coordinateCount=numel(descriptor.CoordinateNames);
                value.InterfaceStateMask=scientificInterfaceMask( ...
                    fieldOr(value,'InterfaceStateMask',[]), ...
                    coordinateCount,count);
            end
        end

        function value=multiStrideConfiguration(obj)
            value=struct('NumberOfStrides',obj.State.RequestedStrideCount, ...
                'CompletionPolicy',obj.State.CompletionPolicy, ...
                'FailurePolicy',obj.State.FailurePolicy, ...
                'EnergyNeutralOnly',obj.State.EnergyNeutralOnly);
            if obj.State.EnergyNeutralOnly
                value.EnergyPolicy=lmz.multistride.EnergyConsistencyPolicy();
            else
                value.EnergyPolicy=lmz.multistride.EnergyConsistencyPolicy( ...
                    'Id','allow_non_neutral');
            end
            configuration=obj.State.ProblemConfiguration;
            value.StartSectionId=fieldOr(configuration, ...
                'StartSectionId','apex');
            value.StopSectionId=fieldOr(configuration, ...
                'StopSectionId','apex');
            if ~isempty(obj.State.StridePlan)
                value.StridePlan=obj.State.StridePlan;
            elseif ~isempty(obj.State.WorkingSolution)&& ...
                    strcmp(obj.State.WorkingSolution.ProblemId, ...
                    'multi_stride_fit')&& ...
                    numel(obj.State.WorkingSolution.DecisionValues)>=44
                value.InitialDecision=obj.State.WorkingSolution.DecisionValues;
            end
            value.ParameterOverrides=obj.State.StrideParameterOverrides;
            value.DeclaredWork=obj.State.DeclaredWork;
        end

        function initializeGenericModel(obj,model,problemId)
            problem=model.createProblem(problemId, ...
                obj.problemConfigurationForCreation( ...
                problemId,obj.State.ProblemConfiguration));
            obj.State.RoadMapCatalog=[];obj.State.Datasets={};
            obj.State.ActiveDatasetId='';obj.State.Selection=[];
            obj.State.LockedSelection=[];obj.State.HoverSelection=[];
            if isa(problem,'lmz.api.SimulationProblem')|| ...
                    isa(problem,'lmz.multistride.NStrideSimulationProblem')
                obj.State.WorkingSolution=obj.makeTutorialSolution(problemId);
            else
                obj.State.WorkingSolution=problem.makeSolution( ...
                    problem.getDecisionSchema().defaults(), ...
                    problem.getParameterSchema().defaults(),[]);
            end
            obj.State.Status=sprintf('Selected %s; no built-in branch dataset.', ...
                obj.State.ModelId);
        end

        function [problem,options]=demoProblem(obj)
            problemIds=obj.simulationProblemIds();
            if isempty(problemIds)
                error('lmz:GUI:DemoUnavailable', ...
                    ['The selected model does not provide an implemented ' ...
                    'simulation problem.']);
            end
            examples=obj.builtInExamples();
            if isempty(examples)
                problemId=problemIds{1};
                if any(strcmp(obj.State.ProblemId,problemIds))
                    problemId=obj.State.ProblemId;
                end
                options=struct();
            else
                example=lmz.services.DataService().loadBuiltInExample( ...
                    obj.State.ModelId,obj.State.ExampleId);
                problemId=char(example.problemId);
                options=example.options;
                if ~any(strcmp(problemId,problemIds))
                    error('lmz:GUI:InvalidDemoProblem', ...
                        ['Built-in example %s targets %s, which is not an ' ...
                        'implemented simulation problem for %s.'], ...
                        obj.State.ExampleId,problemId,obj.State.ModelId);
                end
            end
            model=obj.Registry.createModel(obj.State.ModelId);
            problem=model.createProblem(problemId,struct());
            if ~isa(problem,'lmz.api.SimulationProblem')
                error('lmz:GUI:InvalidDemoProblem', ...
                    ['Problem %s is declared as a simulation but does not ' ...
                    'implement lmz.api.SimulationProblem.'],problemId);
            end
        end

        function options=simulationOptions(obj,problemId)
            options=struct();
            examples=obj.builtInExamples();
            if isempty(examples),return,end
            example=lmz.services.DataService().loadBuiltInExample( ...
                obj.State.ModelId,obj.State.ExampleId);
            if strcmp(char(example.problemId),problemId)
                options=example.options;
            end
        end

        function ids=simulationProblemIds(obj)
            candidates=obj.problemIds();
            selected=false(size(candidates));
            for index=1:numel(candidates)
                descriptor=obj.Registry.getProblemDescriptor( ...
                    obj.State.ModelId,candidates{index});
                selected(index)=strcmp(descriptor.kind,'simulation')&& ...
                    descriptor.implemented&&descriptor.capabilities.simulate;
            end
            ids=candidates(selected);
        end

        function options=wrapContinuationCallbacks(obj,options)
            if nargin<2||isempty(options),options=struct();end
            prediction=fieldOr(options,'PredictionFcn',[]);
            accepted=fieldOr(options,'AcceptedFcn',[]);
            rejected=fieldOr(options,'RejectedFcn',[]);
            options.PredictionFcn=@(state)obj.continuationProgress( ...
                'prediction',state,prediction);
            options.AcceptedFcn=@(state)obj.continuationProgress( ...
                'accepted',state,accepted);
            options.RejectedFcn=@(state)obj.continuationProgress( ...
                'rejected',state,rejected);
        end

        function continuationProgress(obj,phase,state,userCallback)
            obj.State.ContinuationPreview=struct('Phase',phase,'State',state);
            if isa(userCallback,'function_handle'),userCallback(state);end
        end

        function stop=solveProgressUpdate(obj,eventName,snapshot, ...
                userCallbacks)
            overlay=obj.State.OverlayState;
            if ~isstruct(overlay)||~isscalar(overlay),overlay=struct();end
            overlay.Solve=struct('Event',eventName, ...
                'Snapshot',snapshot.toStruct());
            obj.State.OverlayState=overlay;
            obj.State.Status=solveStageText(eventName,snapshot);
            obj.Events.publish( ...
                lmz.gui.PresentationEvents.SolveProgressChanged, ...
                struct('Event',eventName,'Snapshot',snapshot.toStruct()));
            drawnow limitrate
            stop=userCallbacks.notify(eventName,snapshot);
        end

        function invalidateDerived(obj)
            obj.State.WorkingEvaluation=[];obj.State.CandidateSimulation=[];obj.State.Simulation=[];
            obj.State.SolvedSolution=[];obj.State.SolveResult=[];
            obj.State.SolveProgress=[];obj.State.SeedPair=[];
            obj.State.ShootingResult=[];obj.State.TimingResult=[];
            obj.State.SectionTransferResult=[];
            obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            obj.State.HomotopyResult=[];obj.State.FamilyScanResult=[];
            obj.State.OptimizationResult=[];
        end
        function applyEvaluation(obj,problem,evaluation)
            original=obj.State.WorkingSolution;
            evaluated=problem.makeSolution(original.DecisionValues,original.ParameterValues,evaluation);
            value=evaluated.toStruct();value.Provenance=original.Provenance;value.Lineage=original.Lineage;
            obj.State.WorkingSolution=lmz.data.Solution.fromStruct(value);
        end
        function finishCurrentRun(obj)
            wasCancelled=obj.Context.Cancellation.IsCancellationRequested;seed=obj.Context.RandomSeed;obj.State.CurrentRun=[];
            if wasCancelled,obj.Context=lmz.api.RunContext.synchronous(seed);end
        end
        function value=hasActiveWorkflowSession(obj)
            value=~isempty(obj.State.WorkflowId)&& ...
                isa(obj.State.WorkflowSession,'lmz.workflow.WorkflowSession')&& ...
                strcmp(obj.State.WorkflowSession.Descriptor.ModelId, ...
                obj.State.ModelId)&& ...
                ~isempty(obj.State.LockedSelection)&& ...
                strcmp(obj.State.LockedSelection.DatasetId, ...
                obj.State.WorkflowSession.Dataset.Id)&& ...
                obj.State.LockedSelection.PointIndex== ...
                obj.State.WorkflowSession.SeedIndex&& ...
                ~isempty(obj.State.WorkingSolution)&& ...
                strcmp(obj.State.WorkflowSession.Problem.Id, ...
                obj.State.WorkingSolution.ProblemId);
        end
        function value=workflowSessionOwnsWorkingSolution(obj)
            value=obj.hasActiveWorkflowSession()&& ...
                sameRunContext(obj.State.WorkflowSession.Context,obj.Context)&& ...
                sameSolutionValues(obj.State.WorkflowSession.WorkingSolution, ...
                obj.State.WorkingSolution);
        end
        function value=workflowSessionOwnsSeedPair(obj)
            value=obj.hasActiveWorkflowSession()&& ...
                sameRunContext(obj.State.WorkflowSession.Context,obj.Context)&& ...
                sameSolutionPairValues(obj.State.WorkflowSession.SeedPair, ...
                obj.State.SeedPair);
        end
        function assertWorkflowAllows(obj,aliases,operation)
            descriptor=obj.activeWorkflowDescriptor();
            if isempty(descriptor)||workflowAllowsAny(descriptor,aliases)
                return
            end
            error('lmz:GUI:WorkflowStepUnavailable', ...
                'Registered workflow %s does not allow %s.', ...
                descriptor.Id,operation);
        end
        function value=activeWorkflowDescriptor(obj)
            value=[];
            if isempty(obj.State.WorkflowId),return,end
            try
                value=obj.Workflows.get( ...
                    obj.State.ModelId,obj.State.WorkflowId);
            catch
                value=[];
            end
        end
        function finishRecording(obj),obj.State.RecordingState=struct('Active',false);end
        function dataset=findDataset(obj,id)
            dataset=[];for index=1:numel(obj.State.Datasets),if strcmp(obj.State.Datasets{index}.Id,id),dataset=obj.State.Datasets{index};break,end,end
            if isempty(dataset),error('lmz:GUI:DatasetMissing','Dataset is missing.');end
        end
        function problem=problem(obj,id)
            configuration=obj.defaultProblemConfiguration(obj.State.ModelId,id);
            if strcmp(id,obj.State.ProblemId)&& ...
                    isstruct(obj.State.ProblemConfiguration)
                configuration=obj.State.ProblemConfiguration;
            end
            problem=obj.Registry.createModel(obj.State.ModelId).createProblem( ...
                id,obj.problemConfigurationForCreation(id,configuration));
        end
        function [dataset,index]=problemDataset(obj,problemId)
            dataset=[];index=1;
            if ~isempty(obj.State.LockedSelection)
                try
                    candidate=obj.findDataset(obj.State.LockedSelection.DatasetId);
                    if strcmp(candidate.Branch.ProblemId,problemId)
                        dataset=candidate;
                        index=min(obj.State.LockedSelection.PointIndex, ...
                            candidate.Branch.pointCount());
                        return
                    end
                catch
                end
            end
            order=1:numel(obj.State.Datasets);
            if ~isempty(obj.State.ActiveDatasetId)
                active=find(cellfun(@(item)strcmp(item.Id, ...
                    obj.State.ActiveDatasetId),obj.State.Datasets),1);
                if ~isempty(active),order=[active order(order~=active)];end
            end
            for candidateIndex=order
                candidate=obj.State.Datasets{candidateIndex};
                if strcmp(candidate.Branch.ModelId,obj.State.ModelId)&& ...
                        strcmp(candidate.Branch.ProblemId,problemId)
                    dataset=candidate;break
                end
            end
            if isempty(dataset),return,end
            resolved=false;
            datasetId=fieldOr(dataset.Metadata,'DatasetId','');
            if ~isempty(datasetId)
                try
                    [source,provider]=obj.registeredSourceForDataset(datasetId);
                    if strcmp(source.ProblemId,problemId)
                        index=provider.recommendedPoint(source,dataset);
                        resolved=true;
                    end
                catch
                    % User and historical datasets need not be registered.
                end
            end
            if ~resolved&&isstruct(dataset.Metadata)&& ...
                    isfield(dataset.Metadata,'RecommendedPointIndex')
                index=dataset.Metadata.RecommendedPointIndex;
                resolved=true;
            end
            if ~resolved&&~isempty(dataset.SourcePath)&& ...
                    ~isempty(obj.State.RoadMapCatalog)&& ...
                    ismethod(obj.State.RoadMapCatalog,'recommendedSeedIndex')
                try
                    index=obj.State.RoadMapCatalog.recommendedSeedIndex( ...
                        dataset.SourcePath);
                catch
                    index=1;
                end
            end
            index=max(1,min(index,dataset.Branch.pointCount()));
        end
        function solution=makeTutorialSolution(obj,problemId)
            schema=lmz.schema.VariableSchema();
            manifest=obj.Registry.getManifest(obj.State.ModelId);
            value=struct('Id',lmz.util.Ids.new('solution'), ...
                'ModelId',obj.State.ModelId,'ModelVersion',manifest.version, ...
                'ProblemId',problemId,'ProblemVersion','1.0.0', ...
                'DecisionSchema',schema,'ParameterSchema',schema, ...
                'DecisionValues',zeros(0,1),'ParameterValues',zeros(0,1), ...
                'Observables',struct(), ...
                'ResidualBlocks',lmz.data.ResidualBlock.empty(0,1), ...
                'Diagnostics',struct('Status','tutorial'), ...
                'Classification',struct(),'Feasibility',struct('Valid',true), ...
                'Lineage',struct(), ...
                'Provenance',struct('source','built-in-tutorial'), ...
                'CreatedAt',lmz.compat.Timestamp.current());
            solution=lmz.data.Solution(value);
        end
        function datasets=writableDatasets(obj)
            datasets={};for index=1:numel(obj.State.Datasets),if ~obj.State.Datasets{index}.ReadOnly,datasets{end+1}=obj.State.Datasets{index};end,end %#ok<AGROW>
        end
    end
end

function value=completeSectionConfiguration(value,start,stop,catalog)
defaults=struct('StartStateSide',start.StateSide, ...
    'StopStateSide',stop.StateSide, ...
    'CrossingDirection',stop.CrossingDirection, ...
    'MinimumReturnTime',stop.MinimumReturnTime, ...
    'RequiredEventSequence',{stop.RequiredEventSequence}, ...
    'ReturnOccurrence',stop.ReturnOccurrence, ...
    'SymmetryId',catalog.symmetryFor(stop.Id).Id);
names=fieldnames(defaults);
for index=1:numel(names)
    if ~isfield(value,names{index}),value.(names{index})=defaults.(names{index});end
end
if ~ischar(value.StartStateSide)||~ischar(value.StopStateSide)|| ...
        ~any(strcmp(value.StartStateSide,{'pre','post'}))|| ...
        ~any(strcmp(value.StopStateSide,{'pre','post'}))
    error('lmz:GUI:SectionSide','Section side must be pre or post.');
end
if ~isnumeric(value.CrossingDirection)|| ...
        ~isscalar(value.CrossingDirection)|| ...
        ~ismember(value.CrossingDirection,[-1 0 1])
    error('lmz:GUI:SectionDirection', ...
        'Section crossing direction must be -1, 0, or 1.');
end
if ~isnumeric(value.MinimumReturnTime)|| ...
        ~isscalar(value.MinimumReturnTime)|| ...
        ~isfinite(value.MinimumReturnTime)||value.MinimumReturnTime<0
    error('lmz:GUI:MinimumReturnTime', ...
        'Minimum return time must be finite and nonnegative.');
end
end

function value=validateShootingConfiguration(value)
defaults=struct('ShootingFormulation','multiple_shooting', ...
    'Formulation','periodic','Solver','auto', ...
    'InterfaceStateMask',true,'EventFreeMask',[true true], ...
    'ControlFreeMask',false,'EnergyWorkMode','diagnostic_only', ...
    'ResidualTolerance',1e-7,'HorizonLength',2, ...
    'TemplateInitializer','schema_defaults');
names=fieldnames(defaults);
for index=1:numel(names)
    if ~isfield(value,names{index}),value.(names{index})=defaults.(names{index});end
end
if ~ischar(value.ShootingFormulation)||~any(strcmp( ...
        value.ShootingFormulation,{'single_shooting','multiple_shooting', ...
        'timing_only','horizon_feasibility'}))
    error('lmz:GUI:ShootingFormulation','Shooting formulation is invalid.');
end
if ~ischar(value.Formulation)|| ...
        ~any(strcmp(value.Formulation,{'periodic','transition','feasibility'}))
    error('lmz:GUI:ShootingFormulation','Horizon formulation is invalid.');
end
if ~ischar(value.Solver)||~any(strcmp(value.Solver, ...
        {'auto','fsolve','lsqnonlin','fmincon_feasibility'}))
    error('lmz:GUI:ShootingSolver','Shooting solver selection is invalid.');
end
masks={'InterfaceStateMask','EventFreeMask','ControlFreeMask'};
for index=1:numel(masks)
    item=value.(masks{index});
    if ~(islogical(item)|| ...
            (isnumeric(item)&&isreal(item)&&all(ismember(item(:),[0 1]))))
        error('lmz:GUI:ShootingMask','%s must be a logical mask.',masks{index});
    end
    value.(masks{index})=logical(item);
end
if ~ischar(value.EnergyWorkMode)||~any(strcmp(value.EnergyWorkMode, ...
        {'energy_neutral','bounded_work','prescribed_work','diagnostic_only'}))
    error('lmz:GUI:ShootingEnergy','Energy/work mode is invalid.');
end
if ~isnumeric(value.ResidualTolerance)|| ...
        ~isscalar(value.ResidualTolerance)|| ...
        ~isfinite(value.ResidualTolerance)||value.ResidualTolerance<=0
    error('lmz:GUI:ShootingTolerance', ...
        'Residual tolerance must be finite and positive.');
end
if ~isnumeric(value.HorizonLength)||~isscalar(value.HorizonLength)|| ...
        ~isfinite(value.HorizonLength)||value.HorizonLength<1|| ...
        value.HorizonLength~=fix(value.HorizonLength)
    error('lmz:GUI:ShootingHorizon', ...
        'Horizon length must be a positive integer.');
end
if ~ischar(value.TemplateInitializer)||isempty(value.TemplateInitializer)
    error('lmz:GUI:ShootingInitializer', ...
        'Template initializer must be nonempty text.');
end
end

function value=loadNodeMask(source,strideCount)
source=logical(source);
widths=[14 15];nodeCount=strideCount+1;
if isscalar(source)
    value=source;
else
    value=[];
    for width=widths
        if isvector(source)&&numel(source)==width
            value=repmat(reshape(source,1,[]),nodeCount,1);break
        elseif isequal(size(source),[nodeCount width])
            value=source;break
        elseif numel(source)==nodeCount*width
            value=reshape(source,width,nodeCount).';break
        end
    end
    if isempty(value)
        error('lmz:GUI:LoadShootingNodeMask', ...
            ['Load interface masks must be scalar, 14-coordinate apex or ' ...
            '15-coordinate stride-boundary masks, or one mask per N+1 node.']);
    end
end
end

function value=loadControlMask(source,strideCount)
source=logical(source);width=4;
if isscalar(source)
    value=source;
elseif isvector(source)&&numel(source)==width
    value=repmat(reshape(source,1,[]),strideCount,1);
elseif numel(source)==strideCount*width
    value=reshape(source,width,strideCount).';
else
    error('lmz:GUI:LoadShootingControlMask', ...
        ['Load control masks must be scalar, four stiffness entries, or ' ...
        'four entries for each stride.']);
end
end

function [templateId,strategy,useTemplateControls]=loadInitializer(source)
useTemplateControls=false;templateId='';
switch source
    case {'schema_defaults','exact_source_horizon'}
        strategy='exact_source_horizon';
    case 'nearest_compatible_template'
        strategy='nearest_compatible_template';
        useTemplateControls=true;
    case 'phase_compatible_repeat'
        strategy='phase_compatible_repeat';
    otherwise
        if ~ischar(source)||isempty(regexp(source, ...
                '^[A-Za-z][A-Za-z0-9_]*$','once'))
            error('lmz:GUI:ShootingInitializer', ...
                'A registered shooting initializer ID is required.');
        end
        templateId=source;strategy='exact_source_horizon';
end
end

function value=sectionStatePlaneSummary(descriptor)
value='';
if ~strcmp(descriptor.kind,'state_plane'),return,end
value=sprintf('state plane %s = %.12g, direction %d', ...
    descriptor.stateName,descriptor.threshold,descriptor.crossingDirection);
end

function value=scientificTransitionKind(kind)
value=any(strcmp(kind,{'named_event','state_plane','composite'}));
end

function [startId,stopId]=defaultTransitionSections(catalog,startId)
stopId='';ids=catalog.listSections();
for index=1:numel(ids)
    descriptor=catalog.descriptor(ids{index});
    if ~strcmp(descriptor.Id,startId)&& ...
            strcmp(descriptor.Kind,'state_plane')&& ...
            strcmp(descriptor.StateName,'y')&& ...
            descriptor.CrossingDirection<0&& ...
            any(strcmp(descriptor.ValidationStatus, ...
            {'tested','source-equivalent'}))
        stopId=descriptor.Id;break
    end
end
if ~catalog.hasSection(startId)||isempty(stopId)
    error('lmz:GUI:TransitionDefaults', ...
        'The catalog does not provide distinct tested transition defaults.');
end
end

function value=defaultScientificInterfaceMask(coordinateCount,count)
value=false(coordinateCount,count+1);
if count>1,value(:,2:count)=true;end
end

function value=scientificInterfaceMask(source,coordinateCount,count)
if isempty(source)
    value=defaultScientificInterfaceMask(coordinateCount,count);return
end
if ~(islogical(source)||(isnumeric(source)&&isreal(source)&& ...
        all(ismember(source(:),[0 1]))))
    error('lmz:GUI:ScientificShootingMask', ...
        'The scientific interface mask must be logical.');
end
source=logical(source);
if isscalar(source)|| ...
        (isvector(source)&&numel(source)==coordinateCount)|| ...
        isequal(size(source),[coordinateCount count+1])
    value=source;
elseif numel(source)==coordinateCount*(count+1)
    value=reshape(source,coordinateCount,count+1);
elseif mod(numel(source),coordinateCount)==0
    value=defaultScientificInterfaceMask(coordinateCount,count);
else
    error('lmz:GUI:ScientificShootingMask', ...
        ['The scientific interface mask must be scalar, one section ' ...
        'coordinate vector, or coordinate-by-(N+1).']);
end
end

function [value,qualification]=scientificTransitionSupport(~,stop)
value='validated';
if strcmp(stop.kind,'state_plane')
    qualification=['tolerance-satisfying transition seed; ' ...
        'no periodic-root claim'];
else
    qualification=['accepted-crossing candidate with a nonzero contact ' ...
        'residual; no root or periodic claim'];
end
end

function value=sectionCompositeSummary(descriptor)
value='';
if ~strcmp(descriptor.kind,'composite'),return,end
parameters=descriptor.parameters;primary='unspecified';conditions={};
if isfield(parameters,'primarySectionId'),primary=parameters.primarySectionId;end
if isfield(parameters,'conditions')
    source=parameters.conditions;
    if isstruct(source),source=num2cell(source(:));end
    if iscell(source)
        for index=1:numel(source)
            conditions{end+1}=compositeConditionText(source{index}); %#ok<AGROW>
        end
    end
end
if isempty(conditions)
    conditionText='not declared';
else
    conditionText=strjoin(conditions,' | ');
end
value=sprintf('composite primary %s; conditions: %s', ...
    primary,conditionText);
end

function value=compositeConditionText(condition)
if ~isstruct(condition)||~isscalar(condition)
    value='unreadable condition';return
end
parts={};kind=fieldOr(condition,'kind','condition');
if isfield(condition,'stateName')
    parts{end+1}=['state ' char(condition.stateName)];
elseif isfield(condition,'eventId')
    parts{end+1}=['event ' char(condition.eventId)];
elseif isfield(condition,'eventName')
    parts{end+1}=['event ' char(condition.eventName)];
else
    parts{end+1}=strrep(char(kind),'_',' ');
end
if isfield(condition,'comparator')
    parts{end+1}=['comparator ' char(condition.comparator)];
end
if isfield(condition,'threshold')&&isnumeric(condition.threshold)&& ...
        isscalar(condition.threshold)
    parts{end+1}=sprintf('threshold %.12g',condition.threshold);
end
if isfield(condition,'tolerance')&&isnumeric(condition.tolerance)&& ...
        isscalar(condition.tolerance)
    parts{end+1}=sprintf('tolerance %.12g',condition.tolerance);
end
if isfield(condition,'stateSide')
    parts{end+1}=['side ' char(condition.stateSide)];
end
value=strjoin(parts,', ');
end

function value=appendSectionSummary(reason,statePlane,composite)
details={};
if ~isempty(statePlane),details{end+1}=statePlane;end
if ~isempty(composite),details{end+1}=composite;end
if isempty(details),value=reason;else
    value=[reason '; ' strjoin(details,'; ')];
end
end

function values=providerRecords(source)
if isempty(source),values={}; ...
elseif iscell(source),values=reshape(source,1,[]); ...
elseif isstruct(source),values=num2cell(reshape(source,1,[])); ...
elseif ischar(source),values={source}; ...
else
    error('lmz:GUI:ProviderRecords', ...
        'Registered provider records must be structs or text.');
end
end

function value=providerRecordField(source,names,fallback)
value=fallback;
if ischar(source)
    if any(strcmp(names,'id'))||any(strcmp(names,'name')),value=source;end
    return
end
for index=1:numel(names)
    if isstruct(source)&&isfield(source,names{index})
        value=source.(names{index});return
    end
end
end

function valid=providerRecordMatches(record,requested)
fields={'id','Id','name','label','path','sourcePath','Path'};
values=cell(1,numel(fields));
for index=1:numel(fields)
    values{index}=providerRecordField(record,fields(index),'');
end
[~,requestedBase,requestedExtension]=fileparts(requested);
requestedFile=[requestedBase requestedExtension];
valid=false;
for index=1:numel(values)
    value=values{index};
    if ~ischar(value),continue,end
    [~,base,extension]=fileparts(value);file=[base extension];
    if strcmp(requested,value)||strcmp(requested,file)|| ...
            (~isempty(requestedFile)&&strcmp(requestedFile,file))
        valid=true;return
    end
end
end

function values=completeAxisNames(values)
if isstring(values),values=cellstr(values);end
values=reshape(values,1,[]);
if numel(values)<2
    error('lmz:GUI:AxisPreset', ...
        'A registered axis preset must provide at least two coordinates.');
end
if numel(values)<3,values{3}='';else,values=values(1:3);end
end

function value=axisLimitText(source)
if isempty(source),value='auto';else,value=mat2str(source,17);end
end

function value=mergeOptions(defaults,overrides)
if ~isstruct(defaults)||~isscalar(defaults)|| ...
        ~isstruct(overrides)||~isscalar(overrides)
    error('lmz:GUI:Options','Registered options must be scalar structs.');
end
value=defaults;names=fieldnames(overrides);
for index=1:numel(names),value.(names{index})=overrides.(names{index});end
end

function capabilities=restrictWorkflowCapabilities(capabilities,descriptor)
mappings={ ...
    'simulate',{'simulate','simulation'}; ...
    'solve',{'solve','root_solve'}; ...
    'continue',{'continuation','continue'}; ...
    'optimize',{'optimize','optimization'}; ...
    'visualize',{'analysis','visualize','simulation','simulate'}; ...
    'animate',{'analysis','visualize','simulation','simulate'}; ...
    'parameterHomotopy',{'parameter_homotopy','homotopy'}; ...
    'branchFamilyScan',{'branch_family','family_scan'}};
for index=1:size(mappings,1)
    name=mappings{index,1};
    if isfield(capabilities,name)
        capabilities.(name)=logical(capabilities.(name))&& ...
            workflowAllowsAny(descriptor,mappings{index,2});
    end
end
end

function value=workflowAllowsAny(descriptor,aliases)
if ischar(aliases),aliases={aliases};end
value=false;
for index=1:numel(aliases)
    if descriptor.allows(aliases{index}),value=true;return,end
end
end

function value=sameRunContext(first,second)
value=isa(first,'lmz.api.RunContext')&& ...
    isa(second,'lmz.api.RunContext')&& ...
    isequal(first.Cancellation,second.Cancellation)&& ...
    isequal(first.Pause,second.Pause);
end

function value=sameSolutionValues(first,second)
value=isa(first,'lmz.data.Solution')&& ...
    isa(second,'lmz.data.Solution')&& ...
    strcmp(first.ModelId,second.ModelId)&& ...
    strcmp(first.ProblemId,second.ProblemId)&& ...
    isequaln(first.DecisionValues,second.DecisionValues)&& ...
    isequaln(first.ParameterValues,second.ParameterValues);
end

function value=sameSolutionPairValues(first,second)
value=isa(first,'lmz.data.SolutionPair')&& ...
    isa(second,'lmz.data.SolutionPair')&& ...
    sameSolutionValues(first.First,second.First)&& ...
    sameSolutionValues(first.Second,second.Second);
end

function pair=reverseSolutionPair(source)
pair=lmz.data.SolutionPair(source.Second,source.First, ...
    source.RequestedRadius,source.AchievedRadius,source.Diagnostics);
end

function restoreSeedPair(controller,pair)
if isvalid(controller),controller.State.SeedPair=pair;end
end

function value=solveStageText(eventName,snapshot)
switch eventName
    case 'seed_selected',value='Solve seed selected.';
    case 'seed_evaluated'
        value=sprintf('Seed residual %.3g.',snapshot.ScaledResidual);
    case 'projection_started',value='Projecting the solve seed.';
    case 'projection_completed',value='Seed projection complete.';
    case 'solve_started',value='Root solve started.';
    case 'iteration'
        value=sprintf('Solve iteration %g; residual %.3g.', ...
            snapshot.Iteration,snapshot.ScaledResidual);
    case 'step_accepted',value='Solver step accepted.';
    case 'solve_completed',value='Root solve complete.';
    case 'solve_failed',value='Root solve did not converge.';
    case 'controlled_stop',value='Root solve stopped with partial progress.';
    otherwise,value=snapshot.Message;
end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=onOff(condition),if condition,value='on';else,value='off';end,end
function values=objectiveValues(terms)
names=fieldnames(terms);values=zeros(numel(names),1);
for index=1:numel(names)
    item=terms.(names{index});
    if isnumeric(item)&&isscalar(item)
        values(index)=item;
    elseif isstruct(item)&&isfield(item,'Value')&&isscalar(item.Value)
        if isfield(item,'Weight'),values(index)=item.Value*item.Weight; ...
        else,values(index)=item.Value;end
    else
        values(index)=0;
    end
end
end
