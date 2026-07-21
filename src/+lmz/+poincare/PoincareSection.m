classdef (Abstract) PoincareSection < handle
    %POINCARESECTION Stable trusted-code contract for a return section.
    properties (SetAccess = private)
        Descriptor
    end
    properties (Dependent)
        Id
        Label
        Kind
        CrossingDirection
        StateSide
        MinimumReturnTime
        RequiredEventSequence
        ReturnOccurrence
    end

    methods
        function obj = PoincareSection(descriptor)
            if ~isa(descriptor, 'lmz.poincare.PoincareSectionDescriptor')
                descriptor = lmz.poincare.PoincareSectionDescriptor(descriptor);
            end
            obj.Descriptor = descriptor;
        end

        function value = get.Id(obj), value = obj.Descriptor.Id; end
        function value = get.Label(obj), value = obj.Descriptor.Label; end
        function value = get.Kind(obj), value = obj.Descriptor.Kind; end
        function value = get.CrossingDirection(obj)
            value = obj.Descriptor.CrossingDirection;
        end
        function value = get.StateSide(obj), value = obj.Descriptor.StateSide; end
        function value = get.MinimumReturnTime(obj)
            value = obj.Descriptor.MinimumReturnTime;
        end
        function value = get.RequiredEventSequence(obj)
            value = obj.Descriptor.RequiredEventSequence;
        end
        function value = get.ReturnOccurrence(obj)
            value = obj.Descriptor.ReturnOccurrence;
        end

        function validate(obj)
            obj.Descriptor.validate();
        end

        function value = toStruct(obj)
            value = obj.Descriptor.toStruct();
        end

        function value = coordinates(obj, state, stateSchema)
            if ~isa(stateSchema, 'lmz.schema.VariableSchema')
                error('lmz:Poincare:StateSchema', ...
                    'Section coordinates require a VariableSchema.');
            end
            stateSchema.validateVector(state);
            names = obj.Descriptor.CoordinateNames;
            if isempty(names)
                value = state(:);
                return
            end
            value = zeros(numel(names), 1);
            for index = 1:numel(names)
                value(index) = state(stateSchema.indexOf(names{index}));
            end
        end

        function value = gradient(~, varargin)
            value = [];
        end

        function value = directionalDerivative(obj, time, state, ...
                parameters, modeId, flow)
            derivative = obj.gradient(time, state, parameters, modeId);
            if isempty(derivative) || nargin < 6 || isempty(flow)
                value = NaN;
                return
            end
            derivative = derivative(:);
            flow = flow(:);
            if numel(derivative) ~= numel(flow) || any(~isfinite(flow))
                error('lmz:Poincare:DirectionalDerivative', ...
                    'Section gradient and flow dimensions must agree.');
            end
            value = derivative.' * flow;
        end

        function [accepted, reason] = acceptCrossing(obj, crossing, eventHistory)
            if nargin < 3
                eventHistory = {};
            end
            if ~isa(crossing, 'lmz.poincare.SectionCrossing') || ...
                    ~strcmp(crossing.SectionId, obj.Id)
                error('lmz:Poincare:CrossingType', ...
                    'Section crossing does not belong to this section.');
            end
            accepted = false;
            if crossing.Time + localTimeTolerance(crossing.Time) < ...
                    obj.MinimumReturnTime
                reason = 'minimum-return-time';
                return
            end
            if crossing.Grazing
                reason = 'grazing';
                return
            end
            if obj.CrossingDirection ~= 0 && ...
                    crossing.CrossingDirection ~= obj.CrossingDirection
                reason = 'crossing-direction';
                return
            end
            if crossing.Occurrence ~= obj.ReturnOccurrence
                reason = 'return-occurrence';
                return
            end
            observed = localEventIds(eventHistory);
            if ~localOrderedSubsequence(obj.RequiredEventSequence, observed)
                reason = 'required-event-sequence';
                return
            end
            accepted = true;
            reason = '';
        end

        function [transverse, grazing] = transversality(~, derivative, tolerance)
            if nargin < 3 || isempty(tolerance)
                tolerance = 1e-9;
            end
            if ~isnumeric(derivative) || ~isscalar(derivative) || ...
                    ~isreal(derivative) || ...
                    ~(isfinite(derivative) || isnan(derivative)) || ...
                    ~isnumeric(tolerance) || ~isscalar(tolerance) || ...
                    ~isfinite(tolerance) || tolerance <= 0
                error('lmz:Poincare:Transversality', ...
                    'Derivative/tolerance values are invalid.');
            end
            if isnan(derivative)
                transverse = false;
                grazing = false;
            else
                grazing = abs(derivative) <= tolerance;
                transverse = ~grazing;
            end
        end
    end

    methods (Abstract)
        value = value(obj, time, state, parameters, modeId)
    end
end

function value = localTimeTolerance(time)
value = 64 * eps(max(1, abs(time)));
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
            error('lmz:Poincare:EventHistory', ...
                'Event history records require Id or Name.');
        end
    end
else
    error('lmz:Poincare:EventHistory', ...
        'Event history must be text or event records.');
end
end

function valid = localOrderedSubsequence(required, observed)
valid = true;
cursor = 1;
for index = 1:numel(required)
    match = find(strcmp(required{index}, observed(cursor:end)), 1);
    if isempty(match)
        valid = false;
        return
    end
    cursor = cursor + match;
end
end
