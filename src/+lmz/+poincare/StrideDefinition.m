classdef StrideDefinition
    %STRIDEDEFINITION Explicit start/stop section semantics for one stride.
    properties (SetAccess = private)
        StartSectionId = ''
        StartStateSide = 'post'
        StopSectionId = ''
        StopStateSide = 'post'
        CrossingDirection = 0
        MinimumReturnTime = 0
        RequiredEventSequence = {}
        ReturnOccurrence = 1
        SymmetryId = 'identity'
        StartSectionHash = ''
        StopSectionHash = ''
    end

    methods
        function obj = StrideDefinition(value)
            if nargin == 0
                return
            end
            if isa(value, 'lmz.poincare.StrideDefinition')
                obj = value;
                return
            end
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Poincare:StrideType', ...
                    'Stride definition must be a scalar struct.');
            end
            required = {'StartSectionId','StopSectionId'};
            for index = 1:numel(required)
                if ~isfield(value, required{index})
                    error('lmz:Poincare:StrideField', ...
                        'Stride definition is missing %s.', required{index});
                end
            end
            allowed = {'StartSectionId','StartStateSide','StopSectionId', ...
                'StopStateSide','CrossingDirection','MinimumReturnTime', ...
                'RequiredEventSequence','ReturnOccurrence','SymmetryId', ...
                'StartSectionHash','StopSectionHash'};
            names = fieldnames(value);
            if ~all(ismember(names, allowed))
                unknown = names(~ismember(names, allowed));
                error('lmz:Poincare:StrideField', ...
                    'Unknown stride-definition field: %s', unknown{1});
            end
            obj.StartSectionId = localId(value.StartSectionId, 'start section');
            obj.StopSectionId = localId(value.StopSectionId, 'stop section');
            obj.StartStateSide = localSide(localField(value, ...
                'StartStateSide', 'post'));
            obj.StopStateSide = localSide(localField(value, ...
                'StopStateSide', 'post'));
            obj.CrossingDirection = localField(value, 'CrossingDirection', 0);
            if ~isnumeric(obj.CrossingDirection) || ...
                    ~isscalar(obj.CrossingDirection) || ...
                    ~ismember(obj.CrossingDirection, [-1 0 1])
                error('lmz:Poincare:StrideDirection', ...
                    'Stride crossing direction must be -1, 0, or 1.');
            end
            obj.MinimumReturnTime = localField(value, 'MinimumReturnTime', 0);
            if ~isnumeric(obj.MinimumReturnTime) || ...
                    ~isscalar(obj.MinimumReturnTime) || ...
                    ~isfinite(obj.MinimumReturnTime) || obj.MinimumReturnTime < 0
                error('lmz:Poincare:StrideMinimumTime', ...
                    'Stride minimum return time must be nonnegative.');
            end
            obj.RequiredEventSequence = localTextList(localField(value, ...
                'RequiredEventSequence', {}));
            obj.ReturnOccurrence = localField(value, 'ReturnOccurrence', 1);
            if ~isnumeric(obj.ReturnOccurrence) || ...
                    ~isscalar(obj.ReturnOccurrence) || ...
                    ~isfinite(obj.ReturnOccurrence) || obj.ReturnOccurrence < 1 || ...
                    obj.ReturnOccurrence ~= fix(obj.ReturnOccurrence)
                error('lmz:Poincare:StrideOccurrence', ...
                    'Stride return occurrence must be a positive integer.');
            end
            obj.SymmetryId = localId(localField(value, ...
                'SymmetryId', 'identity'), 'symmetry');
            obj.StartSectionHash = localHash(localField(value, ...
                'StartSectionHash', ''));
            obj.StopSectionHash = localHash(localField(value, ...
                'StopSectionHash', ''));
        end

        function validate(obj)
            lmz.poincare.StrideDefinition(obj.toStruct());
        end

        function value = toStruct(obj)
            value = struct('StartSectionId', obj.StartSectionId, ...
                'StartStateSide', obj.StartStateSide, ...
                'StopSectionId', obj.StopSectionId, ...
                'StopStateSide', obj.StopStateSide, ...
                'CrossingDirection', obj.CrossingDirection, ...
                'MinimumReturnTime', obj.MinimumReturnTime, ...
                'RequiredEventSequence', {obj.RequiredEventSequence}, ...
                'ReturnOccurrence', obj.ReturnOccurrence, ...
                'SymmetryId', obj.SymmetryId, ...
                'StartSectionHash', obj.StartSectionHash, ...
                'StopSectionHash', obj.StopSectionHash);
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
        function obj = fromSections(startSection, stopSection, symmetryId)
            if ~isa(startSection, 'lmz.poincare.PoincareSection') || ...
                    ~isa(stopSection, 'lmz.poincare.PoincareSection')
                error('lmz:Poincare:StrideSections', ...
                    'Stride endpoints must be PoincareSection objects.');
            end
            if nargin < 3 || isempty(symmetryId)
                symmetryId = 'identity';
            end
            value = struct('StartSectionId', startSection.Id, ...
                'StartStateSide', startSection.StateSide, ...
                'StopSectionId', stopSection.Id, ...
                'StopStateSide', stopSection.StateSide, ...
                'CrossingDirection', stopSection.CrossingDirection, ...
                'MinimumReturnTime', stopSection.MinimumReturnTime, ...
                'RequiredEventSequence', ...
                {stopSection.RequiredEventSequence}, ...
                'ReturnOccurrence', stopSection.ReturnOccurrence, ...
                'SymmetryId', symmetryId, ...
                'StartSectionHash', startSection.Descriptor.fingerprint(), ...
                'StopSectionHash', stopSection.Descriptor.fingerprint());
            obj = lmz.poincare.StrideDefinition(value);
        end
    end
end

function value = localField(source, name, fallback)
if isfield(source, name), value = source.(name); else, value = fallback; end
end

function value = localId(value, description)
if ~ischar(value) || isempty(regexp(value, '^[a-z][a-z0-9_]*$', 'once'))
    error('lmz:Poincare:StrideId', '%s ID is invalid.', description);
end
end

function value = localSide(value)
if ~ischar(value) || ~any(strcmp(value, {'pre','post'}))
    error('lmz:Poincare:StrideSide', 'Stride state side must be pre or post.');
end
end

function value = localTextList(value)
if isempty(value)
    value = {};
elseif ischar(value)
    value = {value};
elseif isstring(value)
    value = cellstr(value(:)).';
elseif iscell(value) && all(cellfun(@ischar, value))
    value = reshape(value, 1, []);
else
    error('lmz:Poincare:StrideSequence', ...
        'Required event sequence must be a text list.');
end
end

function value = localHash(value)
if ~ischar(value) || ...
        (~isempty(value) && isempty(regexp(value, '^[0-9a-fA-F]{64}$', 'once')))
    error('lmz:Poincare:StrideHash', ...
        'Section hashes must be empty or SHA-256 hex values.');
end
value = lower(value);
end
