classdef SectionTransitionDecisionCodec < lmz.shooting.SectionDecisionCodec
    %SECTIONTRANSITIONDECISIONCODEC Mixed-section state and schedule chart.
    %   A transition owns coordinates on its start section and an ordered
    %   list of events strictly inside the segment.  Canonical contact
    %   events that define the mode at a boundary remain explicit in
    %   BoundaryRoles, but are not introduced as zero-gap solver variables.
    properties (SetAccess=private)
        ModelId
        StartSection
        StopSection
        StateCoordinates
        StopStateCoordinates
        ScheduleAdapter
        EventNames
        InteriorEventIndices
        BoundaryRoles
        BaseEventTimes
        BaseState
        DecisionSchema
        SourceDecision
        ActiveContactNames
        MaximumTimeRegularization = 0
    end

    methods
        function obj=SectionTransitionDecisionCodec(modelId,physicalSchema, ...
                startSection,stopSection,eventNames,eventTimes,returnTime, ...
                seedState,varargin)
            parser=inputParser;
            addParameter(parser,'SourceDecision',[],@isnumeric);
            addParameter(parser,'InteriorEventNames',{},@isNameList);
            addParameter(parser,'ActiveContactNames',{},@isNameList);
            parse(parser,varargin{:});
            if ~ischar(modelId)||~isa(physicalSchema, ...
                    'lmz.schema.VariableSchema')||~isa(startSection, ...
                    'lmz.poincare.PoincareSection')||~isa(stopSection, ...
                    'lmz.poincare.PoincareSection')|| ...
                    strcmp(startSection.Id,stopSection.Id)
                error('lmz:Shooting:TransitionCodecInput', ...
                    ['A mixed-section transition codec requires a model, ' ...
                    'physical schema, and distinct start/stop sections.']);
            end
            if ischar(eventNames),eventNames={eventNames};end
            eventNames=reshape(eventNames,[],1);eventTimes=eventTimes(:);
            if ~iscell(eventNames)||~all(cellfun(@ischar,eventNames))|| ...
                    numel(unique(eventNames))~=numel(eventNames)|| ...
                    numel(eventNames)~=numel(eventTimes)|| ...
                    any(~isfinite(eventTimes))||any(eventTimes<0)|| ...
                    ~isnumeric(returnTime)||~isscalar(returnTime)|| ...
                    ~isfinite(returnTime)||returnTime<=0|| ...
                    any(eventTimes>returnTime)
                error('lmz:Shooting:TransitionScheduleSeed', ...
                    'Transition schedule seed data are invalid.');
            end
            physicalSchema.validateVector(seedState);
            interiorNames=reshape(parser.Results.InteriorEventNames,[],1);
            if isempty(interiorNames)
                tolerance=256*eps(max(1,returnTime));
                interior=find(eventTimes>tolerance& ...
                    eventTimes<returnTime-tolerance);
            else
                interior=zeros(numel(interiorNames),1);
                for index=1:numel(interiorNames)
                    match=find(strcmp(interiorNames{index},eventNames),1);
                    if isempty(match)
                        error('lmz:Shooting:TransitionInteriorEvent', ...
                            'Interior event %s is not canonical.', ...
                            interiorNames{index});
                    end
                    interior(index)=match;
                end
                if numel(unique(interior))~=numel(interior)
                    error('lmz:Shooting:TransitionInteriorEvent', ...
                        'Interior event names must be unique.');
                end
            end
            [~,order]=sortrows([eventTimes(interior),interior],[1 2]);
            interior=interior(order);times=eventTimes(interior);
            originalTimes=times;
            separation=256*eps(max(1,returnTime));
            for index=1:numel(times)
                lower=separation;
                if index>1,lower=times(index-1)+separation;end
                if times(index)<lower
                    times(index)=lower;
                end
            end
            for index=numel(times):-1:1
                upper=returnTime-separation;
                if index<numel(times),upper=times(index+1)-separation;end
                if times(index)>upper,times(index)=upper;end
            end
            if any(diff([0;times;returnTime])<=0)
                error('lmz:Shooting:TransitionScheduleOrder', ...
                    'Transition events do not define a positive-gap chart.');
            end
            eventTimes(interior)=times;
            roles=repmat({'return'},numel(eventNames),1);
            tolerance=max(separation,256*eps(max(1,returnTime)));
            roles(eventTimes<=tolerance)={'start'};
            roles(eventTimes>=returnTime-tolerance)={'return'};
            roles(interior)={'interior'};
            occurrences=lmz.schedule.EventOccurrence.empty(0,1);
            for index=1:numel(interior)
                occurrences(index,1)=lmz.schedule.EventOccurrence( ...
                    eventNames{interior(index)},times(index), ...
                    'Metadata',struct('CanonicalEventIndex',interior(index)));
            end
            schedule=lmz.schedule.EventSchedule(occurrences,returnTime, ...
                'MinimumGap',0,'StartSectionId',startSection.Id, ...
                'StopSectionId',stopSection.Id,'Metadata',struct( ...
                'Formulation','transition','BoundaryRoles',{roles}));
            stateCoordinates=lmz.shooting.SectionStateSchema( ...
                physicalSchema,startSection.Descriptor.CoordinateNames);
            stopCoordinates=lmz.shooting.SectionStateSchema( ...
                physicalSchema,stopSection.Descriptor.CoordinateNames);
            stateDefaults=stateCoordinates.extract(seedState);
            stateSpecs=stateCoordinates.coordinateSchema().Specs;
            for index=1:numel(stateSpecs)
                value=stateSpecs(index).toStruct();
                value.DefaultValue=stateDefaults(index);
                value.Group='transition_start_state';
                stateSpecs(index)=lmz.schema.VariableSpec.fromStruct(value);
            end
            scheduleAdapter=lmz.shooting.SectionScheduleAdapter(schedule);
            scheduleSpecs=scheduleAdapter.Chart.DecisionSchema.Specs;
            active=reshape(parser.Results.ActiveContactNames,[],1);
            if isempty(active)
                active=eventNames(interior);
                active=unique([active;localEndpointEvents( ...
                    startSection,stopSection,eventNames)],'stable');
            end
            for index=1:numel(active)
                if ~any(strcmp(active{index},eventNames))
                    error('lmz:Shooting:TransitionContactEvent', ...
                        'Active contact %s is not canonical.',active{index});
                end
            end
            obj.ModelId=modelId;obj.StartSection=startSection;
            obj.StopSection=stopSection;obj.StateCoordinates=stateCoordinates;
            obj.StopStateCoordinates=stopCoordinates;
            obj.ScheduleAdapter=scheduleAdapter;obj.EventNames=eventNames;
            obj.InteriorEventIndices=interior(:);
            obj.BoundaryRoles=roles;obj.BaseEventTimes=eventTimes(:);
            obj.BaseState=seedState(:);
            obj.DecisionSchema=lmz.schema.VariableSchema( ...
                [stateSpecs;scheduleSpecs],'1.0.0');
            obj.SourceDecision=parser.Results.SourceDecision(:);
            obj.ActiveContactNames=active(:);
            if isempty(times),obj.MaximumTimeRegularization=0;else
                obj.MaximumTimeRegularization=max(abs(times-originalTimes));
            end
        end

        function value=decisionSchema(obj,varargin)
            value=obj.DecisionSchema;
        end

        function value=templateSchedule(obj)
            value=obj.ScheduleAdapter.Chart.Template;
        end

        function value=encode(obj,state,eventTimes,returnTime)
            obj.StateCoordinates.PhysicalSchema.validateVector(state);
            if ~isnumeric(eventTimes)||numel(eventTimes)~=numel(obj.EventNames)
                error('lmz:Shooting:TransitionEncodeTimes', ...
                    'Encoded event times do not match the canonical event list.');
            end
            if nargin<4||isempty(returnTime)
                returnTime=obj.ScheduleAdapter.Chart.Template.ReturnTime;
            end
            template=obj.ScheduleAdapter.Chart.Template;
            times=eventTimes(obj.InteriorEventIndices);
            schedule=template.withTimes(times,returnTime);
            coordinates=obj.StateCoordinates.extract(state);
            value=[coordinates;obj.ScheduleAdapter.encode(schedule)];
            obj.DecisionSchema.validateVector(value);
        end

        function value=decode(obj,decision)
            obj.DecisionSchema.validateVector(decision);
            stateCount=obj.StateCoordinates.count();
            coordinates=decision(1:stateCount);
            schedule=obj.ScheduleAdapter.decode(decision(stateCount+1:end));
            state=obj.StateCoordinates.embed(obj.BaseState,coordinates);
            value=obj.decodeSegment(state,schedule);
            value.InitialCoordinates=coordinates(:);
        end

        function value=decodeSegment(obj,state,schedule)
            obj.StateCoordinates.PhysicalSchema.validateVector(state);
            if ~isa(schedule,'lmz.schedule.EventSchedule')|| ...
                    ~strcmp(schedule.StartSectionId,obj.StartSection.Id)|| ...
                    ~strcmp(schedule.StopSectionId,obj.StopSection.Id)
                error('lmz:Shooting:TransitionSegmentSchedule', ...
                    'Transition segment schedule does not match its sections.');
            end
            expected=obj.EventNames(obj.InteriorEventIndices);
            if ~isequal(schedule.names(),reshape(expected,1,[]))&& ...
                    ~isequal(schedule.names(),reshape(expected,[],1))
                error('lmz:Shooting:TransitionSegmentSchedule', ...
                    'Transition segment schedule event names changed.');
            end
            eventTimes=obj.BaseEventTimes;
            for index=1:numel(eventTimes)
                switch obj.BoundaryRoles{index}
                    case 'start'
                        eventTimes(index)=0;
                    case 'return'
                        eventTimes(index)=schedule.ReturnTime;
                end
            end
            eventTimes(obj.InteriorEventIndices)=schedule.times();
            value=struct('InitialState',state(:), ...
                'InitialCoordinates',obj.StateCoordinates.extract(state), ...
                'EventTimes',eventTimes(:),'ReturnTime',schedule.ReturnTime, ...
                'EventSchedule',schedule, ...
                'StartSectionId',obj.StartSection.Id, ...
                'StopSectionId',obj.StopSection.Id, ...
                'InteriorEventNames',{schedule.names()}, ...
                'ActiveContactNames',{obj.ActiveContactNames});
        end

        function value=toStruct(obj)
            value=toStruct@lmz.shooting.SectionDecisionCodec(obj);
            value.ModelId=obj.ModelId;
            value.StartSection=obj.StartSection.toStruct();
            value.StopSection=obj.StopSection.toStruct();
            value.StateCoordinates=obj.StateCoordinates.toStruct();
            value.StopStateCoordinates=obj.StopStateCoordinates.toStruct();
            value.Schedule=obj.ScheduleAdapter.toStruct();
            value.EventNames=obj.EventNames;
            value.InteriorEventIndices=obj.InteriorEventIndices;
            value.BoundaryRoles=obj.BoundaryRoles;
            value.BaseEventTimes=obj.BaseEventTimes;
            value.BaseState=obj.BaseState;
            value.SourceDecision=obj.SourceDecision;
            value.ActiveContactNames=obj.ActiveContactNames;
            value.MaximumTimeRegularization=obj.MaximumTimeRegularization;
        end
    end
end

function value=localEndpointEvents(startSection,stopSection,eventNames)
value={};sections={startSection,stopSection};
for index=1:numel(sections)
    primary=localPrimary(sections{index});
    if isa(primary,'lmz.poincare.NamedEventSection')
        id=primary.Descriptor.EventId;
        if any(strcmp(id,eventNames)),value{end+1,1}=id;end %#ok<AGROW>
    end
end
end

function value=localPrimary(section)
if isa(section,'lmz.poincare.CompositeSection'),value=section.Primary; ...
else,value=section;end
end

function value=isNameList(source)
if ischar(source),source={source};end
value=iscell(source)&&all(cellfun(@ischar,source));
end
