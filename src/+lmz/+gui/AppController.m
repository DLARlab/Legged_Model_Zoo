classdef AppController < handle
    %APPCONTROLLER Headless application workflow coordinator.
    properties (SetAccess=private)
        Registry
        State
        Context
    end
    methods
        function obj = AppController(registry, context)
            if nargin < 1, registry = lmz.registry.ModelRegistry.discover(); end
            if nargin < 2, context = lmz.api.RunContext.synchronous(0); end
            obj.Registry = registry;
            obj.Context = context;
            obj.State = lmz.gui.AppState();
            ids = obj.Registry.listModels();
            obj.selectModel(ids{1});
        end

        function ids = modelIds(obj)
            ids = obj.Registry.listModels();
        end

        function selectModel(obj, modelId)
            model = obj.Registry.createModel(modelId);
            manifest = model.getManifest();
            problems = model.listProblems();
            obj.State.ModelId = manifest.id;
            obj.State.ProblemId = problems{1};
            obj.State.Simulation = [];
            obj.State.Status = ['Selected ' manifest.id];
        end

        function ids = problemIds(obj)
            model = obj.Registry.createModel(obj.State.ModelId);
            ids = model.listProblems();
        end

        function examples = builtInExamples(obj)
            service = lmz.services.DataService();
            examples = service.listBuiltInExamples(obj.State.ModelId);
        end

        function result = simulate(obj, options)
            dataService = lmz.services.DataService();
            example = dataService.loadBuiltInExample( ...
                obj.State.ModelId, obj.State.ExampleId);
            if nargin < 2 || isempty(fieldnames(options))
                options = example.options;
            end
            model = obj.Registry.createModel(obj.State.ModelId);
            problem = model.createProblem(obj.State.ProblemId, struct());
            service = lmz.services.SimulationService();
            result = service.simulate(problem, struct(), options, obj.Context);
            obj.State.Simulation = result;
            obj.State.Status = 'Simulation complete';
        end

        function capabilities = capabilities(obj)
            model = obj.Registry.createModel(obj.State.ModelId);
            capabilities = model.getCapabilities();
        end

        function names = bodyTrajectoryNames(obj)
            if isempty(obj.State.Simulation)
                names = {};
                return
            end
            available = obj.State.Simulation.StateSchema.names();
            candidates = {{'x','y'}, {'quad_x','quad_y'}};
            names = {};
            for index = 1:numel(candidates)
                pair = candidates{index};
                if all(ismember(pair, available))
                    names = pair;
                    return
                end
            end
        end
    end
end
