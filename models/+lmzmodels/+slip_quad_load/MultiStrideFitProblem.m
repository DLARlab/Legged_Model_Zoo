classdef MultiStrideFitProblem < lmz.api.OptimizationProblem
    %MULTISTRIDEFITPROBLEM Source-equivalent X_accum gait/load objective.
    properties (SetAccess=private)
        Dataset
        DatasetPath
        SourceDecision
        Simulator
        ActiveOptimizationIndices
    end
    methods
        function obj=MultiStrideFitProblem(model,configuration)
            if nargin<2,configuration=struct();end
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            datasetPath=catalog.defaultMultiPath();if isfield(configuration,'DatasetPath'),datasetPath=configuration.DatasetPath;end
            dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(datasetPath);
            source=dataset.XAccum;active=activeIndices(dataset.StrideCount);
            if isfield(configuration,'ActiveOptimizationIndices')
                requested=configuration.ActiveOptimizationIndices(:).';
                if isempty(requested)||any(requested~=fix(requested))|| ...
                        any(~ismember(requested,active))||numel(unique(requested))~=numel(requested)
                    error('lmz:QuadLoad:ActiveOptimizationIndices', ...
                        'Active optimization indices must be a unique subset of the later-stride post-swing stiffness entries.');
                end
                active=requested;
            end
            defaults=source;factor=fieldOr(configuration,'InitialPerturbation',0.03);
            defaults(active)=source(active).*(1+factor);zero=abs(source(active))<1e-9;defaults(active(zero))=factor;
            decision=lmzmodels.slip_quad_load.MultiStrideDecisionSchema.create(dataset.StrideCount,defaults);
            parameters=lmzmodels.slip_quad_load.ObjectiveWeightSchema.create(dataset.TermWeights);
            obj@lmz.api.OptimizationProblem(model,'multi_stride_fit','optimization', ...
                decision,parameters,parameters.defaults(),configuration);
            obj.Version='2.0.0';obj.Dataset=dataset;obj.DatasetPath=datasetPath;
            obj.SourceDecision=source;obj.ActiveOptimizationIndices=active;
            obj.Simulator=lmzmodels.slip_quad_load.MultiStrideSimulator();
        end
        function [value,terms,diagnostics]=evaluateObjective(obj,u,p,context)
            context.check();obj.DecisionSchema.validateVector(u);obj.ParameterSchema.validateVector(p);
            raw=obj.Simulator.runRaw(u,context,true);
            duration=lmzmodels.slip_quad_load.ObjectiveTerms.StrideDurationMismatch.evaluate( ...
                raw.Parameters,obj.Dataset.Experimental.t_exp,p(1));
            footfall=lmzmodels.slip_quad_load.ObjectiveTerms.FootfallTimingMismatch.evaluate( ...
                raw.Parameters,obj.Dataset.Experimental.ft_exp,p(2));
            loading=lmzmodels.slip_quad_load.ObjectiveTerms.LoadingForceMismatch.evaluate( ...
                raw,obj.Dataset.Experimental.loading_force_exp,p(3));
            terms=struct('StrideDuration',duration,'FootfallTiming',footfall,'LoadingForce',loading);
            [value,composite]=lmzmodels.slip_quad_load.ObjectiveTerms.CompositeObjective.compute(terms);
            [r2,r2Diagnostics]=lmzmodels.slip_quad_load.ObjectiveTerms.R2Metrics.compute( ...
                duration,footfall,loading,p(:).');
            diagnostics=struct('LegacyEquivalent',true,'ObjectiveFormulation', ...
                'source-fms_NStridesObjectiveFcn_Quad_Load_v2','DatasetPath',obj.DatasetPath, ...
                'DatasetId',obj.Dataset.Id,'StrideCount',raw.StrideCount,'Composite',composite, ...
                'R2',r2,'R2Diagnostics',r2Diagnostics,'Residual',raw.Residual, ...
                'ResidualNorm',norm(raw.Residual),'PerStrideParameters',raw.Parameters, ...
                'SourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99');
        end
        function value=objectiveTerms(~)
            value={'stride_duration','footfall_timing','loading_force','composite','r_squared'};
        end
        function [lower,upper]=bounds(obj)
            lower=obj.SourceDecision;upper=obj.SourceDecision;
            active=obj.ActiveOptimizationIndices;radius=max(5,0.5*abs(obj.SourceDecision(active)));
            lower(active)=obj.SourceDecision(active)-radius;upper(active)=obj.SourceDecision(active)+radius;
        end
        function [c,ceq]=nonlinearConstraints(~,~,~,context)
            context.check();c=[];ceq=[];
        end
        function result=simulateDecision(obj,u,context)
            result=obj.Simulator.run(u,context,struct('EnforceEventTiming',false));
        end
        function value=sourceSeed(obj),value=obj.SourceDecision;end
        function solution=makeSolution(obj,u,p,evaluation)
            if nargin<3||isempty(p),p=obj.DefaultParameters;end
            if nargin<4,evaluation=[];end
            solution=makeSolution@lmz.api.BaseProblem(obj,u,p,evaluation);
            data=solution.toStruct();data.DecisionSchema=solution.DecisionSchema;data.ParameterSchema=solution.ParameterSchema;data.ResidualBlocks=solution.ResidualBlocks;
            data.Provenance=struct('source','scientific-load-dataset','datasetId',obj.Dataset.Id, ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99');solution=lmz.data.Solution(data);
        end
    end
end
function value=activeIndices(strideCount)
if strideCount>1
    indices=lmzmodels.slip_quad_load.LaterStrideLayout.globalIndices(strideCount);
    value=indices.PostSwingStiffness;
else
    indices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
    value=indices.PostSwingStiffness;
end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
