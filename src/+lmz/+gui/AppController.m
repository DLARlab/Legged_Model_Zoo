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
            obj.State.Datasets={}; obj.State.Selection=[]; obj.State.WorkingSolution=[];
            obj.loadBuiltInBranch();
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
            problem = model.createProblem('demo_stride', struct());
            service = lmz.services.SimulationService();
            result = service.simulate(problem, struct(), options, obj.Context);
            obj.State.Simulation = result;
            obj.State.Status = 'Simulation complete';
        end

        function capabilities = capabilities(obj)
            model = obj.Registry.createModel(obj.State.ModelId);
            capabilities = model.getCapabilities();
        end
        function dataset=loadBuiltInBranch(obj)
            branch=lmz.services.BranchService().loadBuiltInBranch(obj.Registry,obj.State.ModelId);dataset=lmz.data.BranchDataset([obj.State.ModelId ' built-in'],branch,'ReadOnly',true);
            obj.State.Datasets={dataset};obj.State.ActiveDatasetId=dataset.Id;obj.selectBranchPoint(1);
        end
        function solution=selectBranchPoint(obj,index)
            dataset=obj.State.Datasets{1};obj.State.Selection=lmz.services.BranchService().selectPoint(dataset,index);solution=dataset.Branch.point(index);obj.State.WorkingSolution=solution;obj.State.ProblemId=solution.ProblemId;
        end
        function result=solveWorkingSolution(obj,options)
            model=obj.Registry.createModel(obj.State.ModelId);problem=model.createProblem('periodic_apex',struct());result=lmz.services.SolveService().solve(problem,obj.State.WorkingSolution,options,obj.Context);obj.State.SolveResult=result;obj.State.WorkingSolution=result.Solution;obj.State.Status='Solve complete';
        end
        function pair=makeSecondSeed(obj,radius)
            model=obj.Registry.createModel(obj.State.ModelId);problem=model.createProblem('periodic_apex',struct());pair=lmz.services.SeedService().makeSecondSeed(problem,obj.State.WorkingSolution,radius,struct(),obj.Context);obj.State.SeedPair=pair;
        end
        function result=runContinuation(obj,options)
            if isempty(obj.State.SeedPair),obj.makeSecondSeed(0.03);end
            model=obj.Registry.createModel(obj.State.ModelId);problem=model.createProblem('periodic_apex',struct());result=lmz.services.ContinuationService().run(problem,obj.State.SeedPair,options,obj.Context);obj.State.ContinuationResult=result;obj.State.Status='Continuation complete';
        end
        function result=runOptimization(obj,options)
            model=obj.Registry.createModel(obj.State.ModelId);problems=model.listProblems();if any(strcmp(problems,'trajectory_fit')),id='trajectory_fit';else,id='multi_stride_fit';end
            problem=model.createProblem(id,struct());seed=problem.makeSolution(problem.getDecisionSchema().defaults(),[],[]);result=lmz.services.OptimizationService().run(problem,seed,options,obj.Context);obj.State.OptimizationResult=result;obj.State.WorkingSolution=result.Solution;obj.State.Status='Optimization complete';
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
