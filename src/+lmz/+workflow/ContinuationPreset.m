classdef ContinuationPreset
    %CONTINUATIONPRESET Declarative continuation defaults and direction labels.
    properties (SetAccess = private)
        DirectionMode
        DirectionLabels
        CheckpointEnabled
        Options
    end
    methods
        function obj = ContinuationPreset(value)
            if nargin < 1 || isempty(value), value = struct(); end
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Workflow:ContinuationPreset', ...
                    'continuationPreset must be one object.');
            end
            obj.DirectionMode = fieldOr(value, 'directionMode', 'forward');
            obj.DirectionLabels = fieldOr(value, 'directionLabels', ...
                struct('backward','backward','forward','forward'));
            obj.CheckpointEnabled = logicalScalar(fieldOr(value, ...
                'checkpointEnabled', false), 'checkpointEnabled');
            obj.Options = fieldOr(value, 'options', struct());
            if ~any(strcmp(obj.DirectionMode,{'forward','backward','both'}))
                error('lmz:Workflow:ContinuationDirection', ...
                    'Direction mode must be forward, backward, or both.');
            end
            if ~isstruct(obj.DirectionLabels) || ...
                    ~isscalar(obj.DirectionLabels) || ...
                    ~isstruct(obj.Options) || ~isscalar(obj.Options)
                error('lmz:Workflow:ContinuationPreset', ...
                    'Continuation labels/options must be scalar objects.');
            end
        end

        function value = mergedOptions(obj, overrides)
            if nargin < 2 || isempty(overrides), overrides = struct(); end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error('lmz:Workflow:ContinuationOptions', ...
                    'Continuation overrides must be one object.');
            end
            value = obj.Options;
            names = fieldnames(overrides);
            for index = 1:numel(names)
                value.(names{index}) = overrides.(names{index});
            end
            mode = fieldOr(value, 'DirectionMode', obj.DirectionMode);
            if isfield(value, 'DirectionMode'), value = rmfield(value,'DirectionMode'); end
            if ~any(strcmp(mode,{'forward','backward','both'}))
                error('lmz:Workflow:ContinuationDirection', ...
                    'Direction mode must be forward, backward, or both.');
            end
            value.BothDirections = strcmp(mode,'both');
            value.DirectionMode = mode;
        end

        function value = toStruct(obj)
            value = struct('directionMode',obj.DirectionMode, ...
                'directionLabels',obj.DirectionLabels, ...
                'checkpointEnabled',obj.CheckpointEnabled, ...
                'options',obj.Options);
        end
    end
end

function value = logicalScalar(value,name)
if ~islogical(value) || ~isscalar(value)
    error('lmz:Workflow:ContinuationPreset','%s must be logical.',name);
end
end
function value = fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
