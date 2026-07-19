classdef (Abstract) LeggedModel < handle
    methods (Abstract)
        metadata=metadata(obj); capabilities=capabilities(obj); schema=stateSchema(obj); schema=parameterSchema(obj)
        result=simulate(obj,request); frames=kinematics(obj,state,parameters,context); problem=createProblem(obj,problemId,options)
    end
    methods
        function report=validateRequest(obj,request)
            report=lmz.core.ValidationReport(); if ~isstruct(request),report=report.addError('Simulation request must be a struct.');return;end
            if isfield(request,'parameters'), r=obj.parameterSchema().validateVector(request.parameters); if ~r.IsValid,report=report.addError(strjoin(r.Errors,'; '));end,end
        end
        function renderer=createRenderer(obj,axesHandle,visualSpec)
            renderer=lmz.viz.SceneGraphRenderer2D(); if nargin>1&&~isempty(axesHandle),renderer.initialize(axesHandle,obj,visualSpec,struct());end
        end
    end
end
