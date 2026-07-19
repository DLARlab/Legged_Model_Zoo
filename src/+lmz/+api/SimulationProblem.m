classdef SimulationProblem < handle
    %SIMULATIONPROBLEM Lightweight model-owned simulation task.
    properties (SetAccess=private)
        Model
        Id
        Configuration
    end
    methods
        function obj = SimulationProblem(model, id, configuration)
            obj.Model = model;
            obj.Id = id;
            obj.Configuration = configuration;
        end
        function value = getDescriptor(obj)
            manifest = obj.Model.getManifest();
            value = struct('id', obj.Id, 'kind', 'simulation', ...
                'modelId', manifest.id, 'configuration', obj.Configuration);
        end
    end
end
