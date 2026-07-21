classdef TimingGauge
    %TIMINGGAUGE Safe declarative scalar condition on a decoded schedule.
    properties (SetAccess=private)
        Id
        Kind
        EventName
        Target
        Coefficients
        Scale
    end

    methods
        function obj=TimingGauge(value)
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Timing:GaugeType', ...
                    'TimingGauge requires a scalar plain struct.');
            end
            allowed={'SchemaVersion','Id','Kind','EventName', ...
                'Target','Coefficients','Scale'};
            names=fieldnames(value);
            if any(~ismember(names,allowed))
                error('lmz:Timing:GaugeField', ...
                    'TimingGauge contains an unknown field.');
            end
            obj.Id=requiredText(value,'Id');
            if isempty(regexp(obj.Id,'^[A-Za-z][A-Za-z0-9_]*$','once'))
                error('lmz:Timing:GaugeId','TimingGauge Id is invalid.');
            end
            obj.Kind=requiredText(value,'Kind');
            kinds={'fixed_event','fixed_return_time','linear_phase'};
            if ~any(strcmp(obj.Kind,kinds))
                error('lmz:Timing:GaugeKind', ...
                    'TimingGauge Kind must be one of: %s.',strjoin(kinds,', '));
            end
            obj.EventName=fieldOr(value,'EventName','');
            obj.Target=fieldOr(value,'Target',0);
            obj.Coefficients=fieldOr(value,'Coefficients',zeros(0,1));
            obj.Scale=fieldOr(value,'Scale',1);
            if ~ischar(obj.EventName)||~isnumeric(obj.Target)|| ...
                    ~isreal(obj.Target)||~isscalar(obj.Target)|| ...
                    ~isfinite(obj.Target)||~isnumeric(obj.Coefficients)|| ...
                    ~isreal(obj.Coefficients)||~isvector(obj.Coefficients)|| ...
                    any(~isfinite(obj.Coefficients(:)))|| ...
                    ~isnumeric(obj.Scale)||~isscalar(obj.Scale)|| ...
                    ~isfinite(obj.Scale)||obj.Scale<=0
                error('lmz:Timing:GaugeValue', ...
                    'TimingGauge values are invalid.');
            end
            obj.Coefficients=obj.Coefficients(:);
            if strcmp(obj.Kind,'fixed_event')&&isempty(obj.EventName)
                error('lmz:Timing:GaugeEvent', ...
                    'A fixed_event gauge requires EventName.');
            end
            if ~strcmp(obj.Kind,'fixed_event')&&~isempty(obj.EventName)
                error('lmz:Timing:GaugeEvent', ...
                    'EventName is allowed only for fixed_event gauges.');
            end
            if ~strcmp(obj.Kind,'linear_phase')&&~isempty(obj.Coefficients)
                error('lmz:Timing:GaugeCoefficients', ...
                    'Coefficients are allowed only for linear_phase gauges.');
            end
        end

        function value=evaluate(obj,schedule)
            if ~isa(schedule,'lmz.schedule.EventSchedule')
                error('lmz:Timing:GaugeSchedule', ...
                    'TimingGauge requires an EventSchedule.');
            end
            switch obj.Kind
                case 'fixed_event'
                    value=schedule.namedTimes({obj.EventName})-obj.Target;
                case 'fixed_return_time'
                    value=schedule.ReturnTime-obj.Target;
                case 'linear_phase'
                    physical=[schedule.times();schedule.ReturnTime];
                    if numel(obj.Coefficients)~=numel(physical)
                        error('lmz:Timing:GaugeDimension', ...
                            ['linear_phase coefficients must match all event ' ...
                            'times plus return time.']);
                    end
                    value=obj.Coefficients.'*physical-obj.Target;
            end
        end

        function value=toStruct(obj)
            value=struct('SchemaVersion','1.0.0','Id',obj.Id, ...
                'Kind',obj.Kind,'EventName',obj.EventName, ...
                'Target',obj.Target,'Coefficients',obj.Coefficients, ...
                'Scale',obj.Scale);
        end
    end

    methods (Static)
        function obj=fixedEvent(eventName,target,varargin)
            scale=1;if nargin>=3,scale=varargin{1};end
            id=['fix_' matlab.lang.makeValidName(eventName)];
            obj=lmz.schedule.TimingGauge(struct('Id',id, ...
                'Kind','fixed_event','EventName',eventName, ...
                'Target',target,'Scale',scale));
        end

        function obj=fixedReturnTime(target,varargin)
            scale=1;if nargin>=2,scale=varargin{1};end
            obj=lmz.schedule.TimingGauge(struct('Id','fix_return_time', ...
                'Kind','fixed_return_time','Target',target,'Scale',scale));
        end

        function obj=linearPhase(id,coefficients,target,varargin)
            scale=1;if nargin>=4,scale=varargin{1};end
            obj=lmz.schedule.TimingGauge(struct('Id',id, ...
                'Kind','linear_phase','Coefficients',coefficients, ...
                'Target',target,'Scale',scale));
        end

        function values=arrayFrom(source)
            if isempty(source)
                values=lmz.schedule.TimingGauge.empty(0,1);return
            end
            if isa(source,'lmz.schedule.TimingGauge')
                values=source(:);return
            end
            if isstruct(source),source=num2cell(source(:));end
            if ~iscell(source)
                error('lmz:Timing:GaugeCollection', ...
                    'Timing gauges must be objects, structs, or a cell array.');
            end
            values=lmz.schedule.TimingGauge.empty(0,1);
            for index=1:numel(source)
                item=source{index};
                if ~isa(item,'lmz.schedule.TimingGauge')
                    item=lmz.schedule.TimingGauge(item);
                end
                values(index,1)=item;
            end
            ids=arrayfun(@(item)item.Id,values,'UniformOutput',false);
            if numel(unique(ids))~=numel(ids)
                error('lmz:Timing:DuplicateGauge', ...
                    'Timing gauge IDs must be unique.');
            end
        end
    end
end

function value=requiredText(source,name)
if ~isfield(source,name)||~ischar(source.(name))||isempty(source.(name))
    error('lmz:Timing:GaugeField','TimingGauge requires text field %s.',name);
end
value=source.(name);
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
