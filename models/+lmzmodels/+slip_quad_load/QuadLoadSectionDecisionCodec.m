classdef QuadLoadSectionDecisionCodec < lmz.shooting.SectionDecisionCodec
    %QUADLOADSECTIONDECISIONCODEC Section-local state and cyclic schedule.
    %   The load source equations use eight contact events plus an
    %   integration endpoint.  A touchdown return removes that touchdown
    %   from the interior chart and places its next occurrence at the
    %   endpoint; apex and stride-boundary returns retain all contacts.
    properties (SetAccess=private)
        StartSection
        StopSection
        StateCoordinates
        TerminalStateCoordinates
        SourceFixedCoordinateNames
        ScheduleAdapter
        BaseState
        BaseStrideVector
        DecisionSchema
        EndpointContactIndex = 0
        EventNames
        SourceLineage
    end

    methods
        function obj=QuadLoadSectionDecisionCodec(startSection,stopSection, ...
                localEventTimes,returnTime,seedState,baseStrideVector,varargin)
            parser=inputParser;
            addParameter(parser,'SourceLineage',struct(), ...
                @(x)isstruct(x)&&isscalar(x));
            parse(parser,varargin{:});
            if ~isa(startSection,'lmz.poincare.PoincareSection')|| ...
                    ~isa(stopSection,'lmz.poincare.PoincareSection')
                error('lmz:QuadLoad:SectionCodecSections', ...
                    'Load section decisions require start and stop sections.');
            end
            validateSupportedPair(startSection,stopSection);
            schema=lmzmodels.slip_quad_load.PhysicalStateSchema.create();
            schema.validateVector(seedState);
            lmzmodels.slip_quad_load.FirstStrideLayout.validate( ...
                baseStrideVector);
            names=contactNames();times=localEventTimes(:);
            if ~isnumeric(times)||numel(times)~=numel(names)|| ...
                    any(~isfinite(times))||~isnumeric(returnTime)|| ...
                    ~isscalar(returnTime)||~isfinite(returnTime)||returnTime<=0
                error('lmz:QuadLoad:SectionScheduleSeed', ...
                    'Load section schedule seed data are invalid.');
            end
            endpoint=endpointContact(stopSection,names);
            schedule=interiorSchedule(startSection,stopSection,names, ...
                times,returnTime,endpoint);
            sourceFixed={'load_y','load_dy'};
            startNames=sourceSupportedCoordinates( ...
                startSection.Descriptor.CoordinateNames,sourceFixed);
            stopNames=sourceSupportedCoordinates( ...
                stopSection.Descriptor.CoordinateNames,sourceFixed);
            stateCoordinates=lmz.shooting.SectionStateSchema(schema,startNames);
            terminalStateCoordinates=lmz.shooting.SectionStateSchema( ...
                schema,stopNames);
            defaults=stateCoordinates.extract(seedState);
            stateSpecs=stateCoordinates.coordinateSchema().Specs;
            for index=1:numel(stateSpecs)
                value=stateSpecs(index).toStruct();
                value.DefaultValue=defaults(index);
                value.Group='section_initial_state';
                stateSpecs(index)=lmz.schema.VariableSpec.fromStruct(value);
            end
            adapter=lmz.shooting.SectionScheduleAdapter(schedule);
            obj.StartSection=startSection;obj.StopSection=stopSection;
            obj.StateCoordinates=stateCoordinates;obj.ScheduleAdapter=adapter;
            obj.TerminalStateCoordinates=terminalStateCoordinates;
            obj.SourceFixedCoordinateNames=sourceFixed;
            obj.BaseState=seedState(:);obj.BaseStrideVector=baseStrideVector(:);
            obj.EndpointContactIndex=endpoint;obj.EventNames=names;
            obj.SourceLineage=parser.Results.SourceLineage;
            obj.DecisionSchema=lmz.schema.VariableSchema( ...
                [stateSpecs;adapter.schema().Specs],'1.0.0');
        end

        function value=decisionSchema(obj,varargin)
            value=obj.DecisionSchema;
        end

        function value=encode(obj,state,eventTimes,returnTime)
            obj.StateCoordinates.PhysicalSchema.validateVector(state);
            if ~isnumeric(eventTimes)||numel(eventTimes)~=numel(obj.EventNames)
                error('lmz:QuadLoad:SectionEncodeTimes', ...
                    'Encoded event times do not match the load contact list.');
            end
            if nargin<4||isempty(returnTime)
                returnTime=obj.ScheduleAdapter.Chart.Template.ReturnTime;
            end
            template=obj.ScheduleAdapter.Chart.Template;
            names=template.names();times=zeros(numel(names),1);
            for index=1:numel(names)
                source=find(strcmp(names{index},obj.EventNames),1);
                times(index)=mod(eventTimes(source),returnTime);
            end
            schedule=template.withTimes(times,returnTime);
            value=[obj.StateCoordinates.extract(state); ...
                obj.ScheduleAdapter.encode(schedule)];
            obj.DecisionSchema.validateVector(value);
        end

        function value=decode(obj,decision)
            obj.DecisionSchema.validateVector(decision);
            stateCount=obj.StateCoordinates.count();
            coordinates=decision(1:stateCount);
            schedule=obj.ScheduleAdapter.decode(decision(stateCount+1:end));
            state=obj.StateCoordinates.embed(obj.BaseState,coordinates);
            eventTimes=NaN(numel(obj.EventNames),1);
            names=schedule.names();times=schedule.times();
            for index=1:numel(names)
                target=find(strcmp(names{index},obj.EventNames),1);
                eventTimes(target)=times(index);
            end
            if obj.EndpointContactIndex>0
                gap=max(256*eps(max(1,schedule.ReturnTime)),realmin);
                eventTimes(obj.EndpointContactIndex)=schedule.ReturnTime-gap;
            end
            if any(~isfinite(eventTimes))
                error('lmz:QuadLoad:SectionDecodedSchedule', ...
                    'The decoded contact schedule is incomplete.');
            end
            value=struct('InitialState',state, ...
                'InitialCoordinates',coordinates(:), ...
                'EventTimes',eventTimes,'ReturnTime',schedule.ReturnTime, ...
                'EventSchedule',schedule,'StartSectionId', ...
                obj.StartSection.Id,'StopSectionId',obj.StopSection.Id, ...
                'EndpointContactIndex',obj.EndpointContactIndex, ...
                'BaseStrideVector',obj.BaseStrideVector, ...
                'SourceLineage',obj.SourceLineage);
        end

        function value=toStruct(obj)
            value=toStruct@lmz.shooting.SectionDecisionCodec(obj);
            value.ModelId='slip_quad_load';
            value.StartSection=obj.StartSection.toStruct();
            value.StopSection=obj.StopSection.toStruct();
            value.StateCoordinates=obj.StateCoordinates.toStruct();
            value.TerminalStateCoordinates= ...
                obj.TerminalStateCoordinates.toStruct();
            value.SourceFixedCoordinateNames=obj.SourceFixedCoordinateNames;
            value.Schedule=obj.ScheduleAdapter.toStruct();
            value.EventNames=obj.EventNames;
            value.EndpointContactIndex=obj.EndpointContactIndex;
            value.BaseStrideVector=obj.BaseStrideVector;
            value.SourceLineage=obj.SourceLineage;
        end
    end

    methods (Static)
        function [obj,diagnostics]=fromTemplate(sectionId,templateId, ...
                strideIndex,context)
            if nargin<2||isempty(templateId)
                templateId='individual_1_tr_to_rl';
            end
            if nargin<3||isempty(strideIndex),strideIndex=1;end
            if nargin<4||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            models=lmz.registry.ModelRegistry.discover();
            registry=models.getPoincareSectionRegistry('slip_quad_load');
            section=registry.section(sectionId);
            library=lmzmodels.slip_quad_load.StrideTemplateLibrary();
            source=library.load(templateId,context);
            if strideIndex<1||strideIndex>source.StrideCount|| ...
                    strideIndex~=fix(strideIndex)
                error('lmz:QuadLoad:SectionTemplateStride', ...
                    'Template stride index is outside the source horizon.');
            end
            segment=source.Segments(strideIndex);
            controls=segment.ControlParameters;
            vector=lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                vector(segment.InitialSectionState,segment.EventSchedule, ...
                segment.PhysicalParameters,controls.PostSwingStiffness, ...
                controls.PreSwingStiffness);
            raw=lmzmodels.slip_quad_load.LegacyQuadLoadEvaluator(). ...
                evaluateStride(vector,context,false);
            canonical=segment.EventSchedule.Times(:);period=canonical(9);
            eventId=section.Descriptor.EventId;origin=0;
            seed=raw.LegacyStates(1,:).';method='source_section_state';
            if strcmp(eventId,'BL_TD')
                record=raw.EventRecords(strcmp({raw.EventRecords.Name},eventId));
                if numel(record)~=1
                    error('lmz:QuadLoad:SectionTemplateEvent', ...
                        'Template does not contain the requested touchdown.');
                end
                origin=record.Time;seed=record.PostState(:);
                method='source_event_post_state';
            elseif ~any(strcmp(eventId,{'APEX','STRIDE_BOUNDARY'}))
                error('lmz:QuadLoad:UnsupportedSection', ...
                    'Unsupported load section %s.',sectionId);
            end
            localTimes=mod(canonical(1:8)-origin,period);
            lineage=struct('Method',method,'TemplateId',templateId, ...
                'TemplateStrideIndex',strideIndex,'SourceHash', ...
                source.SourceHash,'SourceCommit',source.SourceCommit, ...
                'SeedTransferEvaluationOnly',strcmp(eventId,'BL_TD'));
            obj=lmzmodels.slip_quad_load.QuadLoadSectionDecisionCodec( ...
                section,section,localTimes,period,seed,vector, ...
                'SourceLineage',lineage);
            diagnostics=struct('SectionId',sectionId,'Method',method, ...
                'DirectResidualEvaluationRequiresApexLookup',false, ...
                'TemplateId',templateId,'TemplateStrideIndex',strideIndex, ...
                'SourceHash',source.SourceHash,'LocalEventTimes',localTimes, ...
                'ReturnTime',period);
        end
    end
end

function value=sourceSupportedCoordinates(value,sourceFixed)
% The preserved 44-entry source vector provides only load_x/load_dx as
% initial load state.  Do not expose load_y/load_dy as ineffective decision
% variables; they remain present in the full physical state and catalog.
value=reshape(value,1,[]);
value=value(~ismember(value,sourceFixed));
end

function value=contactNames()
value={'BL_TD','BL_LO','FL_TD','FL_LO', ...
    'BR_TD','BR_LO','FR_TD','FR_LO'};
end

function value=endpointContact(section,names)
value=find(strcmp(section.Descriptor.EventId,names),1);
if isempty(value),value=0;end
end

function value=interiorSchedule(startSection,stopSection,names,times, ...
        returnTime,endpoint)
times=mod(times,returnTime);keep=true(numel(names),1);
if endpoint>0,keep(endpoint)=false;end
interiorTimes=times(keep);interiorNames=names(keep);
[interiorTimes,order]=sort(interiorTimes,'ascend');
interiorNames=interiorNames(order);
separation=256*eps(max(1,returnTime));
for index=1:numel(interiorTimes)
    lower=separation;
    if index>1,lower=interiorTimes(index-1)+separation;end
    interiorTimes(index)=max(interiorTimes(index),lower);
    upper=returnTime-(numel(interiorTimes)-index+1)*separation;
    interiorTimes(index)=min(interiorTimes(index),upper);
end
if any(diff([0;interiorTimes;returnTime])<=0)
    error('lmz:QuadLoad:SectionScheduleOrder', ...
        'The load section seed has no strictly ordered cyclic chart.');
end
occurrences=lmz.schedule.EventOccurrence.empty(0,1);
for index=1:numel(interiorTimes)
    source=find(strcmp(interiorNames{index},names),1);
    occurrences(index,1)=lmz.schedule.EventOccurrence( ...
        interiorNames{index},interiorTimes(index),'Metadata', ...
        struct('CanonicalEventIndex',source));
end
value=lmz.schedule.EventSchedule(occurrences,returnTime, ...
    'MinimumGap',0,'StartSectionId',startSection.Id, ...
    'StopSectionId',stopSection.Id);
end

function validateSupportedPair(startSection,stopSection)
supported={'APEX','STRIDE_BOUNDARY','BL_TD'};
startId=startSection.Descriptor.EventId;
stopId=stopSection.Descriptor.EventId;
if ~any(strcmp(startId,supported))||~any(strcmp(stopId,supported))
    error('lmz:QuadLoad:UnsupportedSection', ...
        'Load section adapter supports apex, stride boundary, and BL touchdown.');
end
touchdown=strcmp(startId,'BL_TD')||strcmp(stopId,'BL_TD');
if touchdown&&~strcmp(startId,stopId)
    error('lmz:QuadLoad:UnsupportedSectionPair', ...
        'The validated touchdown path is BL touchdown to BL touchdown.');
end
if touchdown&&(~strcmp(startSection.StateSide,'post')|| ...
        ~strcmp(stopSection.StateSide,'post'))
    error('lmz:QuadLoad:UnsupportedSectionSide', ...
        'The validated load touchdown path uses post-event states.');
end
end
