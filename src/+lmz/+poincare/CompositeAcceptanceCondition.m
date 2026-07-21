classdef CompositeAcceptanceCondition
    %COMPOSITEACCEPTANCECONDITION Safe declarative non-crossing condition.
    properties (SetAccess = private)
        Kind = ''
        StateName = ''
        Comparator = ''
        Threshold = 0
        StateSide = 'selected'
        ModeId = ''
        EventId = ''
        StateSchema = []
    end

    methods
        function obj = CompositeAcceptanceCondition(value, stateSchema)
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Poincare:CompositeConditionSpec', ...
                    'A composite acceptance condition must be a scalar object.');
            end
            allowed = {'kind','stateName','comparator','threshold', ...
                'stateSide','modeId','eventId'};
            names = fieldnames(value);
            if ~all(ismember(names, allowed)) || ~isfield(value, 'kind') || ...
                    ~ischar(value.kind)
                error('lmz:Poincare:CompositeConditionSpec', ...
                    'Composite condition fields are invalid.');
            end
            obj.Kind = value.kind;
            obj.StateSchema = stateSchema;
            switch obj.Kind
                case 'state_comparison'
                    obj.StateName = localText(value, 'stateName');
                    obj.Comparator = localText(value, 'comparator');
                    if ~any(strcmp(obj.Comparator, {'gt','ge','lt','le'}))
                        error('lmz:Poincare:CompositeComparator', ...
                            'State comparator must be gt, ge, lt, or le.');
                    end
                    obj.Threshold = localFinite(value, 'threshold');
                    obj.StateSide = localOptionalText( ...
                        value, 'stateSide', 'selected');
                    if ~any(strcmp(obj.StateSide, ...
                            {'selected','pre','post'}))
                        error('lmz:Poincare:CompositeStateSide', ...
                            'Condition state side must be selected, pre, or post.');
                    end
                    if ~isa(stateSchema, 'lmz.schema.VariableSchema')
                        error('lmz:Poincare:StateSchema', ...
                            'State conditions require a VariableSchema.');
                    end
                    stateSchema.indexOf(obj.StateName);
                case 'mode_equals'
                    obj.ModeId = localText(value, 'modeId');
                    obj.StateSide = localOptionalText( ...
                        value, 'stateSide', 'selected');
                    if ~any(strcmp(obj.StateSide, ...
                            {'selected','pre','post'}))
                        error('lmz:Poincare:CompositeStateSide', ...
                            'Condition mode side must be selected, pre, or post.');
                    end
                case 'event_seen'
                    obj.EventId = localText(value, 'eventId');
                otherwise
                    error('lmz:Poincare:CompositeConditionKind', ...
                        'Unsupported composite condition kind: %s', obj.Kind);
            end
        end

        function [accepted, reason] = acceptCrossing(obj, crossing, history)
            if ~isa(crossing, 'lmz.poincare.SectionCrossing')
                error('lmz:Poincare:CompositeConditionCrossing', ...
                    'Composite conditions require a SectionCrossing.');
            end
            switch obj.Kind
                case 'state_comparison'
                    state = localState(crossing, obj.StateSide);
                    index = obj.StateSchema.indexOf(obj.StateName);
                    accepted = localCompare( ...
                        state(index), obj.Comparator, obj.Threshold);
                    reason = 'composite-state-comparison';
                case 'mode_equals'
                    modeId = localMode(crossing, obj.StateSide);
                    accepted = strcmp(modeId, obj.ModeId);
                    reason = 'composite-mode';
                otherwise
                    accepted = any(strcmp(obj.EventId, localEventIds(history)));
                    reason = 'composite-event-history';
            end
            if accepted
                reason = '';
            end
        end

        function value = toStruct(obj)
            value = struct('kind', obj.Kind);
            switch obj.Kind
                case 'state_comparison'
                    value.stateName = obj.StateName;
                    value.comparator = obj.Comparator;
                    value.threshold = obj.Threshold;
                    value.stateSide = obj.StateSide;
                case 'mode_equals'
                    value.modeId = obj.ModeId;
                    value.stateSide = obj.StateSide;
                otherwise
                    value.eventId = obj.EventId;
            end
        end
    end
end

function value = localText(source, name)
if ~isfield(source, name) || ~ischar(source.(name)) || ...
        isempty(strtrim(source.(name)))
    error('lmz:Poincare:CompositeConditionField', ...
        'Composite condition requires nonempty %s.', name);
end
value = source.(name);
end

function value = localOptionalText(source, name, fallback)
if isfield(source, name)
    value = localText(source, name);
else
    value = fallback;
end
end

function value = localFinite(source, name)
if ~isfield(source, name) || ~isnumeric(source.(name)) || ...
        ~isscalar(source.(name)) || ~isfinite(source.(name))
    error('lmz:Poincare:CompositeConditionField', ...
        'Composite condition requires finite scalar %s.', name);
end
value = source.(name);
end

function state = localState(crossing, side)
switch side
    case 'pre'
        state = crossing.PreState;
    case 'post'
        state = crossing.PostState;
    otherwise
        state = crossing.State;
end
end

function modeId = localMode(crossing, side)
switch side
    case 'pre'
        modeId = crossing.ModeBefore;
    case 'post'
        modeId = crossing.ModeAfter;
    otherwise
        if strcmp(crossing.StateSide, 'pre')
            modeId = crossing.ModeBefore;
        else
            modeId = crossing.ModeAfter;
        end
end
end

function accepted = localCompare(value, comparator, threshold)
switch comparator
    case 'gt'
        accepted = value > threshold;
    case 'ge'
        accepted = value >= threshold;
    case 'lt'
        accepted = value < threshold;
    otherwise
        accepted = value <= threshold;
end
end

function ids = localEventIds(history)
if isempty(history)
    ids = {};
elseif ischar(history)
    ids = {history};
elseif iscell(history) && all(cellfun(@ischar, history))
    ids = reshape(history, 1, []);
elseif isstruct(history)
    ids = cell(1, numel(history));
    for index = 1:numel(history)
        if isfield(history(index), 'Id')
            ids{index} = history(index).Id;
        elseif isfield(history(index), 'Name')
            ids{index} = history(index).Name;
        else
            error('lmz:Poincare:CompositeEventHistory', ...
                'Event history records require Id or Name.');
        end
    end
else
    error('lmz:Poincare:CompositeEventHistory', ...
        'Event history must be text or event records.');
end
end
