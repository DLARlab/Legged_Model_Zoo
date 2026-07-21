classdef NamedEventSection < lmz.poincare.PoincareSection
    %NAMEDEVENTSECTION Section backed by an existing named hybrid event.
    methods
        function obj = NamedEventSection(descriptor)
            obj@lmz.poincare.PoincareSection(descriptor);
            if ~strcmp(obj.Kind, 'named_event')
                error('lmz:Poincare:NamedEventKind', ...
                    'NamedEventSection requires kind named_event.');
            end
        end

        function result = value(~, ~, ~, ~, ~)
            result = 0;
        end

        function valid = matches(obj, record)
            valid = false;
            if ~isstruct(record) || ~isscalar(record)
                return
            end
            eventId = localField(record, 'Id', localField(record, 'Name', ''));
            valid = ischar(eventId) && strcmp(eventId, obj.Descriptor.EventId);
        end

        function crossing = crossingFromRecord(obj, record, varargin)
            parser = inputParser;
            addParameter(parser, 'Occurrence', 1, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x >= 1 && x == fix(x));
            addParameter(parser, 'EventHistory', {});
            addParameter(parser, 'Tolerance', 1e-9, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x > 0);
            parse(parser, varargin{:});
            options = parser.Results;
            if ~obj.matches(record)
                error('lmz:Poincare:NamedEventMismatch', ...
                    'Event record does not match section %s.', obj.Id);
            end
            time = localRequiredNumeric(record, 'Time');
            fallbackState = localField(record, 'State', zeros(0, 1));
            preState = localField(record, 'PreState', fallbackState);
            postState = localField(record, 'PostState', fallbackState);
            if ~localState(preState) || ~localState(postState)
                error('lmz:Poincare:NamedEventState', ...
                    'Named event pre/post states must be finite vectors.');
            end
            derivative = localDerivative(record);
            if isfinite(derivative)
                direction = localDirection(derivative, options.Tolerance);
                grazing = abs(derivative) <= options.Tolerance;
            else
                direction = localField(record, 'Direction', ...
                    obj.CrossingDirection);
                if ~isnumeric(direction) || ~isscalar(direction) || ...
                        ~ismember(direction, [-1 0 1])
                    direction = obj.CrossingDirection;
                end
                grazing = false;
            end
            metadata = localField(record, 'Metadata', struct());
            if ~isstruct(metadata) || ~isscalar(metadata)
                metadata = struct();
            end
            if isnan(derivative)
                metadata.TransversalityStatus = 'unavailable';
            elseif grazing
                metadata.TransversalityStatus = 'grazing';
            else
                metadata.TransversalityStatus = 'transverse';
            end
            metadata.EventHistory = options.EventHistory;
            sectionValue = localField(record, 'SectionValue', 0);
            if ~isnumeric(sectionValue) || ~isscalar(sectionValue) || ...
                    ~isfinite(sectionValue)
                sectionValue = 0;
            end
            eventId = localField(record, 'Id', localField(record, 'Name', ''));
            crossing = lmz.poincare.SectionCrossing(obj.Id, time, ...
                'EventId', eventId, ...
                'ModeBefore', localField(record, 'FromMode', ''), ...
                'ModeAfter', localField(record, 'ToMode', ''), ...
                'PreState', preState, 'PostState', postState, ...
                'StateSide', obj.StateSide, 'Value', sectionValue, ...
                'DirectionalDerivative', derivative, ...
                'CrossingDirection', direction, 'Grazing', grazing, ...
                'Occurrence', options.Occurrence, 'Metadata', metadata);
            [accepted, reason] = obj.acceptCrossing( ...
                crossing, options.EventHistory);
            crossing = crossing.withAcceptance(accepted, reason);
        end
    end
end

function value = localField(source, name, fallback)
if isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end

function value = localRequiredNumeric(record, name)
if ~isfield(record, name) || ~isnumeric(record.(name)) || ...
        ~isscalar(record.(name)) || ~isfinite(record.(name))
    error('lmz:Poincare:NamedEventField', ...
        'Named event record requires finite scalar %s.', name);
end
value = record.(name);
end

function valid = localState(value)
valid = isnumeric(value) && isreal(value) && isvector(value) && ...
    all(isfinite(value(:)));
end

function value = localDerivative(record)
value = localField(record, 'DirectionalDerivative', NaN);
if isnan(value) && isfield(record, 'Metadata') && ...
        isstruct(record.Metadata) && isscalar(record.Metadata)
    value = localField(record.Metadata, 'DirectionalDerivative', ...
        localField(record.Metadata, 'directionalDerivative', NaN));
end
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~(isfinite(value) || isnan(value))
    value = NaN;
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
