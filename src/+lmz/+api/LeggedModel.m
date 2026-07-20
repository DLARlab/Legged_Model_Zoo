classdef (Abstract) LeggedModel < handle
    %LEGGEDMODEL Stable model extension contract for registry implementations.
    properties (Access = private)
        RegistryContext = []
    end
    methods
        function bindRegistryContext(obj, context)
            % Internal registration hook; executable plugins are trusted code.
            if ~isa(context, 'lmz.registry.RegistryEntryContext')
                error('lmz:API:RegistryContext', ...
                    'Registry context has an invalid type.');
            end
            obj.RegistryContext = context;
        end

        function tf = hasRegistryContext(obj)
            tf = ~isempty(obj.RegistryContext);
        end

        function value = registeredManifest(obj)
            if isempty(obj.RegistryContext)
                value = [];
            else
                value = obj.RegistryContext.Manifest;
            end
        end

        function value = registeredProblemDescriptor(obj, problemId)
            if isempty(obj.RegistryContext)
                value = [];
            else
                value = obj.RegistryContext.problemDescriptor(problemId);
            end
        end

        function value = getVisualizationPlugin(~)
            % Provisional generic scene/plot extension point.
            value = [];
        end
    end
    methods (Abstract)
        value=getManifest(obj); value=getCapabilities(obj); value=getPhysicalStateSchema(obj)
        value=getParameterSchema(obj); value=listProblems(obj); value=createProblem(obj,id,configuration)
        value=simulate(obj,request,context); value=kinematics(obj,frame); value=getPlotDescriptors(obj)
    end
end
