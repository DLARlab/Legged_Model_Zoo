classdef PoincareSectionDescriptor
    %POINCARESECTIONDESCRIPTOR Validated declarative section metadata.
    properties (SetAccess = private)
        Id = ''
        Label = ''
        Kind = ''
        CrossingDirection = 0
        StateSide = 'post'
        MinimumReturnTime = 0
        RequiredEventSequence = {}
        ReturnOccurrence = 1
        CoordinateNames = {}
        SymmetryClass = 'lmz.poincare.IdentitySymmetry'
        SymmetryParameters = struct()
        ImplementationClass = ''
        EventId = ''
        StateName = ''
        Threshold = 0
        ModeRestriction = ''
        Maturities = {'experimental'}
        ValidationStatus = 'untested'
        Parameters = struct()
    end

    methods
        function obj = PoincareSectionDescriptor(value)
            if nargin == 0
                return
            end
            if isa(value, 'lmz.poincare.PoincareSectionDescriptor')
                obj = value;
                return
            end
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Poincare:DescriptorType', ...
                    'A Poincare section descriptor must be a scalar struct.');
            end
            allowed = {'id','label','kind','crossingDirection','direction', ...
                'stateSide','minimumReturnTime','requiredEventSequence', ...
                'returnOccurrence','coordinateNames','symmetryClass', ...
                'symmetryParameters','implementationClass','eventId', ...
                'stateName','threshold','modeRestriction','maturities', ...
                'validationStatus','parameters'};
            names = fieldnames(value);
            if ~all(ismember(names, allowed))
                unknown = names(~ismember(names, allowed));
                error('lmz:Poincare:DescriptorField', ...
                    'Unknown Poincare descriptor field: %s', unknown{1});
            end
            required = {'id','label','kind'};
            for index = 1:numel(required)
                if ~isfield(value, required{index})
                    error('lmz:Poincare:DescriptorField', ...
                        'Poincare descriptor is missing %s.', required{index});
                end
            end

            obj.Id = localIdentifier(value.id, 'section ID', true);
            obj.Label = localNonemptyText(value.label, 'section label');
            obj.Kind = localNonemptyText(value.kind, 'section kind');
            if ~any(strcmp(obj.Kind, {'named_event','state_plane','composite'}))
                error('lmz:Poincare:SectionKind', ...
                    'Unsupported Poincare section kind: %s', obj.Kind);
            end
            direction = localField(value, 'crossingDirection', ...
                localField(value, 'direction', 0));
            if isfield(value, 'crossingDirection') && isfield(value, 'direction') && ...
                    value.crossingDirection ~= value.direction
                error('lmz:Poincare:DirectionConflict', ...
                    'direction and crossingDirection must agree.');
            end
            if ~isnumeric(direction) || ~isscalar(direction) || ...
                    ~isfinite(direction) || ~ismember(direction, [-1 0 1])
                error('lmz:Poincare:CrossingDirection', ...
                    'Crossing direction must be -1, 0, or 1.');
            end
            obj.CrossingDirection = direction;
            obj.StateSide = localField(value, 'stateSide', 'post');
            if ~ischar(obj.StateSide) || ...
                    ~any(strcmp(obj.StateSide, {'pre','post'}))
                error('lmz:Poincare:StateSide', ...
                    'Section state side must be pre or post.');
            end
            obj.MinimumReturnTime = localField(value, 'minimumReturnTime', 0);
            if ~isnumeric(obj.MinimumReturnTime) || ...
                    ~isscalar(obj.MinimumReturnTime) || ...
                    ~isfinite(obj.MinimumReturnTime) || obj.MinimumReturnTime < 0
                error('lmz:Poincare:MinimumReturnTime', ...
                    'Minimum return time must be finite and nonnegative.');
            end
            obj.RequiredEventSequence = localTextList(localField(value, ...
                'requiredEventSequence', {}), 'required event sequence', false);
            obj.ReturnOccurrence = localField(value, 'returnOccurrence', 1);
            if ~isnumeric(obj.ReturnOccurrence) || ...
                    ~isscalar(obj.ReturnOccurrence) || ...
                    ~isfinite(obj.ReturnOccurrence) || ...
                    obj.ReturnOccurrence < 1 || ...
                    obj.ReturnOccurrence ~= fix(obj.ReturnOccurrence)
                error('lmz:Poincare:ReturnOccurrence', ...
                    'Return occurrence must be a positive integer.');
            end
            obj.CoordinateNames = localTextList(localField(value, ...
                'coordinateNames', {}), 'coordinate names', true);
            if numel(unique(obj.CoordinateNames)) ~= numel(obj.CoordinateNames)
                error('lmz:Poincare:CoordinateNames', ...
                    'Section coordinate names must be unique.');
            end
            obj.SymmetryClass = localClassName(localField(value, ...
                'symmetryClass', 'lmz.poincare.IdentitySymmetry'), ...
                'symmetry class', false);
            obj.SymmetryParameters = localScalarStruct(localField(value, ...
                'symmetryParameters', struct()), 'symmetry parameters');
            obj.ImplementationClass = localClassName(localField(value, ...
                'implementationClass', ''), 'implementation class', true);
            obj.EventId = localIdentifier(localField(value, 'eventId', ''), ...
                'event ID', false, true);
            obj.StateName = localIdentifier(localField(value, 'stateName', ''), ...
                'state name', false, true);
            obj.Threshold = localField(value, 'threshold', 0);
            if ~isnumeric(obj.Threshold) || ~isscalar(obj.Threshold) || ...
                    ~isreal(obj.Threshold) || ~isfinite(obj.Threshold)
                error('lmz:Poincare:Threshold', ...
                    'State-plane threshold must be a finite real scalar.');
            end
            obj.ModeRestriction = localIdentifier(localField(value, ...
                'modeRestriction', ''), 'mode restriction', false, true);
            obj.Maturities = localTextList(localField(value, 'maturities', ...
                {'experimental'}), 'maturities', false);
            knownMaturities = {'tutorial','compatibility','validated','experimental'};
            if isempty(obj.Maturities) || ...
                    ~all(ismember(obj.Maturities, knownMaturities)) || ...
                    numel(unique(obj.Maturities)) ~= numel(obj.Maturities)
                error('lmz:Poincare:Maturities', ...
                    'Section maturities must be unique known maturity names.');
            end
            obj.ValidationStatus = localField(value, 'validationStatus', 'untested');
            if ~ischar(obj.ValidationStatus) || ~any(strcmp( ...
                    obj.ValidationStatus, {'untested','tested','source-equivalent'}))
                error('lmz:Poincare:ValidationStatus', ...
                    'Section validation status is invalid.');
            end
            obj.Parameters = localScalarStruct(localField(value, ...
                'parameters', struct()), 'section parameters');

            if strcmp(obj.Kind, 'named_event') && isempty(obj.EventId)
                error('lmz:Poincare:NamedEventId', ...
                    'A named-event section requires eventId.');
            end
            if strcmp(obj.Kind, 'state_plane') && isempty(obj.StateName) && ...
                    isempty(obj.ImplementationClass)
                error('lmz:Poincare:StatePlaneName', ...
                    'A declarative state-plane section requires stateName.');
            end
            if strcmp(obj.Kind, 'composite') && isempty(obj.ImplementationClass) && ...
                    ~isfield(obj.Parameters, 'primarySectionId')
                error('lmz:Poincare:CompositePrimary', ...
                    ['A declarative composite section requires ' ...
                    'parameters.primarySectionId.']);
            end
        end

        function validate(obj)
            lmz.poincare.PoincareSectionDescriptor(obj.toStruct());
        end

        function value = toStruct(obj)
            value = struct('id', obj.Id, 'label', obj.Label, ...
                'kind', obj.Kind, ...
                'crossingDirection', obj.CrossingDirection, ...
                'stateSide', obj.StateSide, ...
                'minimumReturnTime', obj.MinimumReturnTime, ...
                'requiredEventSequence', {obj.RequiredEventSequence}, ...
                'returnOccurrence', obj.ReturnOccurrence, ...
                'coordinateNames', {obj.CoordinateNames}, ...
                'symmetryClass', obj.SymmetryClass, ...
                'symmetryParameters', obj.SymmetryParameters, ...
                'implementationClass', obj.ImplementationClass, ...
                'eventId', obj.EventId, 'stateName', obj.StateName, ...
                'threshold', obj.Threshold, ...
                'modeRestriction', obj.ModeRestriction, ...
                'maturities', {obj.Maturities}, ...
                'validationStatus', obj.ValidationStatus, ...
                'parameters', obj.Parameters);
        end

        function value = fingerprint(obj)
            text = lmz.compat.Json.encode(obj.toStruct());
            digest = java.security.MessageDigest.getInstance('SHA-256');
            digest.update(unicode2native(text, 'UTF-8'));
            bytes = typecast(digest.digest(), 'uint8');
            value = lower(reshape(dec2hex(bytes, 2).', 1, []));
        end
    end

    methods (Static)
        function obj = fromStruct(value)
            obj = lmz.poincare.PoincareSectionDescriptor(value);
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

function value = localNonemptyText(value, description)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || isempty(strtrim(value))
    error('lmz:Poincare:DescriptorText', ...
        '%s must be nonempty text.', description);
end
end

function value = localIdentifier(value, description, lowercase, allowEmpty)
if nargin < 4
    allowEmpty = false;
end
if isstring(value) && isscalar(value)
    value = char(value);
end
if allowEmpty && ischar(value) && isempty(value)
    return
end
if lowercase
    expression = '^[a-z][a-z0-9_]*$';
else
    expression = '^[A-Za-z][A-Za-z0-9_]*$';
end
if ~ischar(value) || isempty(regexp(value, expression, 'once'))
    error('lmz:Poincare:DescriptorIdentifier', ...
        '%s is not a valid identifier.', description);
end
end

function value = localClassName(value, description, allowEmpty)
if isstring(value) && isscalar(value)
    value = char(value);
end
if allowEmpty && ischar(value) && isempty(value)
    return
end
if ~ischar(value) || isempty(regexp(value, ...
        '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$', 'once'))
    error('lmz:Poincare:DescriptorClass', ...
        '%s is not a valid qualified class name.', description);
end
end

function values = localTextList(value, description, identifiers)
if isempty(value)
    values = {};
elseif ischar(value)
    values = {value};
elseif isstring(value)
    values = cellstr(value(:));
elseif iscell(value) && all(cellfun(@ischar, value))
    values = reshape(value, 1, []);
else
    error('lmz:Poincare:DescriptorList', ...
        '%s must be a text list.', description);
end
if identifiers
    for index = 1:numel(values)
        localIdentifier(values{index}, description, false);
    end
else
    for index = 1:numel(values)
        if isempty(values{index})
            error('lmz:Poincare:DescriptorList', ...
                '%s cannot contain empty text.', description);
        end
    end
end
end

function value = localScalarStruct(value, description)
if ~isstruct(value) || ~isscalar(value)
    error('lmz:Poincare:DescriptorStruct', ...
        '%s must be a scalar struct.', description);
end
end
