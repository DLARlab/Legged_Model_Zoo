classdef CyclicSectionDecisionCodec < lmz.shooting.SectionDecisionCodec
    %CYCLICSECTIONDECISIONCODEC Section state plus an ordered cyclic schedule.
    %   A named start/stop event is represented by the return endpoint rather
    %   than duplicated as an interior event. State-plane returns retain every
    %   scheduled contact event and expose the return time independently.
    properties (SetAccess=private)
        ModelId
        StartSection
        StopSection
        StateCoordinates
        ScheduleAdapter
        EventNames
        EndpointEventIndex
        BaseState
        DecisionSchema
        SourceDecision
        CoincidentEventsRegularized = false
        MaximumTimeRegularization = 0
    end

    methods
        function obj=CyclicSectionDecisionCodec(modelId,physicalSchema, ...
                startSection,stopSection,eventNames,localEventTimes, ...
                returnTime,seedState,varargin)
            parser=inputParser;
            addParameter(parser,'SourceDecision',[],@isnumeric);
            parse(parser,varargin{:});
            if ~ischar(modelId)||~isa(startSection, ...
                    'lmz.poincare.PoincareSection')||~isa(stopSection, ...
                    'lmz.poincare.PoincareSection')
                error('lmz:Shooting:CyclicCodecInput', ...
                    'Cyclic section codec inputs are invalid.');
            end
            if ischar(eventNames),eventNames={eventNames};end
            eventNames=eventNames(:);localEventTimes=localEventTimes(:);
            if ~iscell(eventNames)||~all(cellfun(@ischar,eventNames))|| ...
                    numel(eventNames)~=numel(localEventTimes)|| ...
                    any(~isfinite(localEventTimes))||~isnumeric(returnTime)|| ...
                    ~isscalar(returnTime)||~isfinite(returnTime)||returnTime<=0
                error('lmz:Shooting:CyclicScheduleSeed', ...
                    'Cyclic schedule seed data are invalid.');
            end
            physicalSchema.validateVector(seedState);
            startPrimary=localPrimary(startSection);
            stopPrimary=localPrimary(stopSection);
            endpoint=0;
            if isa(startPrimary,'lmz.poincare.NamedEventSection')
                if ~isa(stopPrimary,'lmz.poincare.NamedEventSection')|| ...
                        ~strcmp(startPrimary.Descriptor.EventId, ...
                        stopPrimary.Descriptor.EventId)
                    error('lmz:Shooting:TransitionCodecRequired', ...
                        ['Named-event periodic decisions require the same ' ...
                        'start/stop event. Use a transition segment for ' ...
                        'mixed endpoints.']);
                end
                endpoint=find(strcmp(startPrimary.Descriptor.EventId, ...
                    eventNames),1);
                if isempty(endpoint)
                    error('lmz:Shooting:EndpointEventMissing', ...
                        'The section endpoint event is absent from the schedule.');
                end
            elseif ~isa(startPrimary,'lmz.poincare.StateFunctionSection')|| ...
                    ~isa(stopPrimary,'lmz.poincare.StateFunctionSection')|| ...
                    ~strcmp(startSection.Id,stopSection.Id)
                error('lmz:Shooting:TransitionCodecRequired', ...
                    ['State-plane periodic decisions require the same start ' ...
                    'and stop section. Use a transition segment otherwise.']);
            end

            localEventTimes=mod(localEventTimes,returnTime);
            tolerance=128*eps(max(1,returnTime));
            localEventTimes(abs(localEventTimes)<=tolerance)=0;
            interior=setdiff((1:numel(eventNames)).',endpoint,'stable');
            times=localEventTimes(interior);
            names=eventNames(interior);
            [times,order]=sort(times,'ascend');names=names(order);
            sourceIndices=interior(order);
            originalTimes=times;
            separation=256*eps(max(1,returnTime));
            for index=1:numel(times)
                lower=separation;
                if index>1,lower=times(index-1)+separation;end
                if times(index)<lower
                    times(index)=lower;
                elseif times(index)>=returnTime
                    times(index)=returnTime- ...
                        max(realmin,(numel(times)-index+1)*separation);
                end
            end
            if any(diff([0;times;returnTime])<=0)
                error('lmz:Shooting:CyclicScheduleOrder', ...
                    ['The selected section lies on a simultaneous-event ' ...
                    'boundary that has no strictly ordered local chart.']);
            end
            occurrences=lmz.schedule.EventOccurrence.empty(0,1);
            for index=1:numel(times)
                occurrences(index,1)=lmz.schedule.EventOccurrence( ...
                    names{index},times(index),'Metadata',struct( ...
                    'CanonicalEventIndex',sourceIndices(index)));
            end
            schedule=lmz.schedule.EventSchedule(occurrences,returnTime, ...
                'MinimumGap',0,'StartSectionId',startSection.Id, ...
                'StopSectionId',stopSection.Id);
            scheduleAdapter=lmz.shooting.SectionScheduleAdapter(schedule);
            stateCoordinates=lmz.shooting.SectionStateSchema( ...
                physicalSchema,startSection.Descriptor.CoordinateNames);
            stateDefaults=stateCoordinates.extract(seedState);
            stateSpecs=stateCoordinates.coordinateSchema().Specs;
            for index=1:numel(stateSpecs)
                value=stateSpecs(index).toStruct();
                value.DefaultValue=stateDefaults(index);
                value.Group='section_initial_state';
                stateSpecs(index)=lmz.schema.VariableSpec.fromStruct(value);
            end
            scheduleSpecs=scheduleAdapter.Chart.DecisionSchema.Specs;
            obj.ModelId=modelId;
            obj.StartSection=startSection;
            obj.StopSection=stopSection;
            obj.StateCoordinates=stateCoordinates;
            obj.ScheduleAdapter=scheduleAdapter;
            obj.EventNames=eventNames;
            obj.EndpointEventIndex=endpoint;
            obj.BaseState=seedState(:);
            obj.DecisionSchema=lmz.schema.VariableSchema( ...
                [stateSpecs;scheduleSpecs],'1.0.0');
            obj.SourceDecision=parser.Results.SourceDecision(:);
            obj.CoincidentEventsRegularized=any(times~=originalTimes);
            if isempty(times)
                obj.MaximumTimeRegularization=0;
            else
                obj.MaximumTimeRegularization=max(abs(times-originalTimes));
            end
        end

        function value=decisionSchema(obj,varargin)
            value=obj.DecisionSchema;
        end

        function value=encode(obj,state,eventTimes,returnTime)
            obj.StateCoordinates.PhysicalSchema.validateVector(state);
            if ~isnumeric(eventTimes)||numel(eventTimes)~=numel(obj.EventNames)
                error('lmz:Shooting:CyclicEncodeTimes', ...
                    'Encoded event times do not match the canonical event list.');
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
            eventTimes=zeros(numel(obj.EventNames),1);
            names=schedule.names();times=schedule.times();
            for index=1:numel(names)
                target=find(strcmp(names{index},obj.EventNames),1);
                eventTimes(target)=times(index);
            end
            if obj.EndpointEventIndex>0
                eventTimes(obj.EndpointEventIndex)=schedule.ReturnTime;
            end
            value=struct('InitialState',state,'InitialCoordinates', ...
                coordinates(:),'EventTimes',eventTimes, ...
                'ReturnTime',schedule.ReturnTime,'EventSchedule',schedule, ...
                'StartSectionId',obj.StartSection.Id, ...
                'StopSectionId',obj.StopSection.Id, ...
                'EndpointEventIndex',obj.EndpointEventIndex);
        end

        function value=toStruct(obj)
            value=toStruct@lmz.shooting.SectionDecisionCodec(obj);
            value.ModelId=obj.ModelId;
            value.StartSection=obj.StartSection.toStruct();
            value.StopSection=obj.StopSection.toStruct();
            value.StateCoordinates=obj.StateCoordinates.toStruct();
            value.Schedule=obj.ScheduleAdapter.toStruct();
            value.EventNames=obj.EventNames;
            value.EndpointEventIndex=obj.EndpointEventIndex;
            value.SourceDecision=obj.SourceDecision;
            value.CoincidentEventsRegularized= ...
                obj.CoincidentEventsRegularized;
            value.MaximumTimeRegularization=obj.MaximumTimeRegularization;
        end
    end
end

function value=localPrimary(section)
if isa(section,'lmz.poincare.CompositeSection')
    value=section.Primary;
else
    value=section;
end
end
