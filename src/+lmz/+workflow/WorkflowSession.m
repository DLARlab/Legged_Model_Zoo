classdef WorkflowSession < handle
    %WORKFLOWSESSION Runtime state for one registered scientific workflow.
    properties (SetAccess=private)
        Descriptor
        Context
        Model
        Problem
        DataSourceProvider
        Dataset
        SourceBranch
        SeedIndex
        SourceSeed
        WorkingSolution
        InitialEvaluation
        SolveResult=[]
        SeedPair=[]
        ContinuationResult=[]
        HomotopyResult=[]
        FamilyScanResult=[]
        Steps
    end
    methods
        function obj=WorkflowSession(descriptor,context)
            if ~isa(descriptor,'lmz.workflow.WorkflowDescriptor')
                error('lmz:Workflow:SessionDescriptor', ...
                    'WorkflowSession requires a WorkflowDescriptor.');
            end
            if ~isa(context,'lmz.api.RunContext')
                error('lmz:Workflow:SessionContext', ...
                    'WorkflowSession requires a RunContext.');
            end
            if isempty(descriptor.Registry)|| ...
                    ~isa(descriptor.Registry,'lmz.registry.ModelRegistry')
                error('lmz:Workflow:SessionBinding', ...
                    'Workflow descriptor is not registry-bound.');
            end
            obj.Descriptor=descriptor;obj.Context=context;
            obj.Model=descriptor.Registry.createModel(descriptor.ModelId);
            obj.Problem=obj.Model.createProblem(descriptor.ProblemId, ...
                descriptor.ProblemConfiguration);
            obj.DataSourceProvider=descriptor.createDataSourceProvider();
            obj.Dataset=obj.DataSourceProvider.load(descriptor.DataSource, ...
                descriptor.DefaultDatasetId,descriptor.Registry);
            if ~isa(obj.Dataset,'lmz.data.BranchDataset')
                error('lmz:Workflow:ProviderDataset', ...
                    'Registered provider must return a BranchDataset.');
            end
            obj.SourceBranch=obj.Dataset.Branch;
            if ~strcmp(obj.SourceBranch.ModelId,descriptor.ModelId)
                error('lmz:Workflow:DatasetProblem', ...
                    'Registered dataset does not match the workflow model.');
            end
            if ~strcmp(obj.SourceBranch.ProblemId, ...
                    descriptor.DataSource.ProblemId)
                error('lmz:Workflow:DatasetProblem', ...
                    'Registered dataset does not match its data-source problem.');
            end
            obj.SeedIndex=descriptor.DefaultPointIndex;
            if obj.SeedIndex>obj.SourceBranch.pointCount()
                error('lmz:Workflow:DefaultPoint', ...
                    'Workflow default point is outside its source branch.');
            end
            obj.SourceSeed=obj.SourceBranch.point(obj.SeedIndex);
            transferred=[];
            if strcmp(obj.SourceBranch.ProblemId,descriptor.ProblemId)
                obj.WorkingSolution=obj.SourceSeed;
            else
                obj.assertAllowed({'section_transfer'});
                transferred=obj.transferToWorkflowSection(obj.SourceSeed);
                obj.Problem=obj.Model.createProblem(descriptor.ProblemId, ...
                    transferred.Lineage.Configuration);
                obj.WorkingSolution=transferred.Solution;
            end
            obj.InitialEvaluation=obj.Problem.evaluate( ...
                obj.WorkingSolution.DecisionValues, ...
                obj.WorkingSolution.ParameterValues, ...
                context,false);
            obj.Steps=lmz.workflow.WorkflowStep.empty(0,1);
            obj.recordStep('initialize','Initialize','completed',struct( ...
                'DatasetId',obj.Dataset.Name,'PointIndex',obj.SeedIndex, ...
                'ResidualNorm',obj.InitialEvaluation.ScaledResidualNorm, ...
                'SourceHash',fieldOr(obj.Dataset.Metadata,'SourceHash','')));
            if ~isempty(transferred)
                obj.recordStep('section_transfer','Section transfer', ...
                    'completed',struct('SourceProblemId', ...
                    obj.SourceBranch.ProblemId,'TargetProblemId', ...
                    descriptor.ProblemId,'TargetSectionId', ...
                    transferred.Lineage.TargetSectionId, ...
                    'PhysicalOrbitMaxError', ...
                    transferred.PhysicalOrbitMaxError));
            end
        end

        function result=solve(obj,overrides)
            if nargin<2,overrides=struct();end
            obj.assertAllowed({'solve','root_solve'});
            options=mergeStruct(obj.Descriptor.SolveOptions,overrides);
            obj.recordStep('solve','Root solve','running',struct());
            try
                result=lmz.services.SolveService().solve(obj.Problem, ...
                    obj.WorkingSolution,options,obj.Context);
                obj.SolveResult=result;obj.WorkingSolution=result.Solution;
                obj.recordStep('solve','Root solve','completed',struct( ...
                    'ExitFlag',result.ExitFlag,'ResidualNorm', ...
                    result.Evaluation.ScaledResidualNorm));
            catch exception
                obj.recordStep('solve','Root solve','failed',struct( ...
                    'Identifier',exception.identifier,'Message',exception.message));
                rethrow(exception)
            end
        end

        function pair=makeAdjacentSeedPair(obj,direction,options)
            if nargin<3,options=struct();end
            obj.assertAllowed({'seed_pair','seeds','continuation'});
            if strcmp(obj.SourceBranch.ProblemId,obj.Problem.Id)
                pair=lmz.services.SeedService().adjacentBranchPair( ...
                    obj.Problem,obj.SourceBranch,obj.SeedIndex,direction, ...
                    options,obj.Context);
            else
                pair=obj.transferredAdjacentPair(direction,options);
            end
            obj.SeedPair=pair;
            obj.recordStep('seed_pair','Adjacent seed pair','completed', ...
                pair.Diagnostics);
        end

        function pair=makeGeneratedSeedPair(obj,radius,options)
            if nargin<2||isempty(radius)
                radius=obj.Descriptor.SeedPreset.GeneratedRadius;
            end
            if nargin<3,options=struct();end
            obj.assertAllowed({'seed_pair','seeds','continuation'});
            pair=lmz.services.SeedService().makeSecondSeed(obj.Problem, ...
                obj.WorkingSolution,radius,options,obj.Context);
            obj.SeedPair=pair;
            obj.recordStep('seed_pair','Generated seed pair','completed', ...
                pair.Diagnostics);
        end

        function pair=makeSecondSeed(obj,radius,options)
            if nargin<2,radius=[];end
            if nargin<3,options=struct();end
            pair=obj.makeGeneratedSeedPair(radius,options);
        end

        function result=continueBranch(obj,overrides)
            if nargin<2,overrides=struct();end
            obj.assertAllowed({'continuation','continue'});
            if isempty(obj.SeedPair)
                obj.makeAdjacentSeedPair(+1,struct());
            end
            options=obj.Descriptor.ContinuationPreset.mergedOptions(overrides);
            mode=options.DirectionMode;options=rmfield(options,'DirectionMode');
            pair=obj.SeedPair;
            if strcmp(mode,'backward')
                pair=reversePair(pair);options.BothDirections=false;
            end
            if ~isfield(options,'InitialStep')||isempty(options.InitialStep)
                options.InitialStep=pair.AchievedRadius;
            end
            obj.recordStep('continuation','Continuation','running', ...
                struct('DirectionMode',mode));
            try
                result=lmz.services.ContinuationService().run( ...
                    obj.Problem,pair,options,obj.Context);
                obj.ContinuationResult=result;
                status='completed';
                if strcmp(result.TerminationReason,'controlled_stop')
                    status='stopped';
                end
                obj.recordStep('continuation','Continuation',status,struct( ...
                    'DirectionMode',mode,'PointCount',result.Branch.pointCount(), ...
                    'TerminationReason',result.TerminationReason));
            catch exception
                obj.recordStep('continuation','Continuation','failed',struct( ...
                    'Identifier',exception.identifier,'Message',exception.message));
                rethrow(exception)
            end
        end

        function result=runContinuation(obj,overrides)
            if nargin<2,overrides=struct();end
            result=obj.continueBranch(overrides);
        end

        function result=continueWorkflow(obj,overrides)
            if nargin<2,overrides=struct();end
            result=obj.continueBranch(overrides);
        end

        function result=resumeCheckpoint(obj,path,options)
            if nargin<3,options=struct();end
            obj.assertAllowed({'continuation','continue'});
            result=lmz.services.ContinuationService().resumeCheckpoint( ...
                obj.Problem,path,options,obj.Context);
            obj.ContinuationResult=result;
            obj.recordStep('continuation','Checkpoint resume','completed', ...
                struct('Path',path,'PointCount',result.Branch.pointCount()));
        end

        function result=parameterHomotopy(obj,parameterName,targets,options)
            if nargin<4,options=struct();end
            obj.assertAllowed({'parameter_homotopy','homotopy'});
            result=lmz.services.ContinuationService().parameterHomotopy( ...
                obj.Problem,obj.WorkingSolution,parameterName,targets, ...
                mergePreset(obj.Descriptor.HomotopyPreset,options),obj.Context);
            obj.HomotopyResult=result;
            obj.recordStep('parameter_homotopy','Parameter homotopy', ...
                'completed',struct('Completed',result.Completed));
        end

        function report=branchFamilyScan(obj,parameterName,targets,options)
            if nargin<4,options=struct();end
            obj.assertAllowed({'branch_family','family_scan'});
            report=lmz.services.ContinuationService().branchFamilyScan( ...
                obj.Problem,obj.WorkingSolution,parameterName,targets, ...
                mergePreset(obj.Descriptor.FamilyScanPreset,options),obj.Context);
            obj.FamilyScanResult=report;
            obj.recordStep('branch_family','Branch family scan','completed', ...
                struct('Completed',report.Completed,'Failed',report.Failed));
        end

        function value=result(obj)
            value=lmz.workflow.WorkflowResult(struct( ...
                'WorkflowId',obj.Descriptor.Id,'ModelId',obj.Descriptor.ModelId, ...
                'ProblemId',obj.Descriptor.ProblemId, ...
                'DatasetId',obj.Descriptor.DefaultDatasetId, ...
                'SeedIndex',obj.SeedIndex,'SolveResult',obj.SolveResult, ...
                'SeedPair',obj.SeedPair, ...
                'ContinuationResult',obj.ContinuationResult, ...
                'HomotopyResult',obj.HomotopyResult, ...
                'FamilyScanResult',obj.FamilyScanResult, ...
                'Steps',obj.Steps,'Diagnostics',struct( ...
                'InitialResidualNorm',obj.InitialEvaluation.ScaledResidualNorm, ...
                'WorkflowSourceHash',obj.Descriptor.SourceHash)));
        end
    end
    methods (Access=private)
        function result=transferToWorkflowSection(obj,source)
            configuration=obj.Descriptor.ProblemConfiguration;
            target=fieldOr(configuration,'StartSectionId','');
            if isempty(target)
                options=obj.Descriptor.SeedPreset.Options;
                target=fieldOr(options,'transferToSectionId','');
            end
            if ~ischar(target)||isempty(target)
                error('lmz:Workflow:SectionTransferTarget', ...
                    ['A workflow whose source and target problems differ ' ...
                    'must declare a target section.']);
            end
            result=lmz.services.SectionTransferService().transfer( ...
                obj.Model,source,target,obj.Context);
            if ~strcmp(result.Solution.ModelId,obj.Descriptor.ModelId)|| ...
                    ~strcmp(result.Solution.ProblemId,obj.Descriptor.ProblemId)
                error('lmz:Workflow:SectionTransferProblem', ...
                    'Section transfer did not produce the workflow problem.');
            end
        end

        function pair=transferredAdjacentPair(obj,direction,options)
            if ~isstruct(options)||~isscalar(options)
                error('lmz:Workflow:SeedOptions', ...
                    'Adjacent-seed options must be one object.');
            end
            count=obj.SourceBranch.pointCount();index=obj.SeedIndex;
            if ~(isnumeric(direction)&&isscalar(direction)&& ...
                    isfinite(direction)&&direction~=0)
                error('lmz:Seed:Direction', ...
                    'Adjacent seed direction must be nonzero.');
            end
            neighbor=index+sign(direction);inwardAdjusted=false;
            if neighbor<1||neighbor>count
                neighbor=index-sign(direction);inwardAdjusted=true;
            end
            if neighbor<1||neighbor>count||neighbor==index
                error('lmz:Seed:NoNeighbor', ...
                    'No distinct inward neighbor is available.');
            end
            firstTransfer=obj.transferToWorkflowSection( ...
                obj.SourceBranch.point(index));
            secondTransfer=obj.transferToWorkflowSection( ...
                obj.SourceBranch.point(neighbor));
            first=firstTransfer.Solution;second=secondTransfer.Solution;
            parameterTolerance=option(options,'ParameterTolerance',1e-10);
            if any(abs(first.ParameterValues-second.ParameterValues)> ...
                    parameterTolerance.*max(1,abs(first.ParameterValues)))
                error('lmz:Seed:ParameterMismatch', ...
                    'Adjacent seeds have incompatible parameters.');
            end
            metric=lmz.schema.DiagonalMetric( ...
                obj.Problem.scale(first.DecisionValues));
            distance=metric.norm(obj.Problem.difference( ...
                second.DecisionValues,first.DecisionValues));
            if ~isfinite(distance)||distance<= ...
                    option(options,'MinimumSeparation',1e-10)
                error('lmz:Seed:DuplicateSeeds', ...
                    'Adjacent points are not chart-distinct.');
            end
            firstEvaluation=obj.Problem.evaluate(first.DecisionValues, ...
                first.ParameterValues,obj.Context,false);
            secondEvaluation=obj.Problem.evaluate(second.DecisionValues, ...
                second.ParameterValues,obj.Context,false);
            residuals=[firstEvaluation.ScaledResidualNorm ...
                secondEvaluation.ScaledResidualNorm];
            if max(residuals)>option(options,'ResidualTolerance',1e-6)
                error('lmz:Seed:ResidualTooLarge', ...
                    'Transferred adjacent-seed residual exceeds tolerance.');
            end
            diagnostics=struct('SourceBranchId',obj.SourceBranch.Id, ...
                'SourceIndices',[index neighbor], ...
                'InwardAdjusted',inwardAdjusted, ...
                'ResidualNorms',residuals,'ChartDistance',distance, ...
                'ParameterTolerance',parameterTolerance, ...
                'SectionLocal',true);
            pair=lmz.data.SolutionPair(first,second,distance,distance, ...
                diagnostics);
        end

        function assertAllowed(obj,aliases)
            if ~any(ismember(aliases,obj.Descriptor.AllowedSteps))
                error('lmz:Workflow:StepNotAllowed', ...
                    'Workflow %s does not allow step %s.', ...
                    obj.Descriptor.Id,aliases{1});
            end
        end
        function recordStep(obj,id,label,status,diagnostics)
            step=lmz.workflow.WorkflowStep(id,label,status,diagnostics);
            existing=find(arrayfun(@(item)strcmp(item.Id,id),obj.Steps),1,'last');
            if isempty(existing)||strcmp(status,'running')
                obj.Steps(end+1,1)=step;
            else
                obj.Steps(existing)=step;
            end
        end
    end
end

function value=mergeStruct(base,overrides)
if isempty(base),base=struct();end
if isempty(overrides),overrides=struct();end
if ~isstruct(overrides)||~isscalar(overrides)
    error('lmz:Workflow:Options','Workflow overrides must be an object.');
end
value=base;names=fieldnames(overrides);
for index=1:numel(names),value.(names{index})=overrides.(names{index});end
end
function value=mergePreset(preset,overrides)
value=mergeStruct(preset.Values,overrides);
names={'id','label','values'};
for index=1:numel(names)
    if isfield(value,names{index}),value=rmfield(value,names{index});end
end
end
function pair=reversePair(source)
pair=lmz.data.SolutionPair(source.Second,source.First, ...
    source.RequestedRadius,source.AchievedRadius,source.Diagnostics);
end
function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=option(options,name,fallback)
if isfield(options,name),value=options.(name);else,value=fallback;end
end
