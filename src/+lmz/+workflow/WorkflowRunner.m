classdef WorkflowRunner
    %WORKFLOWRUNNER Initialize registered scientific workflow sessions.
    methods
        function session=initialize(~,descriptor,context)
            if nargin<3||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            session=lmz.workflow.WorkflowSession(descriptor,context);
        end
    end
end
