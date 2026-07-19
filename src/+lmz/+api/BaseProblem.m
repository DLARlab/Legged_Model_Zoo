classdef BaseProblem < handle
    %BASEPROBLEM Common schema/chart behavior for numerical problems.
    properties (SetAccess=protected)
        Model
        Id
        Version = '1.0.0'
        Kind
        DecisionSchema
        ParameterSchema
        DefaultParameters
        Configuration
    end
    methods
        function obj = BaseProblem(model, id, kind, decisionSchema, ...
                parameterSchema, defaultParameters, configuration)
            obj.Model = model; obj.Id = id; obj.Kind = kind;
            obj.DecisionSchema = decisionSchema;
            obj.ParameterSchema = parameterSchema;
            obj.DefaultParameters = defaultParameters(:);
            obj.Configuration = configuration;
        end
        function value = getDescriptor(obj)
            manifest=obj.Model.getManifest();
            registry=lmz.registry.ModelRegistry.discover();
            value=registry.getProblemDescriptor(manifest.id,obj.Id);
            value.version=obj.Version;
            value.modelId=manifest.id;
            value.modelVersion=manifest.version;
            value.configuration=obj.Configuration;
        end
        function value=getDecisionSchema(obj), value=obj.DecisionSchema; end
        function value=getParameterSchema(obj), value=obj.ParameterSchema; end
        function value=canonicalize(obj,u), value=lmz.schema.VariableChart(obj.DecisionSchema).canonicalize(u); end
        function value=difference(obj,a,b), value=lmz.schema.VariableChart(obj.DecisionSchema).difference(a,b); end
        function value=retract(obj,u,d), value=lmz.schema.VariableChart(obj.DecisionSchema).retract(u,d); end
        function value=scale(obj,varargin) %#ok<INUSD>
            value=arrayfun(@(s)s.Scale,obj.DecisionSchema.Specs(:));
        end
        function value=decodeDecision(obj,u), value=obj.DecisionSchema.unpack(u); end
        function request=toSimulationRequest(obj,u,p,options)
            if nargin<4, options=struct(); end
            descriptor=obj.getDescriptor();
            options.decision=obj.decodeDecision(u);
            options.parameters=obj.ParameterSchema.unpack(p);
            request=lmz.api.SimulationRequest(descriptor.modelId,obj.Id,struct(),options);
        end
        function report=validateDecision(obj,u)
            try, obj.DecisionSchema.validateVector(u); report=struct('Valid',true,'Message','');
            catch exception, report=struct('Valid',false,'Message',exception.message); end
        end
        function report=validateSolution(obj,solution)
            report=obj.validateDecision(solution.DecisionValues);
        end
        function value=listObservables(~), value={}; end
        function value=evaluateObservables(~,varargin), value=struct(); end %#ok<INUSD>
        function solution=makeSolution(obj,u,p,evaluation)
            if nargin<3||isempty(p), p=obj.DefaultParameters; end
            if nargin<4||isempty(evaluation)
                residualBlocks=lmz.data.ResidualBlock.empty(0,1); diagnostics=struct(); feasibility=struct('Valid',true);
            else
                residualBlocks=evaluation.ResidualBlocks; diagnostics=evaluation.Diagnostics; feasibility=evaluation.Feasibility;
            end
            descriptor=obj.getDescriptor();
            value=struct('Id',lmz.util.Ids.new('solution'),'ModelId',descriptor.modelId, ...
                'ModelVersion',descriptor.modelVersion,'ProblemId',obj.Id, ...
                'ProblemVersion',obj.Version,'DecisionSchema',obj.DecisionSchema, ...
                'ParameterSchema',obj.ParameterSchema,'DecisionValues',u(:), ...
                'ParameterValues',p(:),'Observables',struct(), ...
                'ResidualBlocks',residualBlocks,'Diagnostics',diagnostics, ...
                'Classification',struct(),'Feasibility',feasibility, ...
                'Lineage',struct(),'Provenance',struct('source','native'), ...
                'CreatedAt',datestr(now,30));
            solution=lmz.data.Solution(value);
        end
    end
end
