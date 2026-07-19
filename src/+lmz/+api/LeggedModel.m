classdef (Abstract) LeggedModel < handle
    methods (Abstract)
        value=getManifest(obj); value=getCapabilities(obj); value=getPhysicalStateSchema(obj)
        value=getParameterSchema(obj); value=listProblems(obj); value=createProblem(obj,id,configuration)
        value=simulate(obj,request,context); value=kinematics(obj,frame); value=getPlotDescriptors(obj)
    end
end
