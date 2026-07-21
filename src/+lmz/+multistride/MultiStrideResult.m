classdef MultiStrideResult
    %MULTISTRIDERESULT Completed or explicitly partial multi-stride outcome.
    properties (SetAccess=private)
        Plan
        Simulation
        RequestedStrideCount
        CompletedStrideCount
        CompletionStatus
        Diagnostics
        Failure
        Checkpoints
        XAccum
        EnergyDiagnostics
        Partial
    end

    methods
        function obj=MultiStrideResult(plan,varargin)
            if ~isa(plan,'lmz.multistride.StridePlan')||~isscalar(plan)
                error('lmz:MultiStride:ResultPlan','MultiStrideResult requires a plan.');
            end
            parser=inputParser;
            addParameter(parser,'Simulation',[]);
            addParameter(parser,'CompletionStatus',defaultStatus(plan),@isStatus);
            addParameter(parser,'Diagnostics',struct(),@isstruct);
            addParameter(parser,'Failure',struct(),@isstruct);
            addParameter(parser,'Checkpoints',{},@iscell);
            addParameter(parser,'XAccum',zeros(0,1),@isFiniteNumeric);
            addParameter(parser,'EnergyDiagnostics',{},@iscell);
            parse(parser,varargin{:});values=parser.Results;
            obj.Plan=plan;obj.Simulation=values.Simulation;
            obj.RequestedStrideCount=plan.RequestedStrideCount;
            obj.CompletedStrideCount=plan.CompletedStrideCount;
            obj.CompletionStatus=char(values.CompletionStatus);
            obj.Diagnostics=values.Diagnostics;obj.Failure=values.Failure;
            obj.Checkpoints=values.Checkpoints;obj.XAccum=values.XAccum(:);
            obj.EnergyDiagnostics=values.EnergyDiagnostics;
            obj.Partial=plan.CompletedStrideCount<plan.RequestedStrideCount;
            if strcmp(obj.CompletionStatus,'complete')&&obj.Partial
                error('lmz:MultiStride:ResultStatus', ...
                    'An incomplete plan cannot have complete status.');
            end
        end

        function value=toStruct(obj)
            simulation=obj.Simulation;
            if isobject(simulation)&&ismethod(simulation,'toStruct')
                simulation=simulation.toStruct();
            end
            value=struct('Plan',obj.Plan.toStruct(),'Simulation',simulation, ...
                'RequestedStrideCount',obj.RequestedStrideCount, ...
                'CompletedStrideCount',obj.CompletedStrideCount, ...
                'CompletionStatus',obj.CompletionStatus, ...
                'Diagnostics',obj.Diagnostics,'Failure',obj.Failure, ...
                'Checkpoints',{obj.Checkpoints},'XAccum',obj.XAccum, ...
                'EnergyDiagnostics',{obj.EnergyDiagnostics}, ...
                'Partial',obj.Partial);
        end

        function artifact=toArtifact(obj,request,randomSeed)
            if nargin<2||isempty(request)
                request=lmz.multistride.MultiStrideRequest( ...
                    'NumberOfStrides',obj.RequestedStrideCount, ...
                    'StridePlan',obj.Plan, ...
                    'CompletionPolicy',obj.Plan.CompletionPolicy, ...
                    'EnergyPolicy',obj.Plan.EnergyPolicy, ...
                    'EnergyNeutralOnly', ...
                    ~strcmp(obj.Plan.EnergyPolicy.Id,'allow_non_neutral'), ...
                    'FailurePolicy',obj.Plan.FailurePolicy);
            end
            if nargin<3,randomSeed=0;end
            if ~isa(request,'lmz.multistride.MultiStrideRequest')
                error('lmz:MultiStride:ArtifactRequest', ...
                    'Multi-stride artifacts require the originating request.');
            end
            artifact=lmz.io.ArtifactStore.workflowBase( ...
                obj.Plan.ModelId,obj.Plan.ProblemId);
            if isempty(obj.Simulation)
                artifact.artifactType='stride-plan-completion-run';
            else
                artifact.artifactType='n-stride-simulation-run';
            end
            artifact.multiStrideResult=obj.toStruct();
            artifact.stridePlan=obj.Plan.toStruct();
            artifact.request=request.toStruct();
            artifact.diagnostics=obj.Diagnostics;
            artifact.lineage=obj.Plan.Provenance;
            ids=cell(1,2*obj.Plan.CompletedStrideCount);
            for index=1:obj.Plan.CompletedStrideCount
                ids{2*index-1}=obj.Plan.StrideSpecs(index).StartSectionId;
                ids{2*index}=obj.Plan.StrideSpecs(index).StopSectionId;
            end
            artifact.poincareMetadata=lmz.io.ArtifactStore.sectionMetadata( ...
                obj.Plan.ModelId,ids);
            sourceHashes=struct();
            relative=artifact.poincareMetadata.CatalogRelativePath;
            if ~isempty(relative)
                sourceHashes.PoincareCatalog=struct( ...
                    'relativePath',relative,'sha256', ...
                    artifact.poincareMetadata.CatalogHash);
            end
            details=struct('Options',request.toStruct(), ...
                'SourceSeed',obj.Plan.toStruct(),'RandomSeed',randomSeed, ...
                'Provenance',obj.Plan.Provenance, ...
                'TerminationReason',obj.CompletionStatus, ...
                'Warnings',{{}},'SourceDataHashes',sourceHashes);
            artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            required={'Plan','Simulation','RequestedStrideCount', ...
                'CompletedStrideCount','CompletionStatus','Diagnostics', ...
                'Failure','Checkpoints','XAccum','EnergyDiagnostics','Partial'};
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~all(isfield(value,required))
                error('lmz:MultiStride:StoredResult', ...
                    'Stored multi-stride result is incomplete.');
            end
            plan=lmz.multistride.StridePlan.fromStruct(value.Plan);
            simulation=value.Simulation;
            if isstruct(simulation)&&isfield(simulation,'time')
                simulation=lmz.api.SimulationResult.fromStruct(simulation);
            end
            obj=lmz.multistride.MultiStrideResult(plan, ...
                'Simulation',simulation, ...
                'CompletionStatus',value.CompletionStatus, ...
                'Diagnostics',value.Diagnostics,'Failure',value.Failure, ...
                'Checkpoints',value.Checkpoints,'XAccum',value.XAccum, ...
                'EnergyDiagnostics',value.EnergyDiagnostics);
            if obj.RequestedStrideCount~=value.RequestedStrideCount|| ...
                    obj.CompletedStrideCount~=value.CompletedStrideCount|| ...
                    obj.Partial~=logical(value.Partial)
                error('lmz:MultiStride:StoredResultCounts', ...
                    'Stored result counts disagree with its stride plan.');
            end
        end

        function obj=fromArtifact(artifact)
            lmz.io.ArtifactStore.validate(artifact);
            supported={'stride-plan-completion-run', ...
                'n-stride-simulation-run'};
            if ~any(strcmp(artifact.artifactType,supported))
                error('lmz:MultiStride:ArtifactType', ...
                    'Artifact is not a multi-stride workflow result.');
            end
            obj=lmz.multistride.MultiStrideResult.fromStruct( ...
                artifact.multiStrideResult);
        end
    end
end

function value=defaultStatus(plan)
if plan.CompletedStrideCount==plan.RequestedStrideCount,value='complete'; ...
else,value='partial';end
end
function value=isStatus(source)
value=(ischar(source)||(isstring(source)&&isscalar(source)))&& ...
    any(strcmp(char(source),{'complete','partial','failed', ...
    'missing_stride_specification','cancelled'}));
end
function value=isFiniteNumeric(source)
value=isnumeric(source)&&isreal(source)&&all(isfinite(source(:)));
end
