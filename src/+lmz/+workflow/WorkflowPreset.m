classdef WorkflowPreset
    %WORKFLOWPRESET Named inert option bundle used by registered workflows.
    properties (SetAccess = private)
        Id
        Label
        Values
    end
    methods
        function obj = WorkflowPreset(value, defaultId)
            if nargin < 2, defaultId = 'default'; end
            if nargin < 1 || isempty(value), value = struct(); end
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Workflow:Preset','Workflow preset must be an object.');
            end
            obj.Id = fieldOr(value,'id',defaultId);
            obj.Label = fieldOr(value,'label',obj.Id);
            obj.Values = fieldOr(value,'values',value);
            if ~ischar(obj.Id) || isempty(regexp(obj.Id, ...
                    '^[a-z][a-z0-9_]*$','once')) || ~ischar(obj.Label) || ...
                    ~isstruct(obj.Values) || ~isscalar(obj.Values)
                error('lmz:Workflow:Preset','Workflow preset is invalid.');
            end
        end
        function value=toStruct(obj)
            value=struct('id',obj.Id,'label',obj.Label,'values',obj.Values);
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
