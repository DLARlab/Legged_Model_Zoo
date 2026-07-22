classdef WorkflowStep
    %WORKFLOWSTEP Declarative workflow step and runtime status record.
    properties (SetAccess=private)
        Id
        Label
        Status
        Diagnostics
    end
    methods
        function obj=WorkflowStep(id,label,status,diagnostics)
            if nargin<2||isempty(label),label=id;end
            if nargin<3||isempty(status),status='pending';end
            if nargin<4,diagnostics=struct();end
            if ~ischar(id)||isempty(regexp(id,'^[a-z][a-z0-9_]*$','once'))|| ...
                    ~ischar(label)||~any(strcmp(status, ...
                    {'pending','running','completed','failed','stopped'}))|| ...
                    ~isstruct(diagnostics)
                error('lmz:Workflow:Step','Workflow step is invalid.');
            end
            obj.Id=id;obj.Label=label;obj.Status=status; ...
                obj.Diagnostics=diagnostics;
        end
        function value=withStatus(obj,status,diagnostics)
            if nargin<3,diagnostics=obj.Diagnostics;end
            value=lmz.workflow.WorkflowStep(obj.Id,obj.Label,status,diagnostics);
        end
        function value=toStruct(obj)
            value=struct('id',obj.Id,'label',obj.Label, ...
                'status',obj.Status,'diagnostics',obj.Diagnostics);
        end
    end
end
