classdef EventSchedule
    %EVENTSCHEDULE Ordered named event occurrences and return time.
    properties (SetAccess=private)
        Occurrences
        ReturnTime
        ReturnTimeFixed
        MinimumGap
        StartSectionId
        StopSectionId
        Metadata
    end

    methods
        function obj=EventSchedule(occurrences,returnTime,varargin)
            if nargin<1
                occurrences=lmz.schedule.EventOccurrence.empty(0,1);
            end
            if nargin<2
                returnTime=1;
            end
            parser=inputParser;
            addRequired(parser,'occurrences');
            addRequired(parser,'returnTime',@(x)isnumeric(x)&&isreal(x)&& ...
                isscalar(x)&&isfinite(x)&&x>0);
            addParameter(parser,'ReturnTimeFixed',false,@(x)islogical(x)&&isscalar(x));
            addParameter(parser,'MinimumGap',1e-12,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0);
            addParameter(parser,'StartSectionId','apex',@ischar);
            addParameter(parser,'StopSectionId','apex',@ischar);
            addParameter(parser,'Metadata',struct(),@(x)isstruct(x)&&isscalar(x));
            parse(parser,occurrences,returnTime,varargin{:});
            if ~all(arrayfun(@(x)isa(x,'lmz.schedule.EventOccurrence'),occurrences))
                error('lmz:Schedule:OccurrenceType', ...
                    'Occurrences must contain EventOccurrence values.');
            end
            obj.Occurrences=occurrences(:);
            obj.ReturnTime=parser.Results.returnTime;
            obj.ReturnTimeFixed=parser.Results.ReturnTimeFixed;
            obj.MinimumGap=parser.Results.MinimumGap;
            obj.StartSectionId=parser.Results.StartSectionId;
            obj.StopSectionId=parser.Results.StopSectionId;
            obj.Metadata=parser.Results.Metadata;
            obj.validate();
        end

        function validate(obj)
            names=obj.names();
            if numel(unique(names))~=numel(names)
                error('lmz:Schedule:DuplicateEvent', ...
                    'Event occurrence names must be unique within a stride.');
            end
            times=obj.times();
            if any(times<=obj.MinimumGap)|| ...
                    any(diff([0;times;obj.ReturnTime])<=obj.MinimumGap)
                error('lmz:Schedule:EventOrder', ...
                    ['Occurrences must already be in strict chronological ' ...
                    'order with gaps above MinimumGap.']);
            end
        end

        function value=count(obj), value=numel(obj.Occurrences); end
        function value=names(obj)
            value=arrayfun(@(x)x.Name,obj.Occurrences,'UniformOutput',false);
        end
        function value=times(obj)
            value=arrayfun(@(x)x.Time,obj.Occurrences(:));
        end
        function value=fixedMask(obj)
            value=arrayfun(@(x)x.Fixed,obj.Occurrences(:));
        end
        function value=freeMask(obj), value=~obj.fixedMask(); end

        function value=namedTimes(obj,requestedNames)
            if ischar(requestedNames), requestedNames={requestedNames}; end
            value=zeros(numel(requestedNames),1);
            own=obj.names();
            for index=1:numel(requestedNames)
                match=find(strcmp(requestedNames{index},own),1);
                if isempty(match)
                    error('lmz:Schedule:UnknownEvent', ...
                        'Schedule does not contain event %s.',requestedNames{index});
                end
                value(index)=obj.Occurrences(match).Time;
            end
        end

        function value=withTimes(obj,times,returnTime)
            if nargin<3, returnTime=obj.ReturnTime; end
            if ~isnumeric(times)||numel(times)~=obj.count()
                error('lmz:Schedule:TimeCount','Event time count is invalid.');
            end
            occurrences=obj.Occurrences;
            for index=1:numel(occurrences)
                occurrences(index)=occurrences(index).withTime(times(index));
            end
            value=lmz.schedule.EventSchedule(occurrences,returnTime, ...
                'ReturnTimeFixed',obj.ReturnTimeFixed, ...
                'MinimumGap',obj.MinimumGap, ...
                'StartSectionId',obj.StartSectionId, ...
                'StopSectionId',obj.StopSectionId,'Metadata',obj.Metadata);
        end

        function value=withFixedMask(obj,eventMask,returnFixed)
            if nargin<3, returnFixed=obj.ReturnTimeFixed; end
            if ~islogical(eventMask)||numel(eventMask)~=obj.count()
                error('lmz:Schedule:FixedMask','Fixed event mask is invalid.');
            end
            occurrences=obj.Occurrences;
            for index=1:numel(occurrences)
                occurrences(index)=occurrences(index).withFixed(eventMask(index));
            end
            value=lmz.schedule.EventSchedule(occurrences,obj.ReturnTime, ...
                'ReturnTimeFixed',returnFixed,'MinimumGap',obj.MinimumGap, ...
                'StartSectionId',obj.StartSectionId, ...
                'StopSectionId',obj.StopSectionId,'Metadata',obj.Metadata);
        end

        function value=toStruct(obj)
            occurrences=cell(obj.count(),1);
            for index=1:obj.count()
                occurrences{index}=obj.Occurrences(index).toStruct();
            end
            value=struct('SchemaVersion','1.0.0','Occurrences',{occurrences}, ...
                'ReturnTime',obj.ReturnTime,'ReturnTimeFixed',obj.ReturnTimeFixed, ...
                'MinimumGap',obj.MinimumGap,'StartSectionId',obj.StartSectionId, ...
                'StopSectionId',obj.StopSectionId,'Metadata',obj.Metadata);
        end
    end

    methods (Static)
        function obj=fromCyclic(names,times,returnTime,varargin)
            %FROMCYCLIC Explicit legacy-boundary conversion into time order.
            parser=inputParser;
            addParameter(parser,'FixedMask',false(numel(names),1));
            addParameter(parser,'ReturnTimeFixed',false);
            addParameter(parser,'MinimumGap',1e-12);
            addParameter(parser,'StartSectionId','apex');
            addParameter(parser,'StopSectionId','apex');
            parse(parser,varargin{:});
            if ischar(names), names={names}; end
            names=names(:); times=times(:); fixed=parser.Results.FixedMask(:);
            if numel(names)~=numel(times)||numel(fixed)~=numel(times)
                error('lmz:Schedule:CyclicCount', ...
                    'Cyclic names, times, and fixed mask must have equal sizes.');
            end
            original=(1:numel(times)).';
            [~,order]=sortrows([times original],[1 2]);
            orderedTimes=times(order);
            minimumGap=parser.Results.MinimumGap;
            adjusted=false;
            for index=2:numel(orderedTimes)
                if orderedTimes(index)-orderedTimes(index-1)<=minimumGap
                    orderedTimes(index)=orderedTimes(index-1)+2*minimumGap;
                    adjusted=true;
                end
            end
            if ~isempty(orderedTimes)&&returnTime-orderedTimes(end)<=minimumGap
                error('lmz:Schedule:CyclicReturnGap', ...
                    'Cyclic events cannot be imported below the return-time gap.');
            end
            occurrences=lmz.schedule.EventOccurrence.empty(0,1);
            for index=1:numel(order)
                source=order(index);
                occurrences(index,1)=lmz.schedule.EventOccurrence( ...
                    names{source},orderedTimes(index),'Fixed',logical(fixed(source)), ...
                    'Metadata',struct('CyclicSourceIndex',source));
            end
            metadata=struct('ImportKind','named-cyclic', ...
                'ImportPermutation',order(:).','OriginalNames',{names(:).'}, ...
                'OriginalTimes',times(:).','SimultaneousTimesAdjusted',adjusted);
            obj=lmz.schedule.EventSchedule(occurrences,returnTime, ...
                'ReturnTimeFixed',logical(parser.Results.ReturnTimeFixed), ...
                'MinimumGap',parser.Results.MinimumGap, ...
                'StartSectionId',parser.Results.StartSectionId, ...
                'StopSectionId',parser.Results.StopSectionId, ...
                'Metadata',metadata);
        end

        function obj=fromStruct(value)
            occurrences=lmz.schedule.EventOccurrence.empty(0,1);
            stored=value.Occurrences;
            if isstruct(stored), stored=num2cell(stored); end
            for index=1:numel(stored)
                occurrences(index,1)=lmz.schedule.EventOccurrence.fromStruct( ...
                    stored{index});
            end
            obj=lmz.schedule.EventSchedule(occurrences,value.ReturnTime, ...
                'ReturnTimeFixed',value.ReturnTimeFixed, ...
                'MinimumGap',value.MinimumGap, ...
                'StartSectionId',value.StartSectionId, ...
                'StopSectionId',value.StopSectionId,'Metadata',value.Metadata);
        end
    end
end
