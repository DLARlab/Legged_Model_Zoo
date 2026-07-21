classdef SingleStrideProblem < lmz.api.BaseProblem
    %SINGLESTRIDEPROBLEM Scientific 44-entry load-pulling stride problem.
    properties (SetAccess=private)
        Dataset
        DatasetPath
        SourceDecision
        SourceEquivalent
        InputTruncationDiagnostics
        Simulator
    end
    methods
        function obj=SingleStrideProblem(model,configuration)
            if nargin<2,configuration=struct();end
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            path=catalog.defaultSinglePath();if isfield(configuration,'DatasetPath'),path=configuration.DatasetPath;end
            dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(path);
            if dataset.StrideCount~=1,error('lmz:QuadLoad:SingleDataset','SingleStrideProblem requires one stride.');end
            source=dataset.XAccum(:);
            if isfield(configuration,'InitialDecision')&& ...
                    ~isempty(configuration.InitialDecision)
                source=lmzmodels.slip_quad_load.XAccumAdapter.encode( ...
                    configuration.InitialDecision);
                if lmzmodels.slip_quad_load.XAccumAdapter.strideCount(source)~=1
                    error('lmz:QuadLoad:SingleDecision', ...
                        'SingleStrideProblem requires one 44-entry stride decision.');
                end
            end
            decision=lmzmodels.slip_quad_load.MultiStrideDecisionSchema.create(1,source);
            parameters=lmzmodels.slip_quad_load.ObjectiveWeightSchema.create(dataset.TermWeights);
            obj@lmz.api.BaseProblem(model,'single_stride','simulation',decision,parameters,parameters.defaults(),configuration);
            obj.Version='2.0.0';obj.Dataset=dataset;obj.DatasetPath=path;
            obj.SourceDecision=source;
            obj.SourceEquivalent=isequaln(source,dataset.XAccum(:));
            obj.InputTruncationDiagnostics=fieldOr(configuration, ...
                'InputTruncationDiagnostics',noTruncationDiagnostics(1,numel(source)));
            obj.Simulator=lmzmodels.slip_quad_load.MultiStrideSimulator();
        end
        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            if nargin<5,includeSimulation=false;end
            context.check();obj.DecisionSchema.validateVector(u);obj.ParameterSchema.validateVector(p);
            raw=obj.Simulator.runRaw(u,context,false);blocks=[ ...
                lmz.data.ResidualBlock('contact_geometry',raw.Residual(1:8),ones(8,1)); ...
                lmz.data.ResidualBlock('apex_section',raw.Residual(9),1); ...
                lmz.data.ResidualBlock('tugline_periodicity',raw.Residual(10),1); ...
                lmz.data.ResidualBlock('load_periodicity',raw.Residual(11:14),ones(4,1)); ...
                lmz.data.ResidualBlock('quadruped_periodicity',raw.Residual(15:27),ones(13,1))];
            simulation=[];if includeSimulation,simulation=obj.Simulator.run(u,context,struct('EnforceEventTiming',false));end
            feasibility=struct('Valid',all(isfinite(raw.Residual))&&all(raw.States(:,3)>0), ...
                'ResidualNorm',norm(raw.Residual));
            diagnostics=struct('LegacyEquivalent',obj.SourceEquivalent, ...
                'SourceEquivalent',obj.SourceEquivalent, ...
                'HiddenEventTimeSolve',false, ...
                'StrideCount',1,'DatasetId',obj.Dataset.Id,'SourceCommit', ...
                '19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'InputTruncated',logical(obj.InputTruncationDiagnostics. ...
                ExplicitTruncation), ...
                'InputTruncation',obj.InputTruncationDiagnostics, ...
                'InputTruncationDiagnostics',obj.InputTruncationDiagnostics);
            evaluation=lmz.data.ProblemEvaluation(blocks,'Simulation',simulation, ...
                'Feasibility',feasibility,'PhysicalValidity',feasibility.Valid,'Diagnostics',diagnostics);
        end
        function result=simulateDecision(obj,u,context),result=obj.Simulator.run(u,context,struct('EnforceEventTiming',false));end
        function names=listObservables(~)
            names={'stride_count','stride_durations','event_phases','tugline_force', ...
                'grf_magnitude','horizontal_grf','vertical_grf','load_position'};
        end
        function solution=makeSolution(obj,u,p,evaluation)
            if nargin<3||isempty(p),p=obj.DefaultParameters;end
            if nargin<4,evaluation=[];end
            solution=makeSolution@lmz.api.BaseProblem(obj,u,p,evaluation);
            data=solution.toStruct();data.DecisionSchema=solution.DecisionSchema;data.ParameterSchema=solution.ParameterSchema;data.ResidualBlocks=solution.ResidualBlocks;
            if ~isempty(evaluation)&&~isempty(evaluation.Simulation),data.Observables=evaluation.Simulation.Observables;end
            data.Provenance=struct('source','scientific-load-dataset','datasetId',obj.Dataset.Id, ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'configuredSourceEquivalent',obj.SourceEquivalent, ...
                'inputTruncation',obj.InputTruncationDiagnostics);solution=lmz.data.Solution(data);
        end
    end
end

function value=noTruncationDiagnostics(count,lengthValue)
value=struct('Source','none','OriginalStrideCount',count, ...
    'RetainedStrideCount',count,'OriginalLength',lengthValue, ...
    'RetainedLength',lengthValue,'ExplicitTruncation',false);
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
