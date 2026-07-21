classdef NStrideSimulationProblem < handle
    %NSTRIDESIMULATIONPROBLEM Public simulation problem for an explicit plan.
    properties (SetAccess=private)
        Model
        Id = 'n_stride_simulation'
        Configuration
        Request
    end

    methods
        function obj=NStrideSimulationProblem(model,configuration)
            if nargin<2
                configuration=struct();
            end
            if ~isa(model,'lmz.api.LeggedModel')||~isstruct(configuration)|| ...
                    ~isscalar(configuration)
                error('lmz:MultiStride:SimulationConfiguration', ...
                    'N-stride simulation requires a model and scalar configuration.');
            end
            obj.Model=model;
            obj.Configuration=configuration;
            obj.Request=makeRequest(configuration);
        end

        function value=getDescriptor(obj)
            manifest=obj.Model.getManifest();
            value=obj.Model.registeredProblemDescriptor(obj.Id);
            if isempty(value)
                value=struct('id',obj.Id,'kind','simulation', ...
                    'modelId',manifest.id);
            end
            value.modelId=manifest.id;
            value.modelVersion=manifest.version;
            value.configuration=obj.Configuration;
        end

        function value=getRequest(obj)
            value=obj.Request;
        end

        function result=simulate(obj,context)
            if nargin<2||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            result=lmz.services.MultiStrideSimulationService().simulate( ...
                obj.Model,obj.Request,context);
        end

        function result=run(obj,context)
            if nargin<2
                context=[];
            end
            result=obj.simulate(context);
        end

        function result=simulateDecision(obj,decision,context)
            if nargin<3||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            configuration=obj.Configuration;
            configuration.InitialDecision=decision(:);
            if isfield(configuration,'StridePlan')
                configuration=rmfield(configuration,'StridePlan');
            end
            request=makeRequest(configuration);
            result=lmz.services.MultiStrideSimulationService().simulate( ...
                obj.Model,request,context);
        end
    end
end

function request=makeRequest(configuration)
allowed={'NumberOfStrides','InitialDecision','StridePlan', ...
    'CompletionPolicy','EnergyPolicy','EnergyNeutralOnly','FailurePolicy', ...
    'StartSectionId','StopSectionId','ProviderCallback', ...
    'ParameterOverrides','DeclaredWork','MaximumStrides','Provenance'};
names=fieldnames(configuration);
unknown=setdiff(names,allowed);
if ~isempty(unknown)
    error('lmz:MultiStride:SimulationConfigurationField', ...
        'Unknown N-stride simulation configuration field: %s.',unknown{1});
end
if isfield(configuration,'StridePlan')&& ...
        ~isfield(configuration,'NumberOfStrides')&& ...
        isa(configuration.StridePlan,'lmz.multistride.StridePlan')
    configuration.NumberOfStrides= ...
        configuration.StridePlan.RequestedStrideCount;
end
pairs=cell(1,2*numel(names));
names=fieldnames(configuration);
for index=1:numel(names)
    pairs{2*index-1}=names{index};
    pairs{2*index}=configuration.(names{index});
end
request=lmz.multistride.MultiStrideRequest(pairs{:});
end
