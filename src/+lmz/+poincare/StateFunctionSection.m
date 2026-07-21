classdef StateFunctionSection < lmz.poincare.PoincareSection
    %STATEFUNCTIONSECTION Safe named-state plane h(x)=x_i-threshold.
    properties (SetAccess = private)
        StateSchema
        StateIndex
    end

    methods
        function obj = StateFunctionSection(descriptor, stateSchema)
            obj@lmz.poincare.PoincareSection(descriptor);
            if ~strcmp(obj.Kind, 'state_plane')
                error('lmz:Poincare:StatePlaneKind', ...
                    'StateFunctionSection requires kind state_plane.');
            end
            if ~isa(stateSchema, 'lmz.schema.VariableSchema')
                error('lmz:Poincare:StateSchema', ...
                    'StateFunctionSection requires a VariableSchema.');
            end
            obj.StateSchema = stateSchema;
            obj.StateIndex = stateSchema.indexOf(obj.Descriptor.StateName);
            names = obj.Descriptor.CoordinateNames;
            for index = 1:numel(names)
                stateSchema.indexOf(names{index});
            end
        end

        function result = value(obj, ~, state, ~, modeId)
            obj.StateSchema.validateVector(state);
            if nargin >= 5 && ~isempty(obj.Descriptor.ModeRestriction) && ...
                    ~strcmp(modeId, obj.Descriptor.ModeRestriction)
                result = NaN;
                return
            end
            result = state(obj.StateIndex) - obj.Descriptor.Threshold;
        end

        function result = gradient(obj, ~, state, ~, ~)
            obj.StateSchema.validateVector(state);
            result = zeros(obj.StateSchema.count(), 1);
            result(obj.StateIndex) = 1;
        end

        function crossing = crossingAt(obj, time, state, flow, varargin)
            parser = inputParser;
            addParameter(parser, 'ModeId', '', @ischar);
            addParameter(parser, 'Occurrence', 1, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x >= 1 && x == fix(x));
            addParameter(parser, 'EventHistory', {});
            addParameter(parser, 'Tolerance', 1e-9, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x > 0);
            parse(parser, varargin{:});
            options = parser.Results;
            obj.StateSchema.validateVector(state);
            if ~isnumeric(flow) || numel(flow) ~= obj.StateSchema.count() || ...
                    any(~isfinite(flow(:)))
                error('lmz:Poincare:SectionFlow', ...
                    'State-plane flow must match the state schema.');
            end
            sectionValue = obj.value(time, state, struct(), options.ModeId);
            derivative = obj.directionalDerivative( ...
                time, state, struct(), options.ModeId, flow);
            [~, grazing] = obj.transversality(derivative, options.Tolerance);
            direction = localDirection(derivative, options.Tolerance);
            metadata = struct('TransversalityStatus', ...
                localTransversalityStatus(derivative, grazing), ...
                'ModeRestriction', obj.Descriptor.ModeRestriction, ...
                'EventHistory', {options.EventHistory});
            crossing = lmz.poincare.SectionCrossing(obj.Id, time, ...
                'ModeBefore', options.ModeId, 'ModeAfter', options.ModeId, ...
                'PreState', state, 'PostState', state, ...
                'StateSide', obj.StateSide, 'Value', sectionValue, ...
                'DirectionalDerivative', derivative, ...
                'CrossingDirection', direction, 'Grazing', grazing, ...
                'Occurrence', options.Occurrence, 'Metadata', metadata);
            if ~isempty(obj.Descriptor.ModeRestriction) && ...
                    ~strcmp(options.ModeId, obj.Descriptor.ModeRestriction)
                crossing = crossing.withAcceptance(false, 'mode-restriction');
            elseif ~isfinite(sectionValue) || abs(sectionValue) > options.Tolerance
                crossing = crossing.withAcceptance(false, 'section-value');
            else
                [accepted, reason] = obj.acceptCrossing( ...
                    crossing, options.EventHistory);
                crossing = crossing.withAcceptance(accepted, reason);
            end
        end

        function [detected, crossing] = detectCrossing(obj, firstTime, ...
                firstState, secondTime, secondState, varargin)
            parser = inputParser;
            addParameter(parser, 'ModeId', '', @ischar);
            addParameter(parser, 'Occurrence', 1, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x >= 1 && x == fix(x));
            addParameter(parser, 'EventHistory', {});
            addParameter(parser, 'Tolerance', 1e-9, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x > 0);
            parse(parser, varargin{:});
            options = parser.Results;
            obj.StateSchema.validateVector(firstState);
            obj.StateSchema.validateVector(secondState);
            if ~isnumeric(firstTime) || ~isscalar(firstTime) || ...
                    ~isfinite(firstTime) || ~isnumeric(secondTime) || ...
                    ~isscalar(secondTime) || ~isfinite(secondTime) || ...
                    secondTime <= firstTime
                error('lmz:Poincare:CrossingInterval', ...
                    'Crossing interval times must be finite and increasing.');
            end
            if ~isempty(obj.Descriptor.ModeRestriction) && ...
                    ~strcmp(options.ModeId, obj.Descriptor.ModeRestriction)
                detected = false;
                crossing = lmz.poincare.SectionCrossing.empty(0, 1);
                return
            end
            firstValue = obj.value(firstTime, firstState, struct(), options.ModeId);
            secondValue = obj.value(secondTime, secondState, struct(), options.ModeId);
            detected = localCrossed(firstValue, secondValue, ...
                obj.CrossingDirection, options.Tolerance);
            if ~detected
                crossing = lmz.poincare.SectionCrossing.empty(0, 1);
                return
            end
            denominator = firstValue - secondValue;
            if abs(denominator) <= options.Tolerance
                fraction = 0.5;
            else
                fraction = firstValue / denominator;
            end
            fraction = max(0, min(1, fraction));
            state = firstState(:) + fraction * ...
                (secondState(:) - firstState(:));
            time = firstTime + fraction * (secondTime - firstTime);
            flow = (secondState(:) - firstState(:)) / ...
                (secondTime - firstTime);
            crossing = obj.crossingAt(time, state, flow, ...
                'ModeId', options.ModeId, ...
                'Occurrence', options.Occurrence, ...
                'EventHistory', options.EventHistory, ...
                'Tolerance', options.Tolerance);
        end
    end
end

function value = localDirection(derivative, tolerance)
if derivative > tolerance
    value = 1;
elseif derivative < -tolerance
    value = -1;
else
    value = 0;
end
end

function value = localTransversalityStatus(derivative, grazing)
if isnan(derivative)
    value = 'unavailable';
elseif grazing
    value = 'grazing';
else
    value = 'transverse';
end
end

function detected = localCrossed(first, second, direction, tolerance)
switch direction
    case 1
        detected = first < -tolerance && second >= -tolerance;
    case -1
        detected = first > tolerance && second <= tolerance;
    otherwise
        detected = (first < -tolerance && second >= -tolerance) || ...
            (first > tolerance && second <= tolerance);
end
end
