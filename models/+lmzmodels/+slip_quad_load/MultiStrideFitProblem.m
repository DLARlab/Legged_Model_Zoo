classdef MultiStrideFitProblem < lmz.api.OptimizationProblem
    %MULTISTRIDEFITPROBLEM Source-equivalent X_accum gait/load objective.
    properties (SetAccess=private)
        Dataset
        DatasetPath
        SourceDecision
        Simulator
        ActiveOptimizationIndices
        StridePlan
        ReferenceExperimental
        ReferenceExtensionPolicy
        SourceEquivalent
        ObjectiveTimingMode
        TimingSeedProvenance
        InputTruncationDiagnostics
    end
    methods
        function obj=MultiStrideFitProblem(model,configuration)
            if nargin<2,configuration=struct();end
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            datasetPath=catalog.defaultMultiPath();if isfield(configuration,'DatasetPath'),datasetPath=configuration.DatasetPath;end
            dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(datasetPath);
            problemId=fieldOr(configuration,'ProblemId','multi_stride_fit');
            timingMode=objectiveTimingMode(problemId,configuration);
            [configuration,timingSeedProvenance]=prepareFixedTimingSeed( ...
                configuration,dataset,problemId);
            [source,plan,strideCount,inputTruncation]=resolvePlan( ...
                configuration,dataset);
            [reference,referencePolicy]=referenceData( ...
                dataset.Experimental,strideCount,dataset.StrideCount,configuration);
            active=activeIndices(strideCount);
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
            decision=lmzmodels.slip_quad_load.MultiStrideDecisionSchema.create(strideCount,defaults);
            parameters=lmzmodels.slip_quad_load.ObjectiveWeightSchema.create(dataset.TermWeights);
            configuration.NumberOfStrides=strideCount;
            configuration.TimingMode=timingMode;
            configuration.ReferenceExtensionPolicy=referencePolicy;
            configuration.StridePlanComplete=true;
            sourceEquivalent=strcmp(timingMode, ...
                'legacy_source_timing_projection')&& ...
                strideCount==dataset.StrideCount&& ...
                isequaln(source(:),dataset.XAccum(:))&& ...
                strcmp(referencePolicy,'measured_reference_only');
            if strcmp(timingMode,'legacy_source_timing_projection')&& ...
                    ~sourceEquivalent
                error('lmz:QuadLoad:LegacyCompatibilityScope', ...
                    ['multi_stride_fit legacy compatibility is limited to ' ...
                    'the exact bundled source dataset. Use n_stride_fit.']);
            end
            obj@lmz.api.OptimizationProblem(model,problemId,'optimization', ...
                decision,parameters,parameters.defaults(),configuration);
            obj.Version='2.0.0';obj.Dataset=dataset;obj.DatasetPath=datasetPath;
            obj.SourceDecision=source;obj.ActiveOptimizationIndices=active;
            obj.StridePlan=plan;obj.ReferenceExperimental=reference;
            obj.ReferenceExtensionPolicy=referencePolicy;
            obj.SourceEquivalent=sourceEquivalent;
            obj.ObjectiveTimingMode=timingMode;
            obj.TimingSeedProvenance=timingSeedProvenance;
            obj.InputTruncationDiagnostics=inputTruncation;
            obj.Simulator=lmzmodels.slip_quad_load.MultiStrideSimulator();
        end
        function [value,terms,diagnostics]=evaluateObjective(obj,u,p,context)
            context.check();obj.DecisionSchema.validateVector(u);obj.ParameterSchema.validateVector(p);
            enforceTiming=strcmp(obj.ObjectiveTimingMode, ...
                'legacy_source_timing_projection');
            raw=obj.Simulator.runRaw(u,context,enforceTiming);
            duration=lmzmodels.slip_quad_load.ObjectiveTerms.StrideDurationMismatch.evaluate( ...
                raw.Parameters,obj.ReferenceExperimental.t_exp,p(1));
            footfall=lmzmodels.slip_quad_load.ObjectiveTerms.FootfallTimingMismatch.evaluate( ...
                raw.Parameters,obj.ReferenceExperimental.ft_exp,p(2));
            loading=lmzmodels.slip_quad_load.ObjectiveTerms.LoadingForceMismatch.evaluate( ...
                raw,obj.ReferenceExperimental.loading_force_exp,p(3));
            terms=struct('StrideDuration',duration,'FootfallTiming',footfall,'LoadingForce',loading);
            [value,composite]=lmzmodels.slip_quad_load.ObjectiveTerms.CompositeObjective.compute(terms);
            [r2,r2Diagnostics]=lmzmodels.slip_quad_load.ObjectiveTerms.R2Metrics.compute( ...
                duration,footfall,loading,p(:).');
            diagnostics=struct('LegacyEquivalent',obj.SourceEquivalent, ...
                'SourceEquivalent',obj.SourceEquivalent,'ObjectiveFormulation', ...
                'source-fms_NStridesObjectiveFcn_Quad_Load_v2','DatasetPath',obj.DatasetPath, ...
                'DatasetId',obj.Dataset.Id,'StrideCount',raw.StrideCount,'Composite',composite, ...
                'R2',r2,'R2Diagnostics',r2Diagnostics,'Residual',raw.Residual, ...
                'ResidualNorm',norm(raw.Residual),'PerStrideParameters',raw.Parameters, ...
                'ReferenceExtensionPolicy',obj.ReferenceExtensionPolicy, ...
                'RepeatedReferenceIsMeasuredData',false, ...
                'StridePlanComplete',true,'TimingMode',obj.ObjectiveTimingMode, ...
                'HiddenTimingSolve',enforceTiming, ...
                'ContactConstraintsExplicit',~enforceTiming, ...
                'ContactResidualNorms',perStrideContactNorms(raw), ...
                'TimingSeedProvenance',obj.TimingSeedProvenance, ...
                'InputTruncated',logical(obj.InputTruncationDiagnostics. ...
                ExplicitTruncation), ...
                'InputTruncation',obj.InputTruncationDiagnostics, ...
                'InputTruncationDiagnostics',obj.InputTruncationDiagnostics, ...
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
        function [c,ceq]=nonlinearConstraints(obj,u,p,context)
            context.check();
            obj.DecisionSchema.validateVector(u);
            obj.ParameterSchema.validateVector(p);
            c=[];
            if strcmp(obj.ObjectiveTimingMode, ...
                    'legacy_source_timing_projection')
                ceq=[];return
            end
            raw=obj.Simulator.runRaw(u,context,false);
            ceq=raw.FirstNineResiduals(:);
        end
        function result=simulateDecision(obj,u,context)
            result=obj.Simulator.run(u,context,struct('EnforceEventTiming',false));
        end
        function value=sourceSeed(obj),value=obj.SourceDecision;end
        function value=getDescriptor(obj)
            value=getDescriptor@lmz.api.BaseProblem(obj);
            if ~obj.SourceEquivalent
                value.maturity='experimental';
                value.validationStatus='tested';
                value.configuredSourceEquivalent=false;
            end
        end
        function solution=makeSolution(obj,u,p,evaluation)
            if nargin<3||isempty(p),p=obj.DefaultParameters;end
            if nargin<4,evaluation=[];end
            solution=makeSolution@lmz.api.BaseProblem(obj,u,p,evaluation);
            data=solution.toStruct();data.DecisionSchema=solution.DecisionSchema;data.ParameterSchema=solution.ParameterSchema;data.ResidualBlocks=solution.ResidualBlocks;
            data.Provenance=struct('source','scientific-load-dataset','datasetId',obj.Dataset.Id, ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'referenceExtensionPolicy',obj.ReferenceExtensionPolicy, ...
                'configuredSourceEquivalent',obj.SourceEquivalent, ...
                'timingSeedProvenance',obj.TimingSeedProvenance, ...
                'inputTruncation',obj.InputTruncationDiagnostics);solution=lmz.data.Solution(data);
        end
    end
end
function value=activeIndices(strideCount)
if strideCount>1
    value=[];
    for stride=2:strideCount
        indices=lmzmodels.slip_quad_load.LaterStrideLayout.globalIndices(stride);
        value=[value indices.PostSwingStiffness]; %#ok<AGROW>
    end
else
    indices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
    value=indices.PostSwingStiffness;
end
end

function [source,plan,count,truncation]=resolvePlan(configuration,dataset)
hasPlan=isfield(configuration,'StridePlan')&&~isempty(configuration.StridePlan);
hasDecision=isfield(configuration,'InitialDecision')&& ...
    ~isempty(configuration.InitialDecision);
if hasPlan&&hasDecision
    error('lmz:MultiStride:AmbiguousInput', ...
        'Specify StridePlan or InitialDecision, not both.');
end
if hasPlan
    plan=configuration.StridePlan;
    validatePlan(plan);
    source=lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(plan);
elseif hasDecision
    source=configuration.InitialDecision(:);
    plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
        source,'ProblemId','multi_stride_fit');
else
    source=dataset.XAccum(:);
    plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
        source,'ProblemId','multi_stride_fit');
end
count=plan.CompletedStrideCount;
truncation=fieldOr(configuration,'InputTruncationDiagnostics', ...
    noTruncationDiagnostics(inputSource(hasPlan,hasDecision), ...
    count,numel(source)));
if isfield(configuration,'NumberOfStrides')
    requested=configuration.NumberOfStrides;
    validateCount(requested);
    if requested<count
        originalCount=count;originalLength=numel(source);
        plan=plan.truncate(requested);
        source=lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(plan);
        count=requested;
        truncation=struct('Source',inputSource(hasPlan,hasDecision), ...
            'OriginalStrideCount',originalCount, ...
            'RetainedStrideCount',requested, ...
            'OriginalLength',originalLength,'RetainedLength',numel(source), ...
            'ExplicitTruncation',true);
    elseif requested>count
        error('lmz:MultiStride:OptimizationPlanIncomplete', ...
            ['NumberOfStrides must match a fully supplied StridePlan or ' ...
            'InitialDecision. Optimization does not complete timings.']);
    end
end
validatePlan(plan);
end

function validatePlan(plan)
if ~isa(plan,'lmz.multistride.StridePlan')|| ...
        ~strcmp(plan.ModelId,'slip_quad_load')|| ...
        plan.CompletedStrideCount~=plan.RequestedStrideCount
    error('lmz:MultiStride:OptimizationPlanIncomplete', ...
        'Optimization requires a complete slip_quad_load StridePlan.');
end
for stride=1:plan.CompletedStrideCount
    schedule=plan.StrideSpecs(stride).EventSchedule;
    failed=isstruct(schedule)&&((isfield(schedule,'TimingCorrectionFailed')&& ...
        logical(schedule.TimingCorrectionFailed))|| ...
        (isfield(schedule,'SafetyFallback')&&logical(schedule.SafetyFallback)));
    if failed
        error('lmz:MultiStride:OptimizationTimingEvidence', ...
            ['Optimization rejects fallback or failed timing schedules; ' ...
            'supply a feasible precompleted plan.']);
    end
end
end

function [value,policy]=referenceData(source,count,available,configuration)
policy=fieldOr(configuration,'ReferenceExtensionPolicy', ...
    'measured_reference_only');
if count>available&&~strcmp(policy,'repeat_final_reference')
    error('lmz:MultiStride:ReferenceExtensionRequired', ...
        ['The bundled dataset has %d measured strides. Set ' ...
        'ReferenceExtensionPolicy to repeat_final_reference explicitly.'], ...
        available);
end
if ~any(strcmp(policy,{'measured_reference_only','repeat_final_reference'}))
    error('lmz:MultiStride:ReferenceExtensionPolicy', ...
        'Unknown reference extension policy %s.',policy);
end
value=source;
value.t_exp=resizeTimeReference(source.t_exp,count);
value.loading_force_exp=resizeForceReference( ...
    source.loading_force_exp,count);
rows=min((1:count).',available);
value.ft_exp=source.ft_exp(rows,:);
if count<=available
    policy='measured_reference_only';
end
end

function value=resizeTimeReference(source,count)
if iscell(source)
    value=resizeCell(source,count);return
end
if ~isnumeric(source)||isempty(source)
    error('lmz:MultiStride:ReferenceData','Time reference data are invalid.');
end
available=size(source,1);rows=min((1:count).',available);
value=source(rows,:);
end

function value=resizeForceReference(source,count)
if iscell(source)
    value=resizeCell(source,count);return
end
if ~isnumeric(source)||isempty(source)
    error('lmz:MultiStride:ReferenceData','Force reference data are invalid.');
end
available=size(source,2);columns=min(1:count,available);
value=source(:,columns);
end

function value=resizeCell(source,count)
if isempty(source)
    error('lmz:MultiStride:ReferenceData', ...
        'Per-stride reference cells cannot be empty.');
end
available=numel(source);value=cell(count,1);
for index=1:count
    value{index}=source{min(index,available)};
end
end

function validateCount(value)
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)|| ...
        value<1||value~=fix(value)
    error('lmz:MultiStride:StrideCount', ...
        'NumberOfStrides must be a positive integer.');
end
end

function value=objectiveTimingMode(problemId,configuration)
if ~any(strcmp(problemId,{'multi_stride_fit','n_stride_fit'}))
    error('lmz:QuadLoad:FitProblemId','Unknown fit problem ID %s.',problemId);
end
if strcmp(problemId,'multi_stride_fit')
    fallback='legacy_source_timing_projection';
else
    fallback='fixed_precompleted';
end
value=fieldOr(configuration,'ObjectiveTimingMode',fallback);
if ~strcmp(value,fallback)
    error('lmz:QuadLoad:FitTimingMode', ...
        '%s requires ObjectiveTimingMode %s.',problemId,fallback);
end
end

function [configuration,provenance]=prepareFixedTimingSeed( ...
        configuration,dataset,problemId)
provenance=struct('Source','supplied_plan_or_decision', ...
    'RuntimeTimingSolve',false);
if ~strcmp(problemId,'n_stride_fit')|| ...
        isfield(configuration,'StridePlan')|| ...
        isfield(configuration,'InitialDecision')
    return
end
if ~strcmp(dataset.Id,'P4_TR_RL_Individual_1')
    error('lmz:MultiStride:FixedTimingSeedRequired', ...
        ['n_stride_fit requires an explicit complete plan/decision for ' ...
        'datasets without a repository-captured fixed timing seed.']);
end
path=fullfile(lmz.util.ProjectPaths.catalog(),'slip_quad_load', ...
    'n_stride_fit_seed.json');
stored=lmz.io.SafeJson.read(path,'Root',fileparts(path));
required={'schemaVersion','datasetId','sourceDatasetSha256', ...
    'generationMethod','xAccum'};
if ~all(isfield(stored,required))||~strcmp(stored.schemaVersion,'1.0.0')|| ...
        ~strcmp(stored.datasetId,dataset.Id)|| ...
        ~strcmpi(stored.sourceDatasetSha256, ...
        lmz.util.FileHash.sha256(dataset.Path))
    error('lmz:MultiStride:FixedTimingSeedIntegrity', ...
        'The repository fixed-timing seed does not match its source dataset.');
end
seed=stored.xAccum(:);
configuration.InitialDecision=seed;
provenance=struct('Source','repository_captured_fixed_timing_seed', ...
    'Path',path,'SourceDatasetSha256',stored.sourceDatasetSha256, ...
    'GenerationMethod',stored.generationMethod,'RuntimeTimingSolve',false);
end

function value=inputSource(hasPlan,hasDecision)
if hasPlan
    value='StridePlan';
elseif hasDecision
    value='InitialDecision';
else
    value='default_dataset';
end
end

function value=noTruncationDiagnostics(source,count,lengthValue)
value=struct('Source',source,'OriginalStrideCount',count, ...
    'RetainedStrideCount',count,'OriginalLength',lengthValue, ...
    'RetainedLength',lengthValue,'ExplicitTruncation',false);
end

function value=perStrideContactNorms(raw)
value=zeros(raw.StrideCount,1);
for stride=1:raw.StrideCount
    rows=(stride-1)*9+(1:9);
    value(stride)=norm(raw.FirstNineResiduals(rows));
end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
