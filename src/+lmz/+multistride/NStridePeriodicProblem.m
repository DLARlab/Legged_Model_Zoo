classdef NStridePeriodicProblem < lmz.api.NonlinearEquationProblem
    %NSTRIDEPERIODICPROBLEM Explicit-contact, final-return-only problem.
    properties (SetAccess=private)
        NumberOfStrides
        StridePlan
        TimingMode
        Evaluator
        ExpectedDimension
    end

    methods
        function obj=NStridePeriodicProblem(model,varargin)
            [decision,parameters,defaults,evaluator,configuration]= ...
                parseInputs(varargin{:});
            obj@lmz.api.NonlinearEquationProblem(model,'n_stride_periodic', ...
                'nonlinear_equation',decision,parameters,defaults,configuration);
            obj.NumberOfStrides=positiveInteger(configuration, ...
                'NumberOfStrides',1);
            obj.StridePlan=fieldOr(configuration,'StridePlan',[]);
            obj.TimingMode=timingMode(configuration);
            obj.Evaluator=evaluator;
            obj.ExpectedDimension=nonnegativeInteger(configuration, ...
                'ExpectedLocalDimension',1);
            validateTimingEvidence(obj.TimingMode,obj.StridePlan,configuration, ...
                obj.NumberOfStrides);
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            if nargin<5
                includeSimulation=false;
            end
            context.check();
            obj.DecisionSchema.validateVector(u);
            obj.ParameterSchema.validateVector(p);
            contract=obj.contract();
            value=obj.Evaluator(u(:),p(:),context,includeSimulation,contract);
            [contacts,closure]=validateEvaluation( ...
                value,obj.NumberOfStrides,obj.Configuration);
            blocks=contactBlocks(contacts);
            blocks(end+1,1)=lmz.data.ResidualBlock( ...
                'final_section_closure',closure,ones(numel(closure),1));
            feasibility=fieldOr(value,'Feasibility', ...
                struct('Valid',all(isfinite([vertcat(contacts{:});closure]))));
            simulation=[];
            if includeSimulation
                simulation=fieldOr(value,'Simulation',[]);
            end
            diagnostics=fieldOr(value,'Diagnostics',struct());
            diagnostics.NumberOfStrides=obj.NumberOfStrides;
            diagnostics.TimingMode=obj.TimingMode;
            diagnostics.IntermediatePeriodicityImposed=false;
            diagnostics.FinalReturnClosureOnly=true;
            diagnostics.HiddenTimingSolve=false;
            evaluation=lmz.data.ProblemEvaluation(blocks, ...
                'Simulation',simulation,'Feasibility',feasibility, ...
                'PhysicalValidity',fieldOr(value,'PhysicalValidity', ...
                feasibility.Valid),'Diagnostics',diagnostics);
        end

        function value=expectedLocalDimension(obj)
            value=obj.ExpectedDimension;
        end

        function value=contract(obj)
            value=struct('NumberOfStrides',obj.NumberOfStrides, ...
                'StridePlan',obj.StridePlan,'TimingMode',obj.TimingMode, ...
                'IntermediatePeriodicityImposed',false, ...
                'FinalReturnClosureOnly',true,'HiddenTimingSolve',false);
        end

        function artifact=toRunArtifact(obj,result)
            %TORUNARTIFACT Persist an inert, reproducible periodic-solve run.
            if ~isa(result,'lmz.data.SolveResult')||~isscalar(result)|| ...
                    ~isa(result.Solution,'lmz.data.Solution')|| ...
                    ~strcmp(result.Solution.ProblemId,obj.Id)
                error('lmz:MultiStride:PeriodicArtifactResult', ...
                    'The run must be a SolveResult produced for this problem.');
            end
            plan=obj.StridePlan;
            if ~isa(plan,'lmz.multistride.StridePlan')||~isscalar(plan)|| ...
                    plan.RequestedStrideCount~=obj.NumberOfStrides|| ...
                    plan.CompletedStrideCount~=obj.NumberOfStrides
                error('lmz:MultiStride:PeriodicArtifactPlan', ...
                    'A complete native StridePlan is required for persistence.');
            end
            planRecord=plan.toStruct();
            configuration=storedConfiguration(obj.Configuration,planRecord);
            planHash=lmz.io.ArtifactStore.dataHash(planRecord);
            configurationHash=lmz.io.ArtifactStore.dataHash(configuration);
            startId=fieldOr(obj.Configuration,'StartSectionId', ...
                plan.StrideSpecs(1).StartSectionId);
            stopId=fieldOr(obj.Configuration,'StopSectionId', ...
                plan.StrideSpecs(end).StopSectionId);
            ids=sectionIds(plan,startId,stopId);
            poincare=lmz.io.ArtifactStore.sectionMetadata( ...
                result.Solution.ModelId,ids);
            stride=lmz.io.ArtifactStore.strideDefinitionMetadata( ...
                result.Solution.ModelId,startId,stopId);
            reason=terminationReason(result.ExitFlag,result.Output);
            sourceSeed=storedSeed(result.SourceSeed);
            provenance=storedProvenance(result.Provenance,configuration);
            evaluation=storedEvaluation(result.Evaluation);
            accepted=isstruct(result.Output)&& ...
                isfield(result.Output,'algorithm')&& ...
                strcmp(result.Output.algorithm,'accepted-existing-seed');

            artifact=result.Solution.toArtifact();
            artifact.artifactType='n-stride-periodic-run';
            artifact.stridePlan=planRecord;
            artifact.stridePlanHash=planHash;
            artifact.poincareMetadata=poincare;
            artifact.strideDefinition=stride.Record;
            artifact.strideDefinitionHash=stride.Hash;
            artifact.diagnostics=struct('ExitFlag',result.ExitFlag, ...
                'Output',result.Output, ...
                'ScaledResidualNorm',result.Evaluation.ScaledResidualNorm, ...
                'AcceptedExistingSeed',accepted, ...
                'EvaluationDiagnostics',result.Evaluation.Diagnostics);
            artifact.nStridePeriodicResult=struct( ...
                'Solution',result.Solution.toStruct(), ...
                'Evaluation',evaluation,'ExitFlag',result.ExitFlag, ...
                'Output',result.Output,'Options',result.Options, ...
                'SourceSeed',sourceSeed,'RandomSeed',result.RandomSeed, ...
                'Provenance',provenance,'TerminationReason',reason, ...
                'AcceptedExistingSeed',accepted);
            sourceHashes=struct('StridePlan',planHash, ...
                'ProblemConfiguration',configurationHash, ...
                'StrideDefinition',stride.Hash);
            if ~isempty(poincare.CatalogRelativePath)
                sourceHashes.PoincareCatalog=struct( ...
                    'relativePath',poincare.CatalogRelativePath, ...
                    'sha256',poincare.CatalogHash);
            end
            details=struct('Options',result.Options, ...
                'SourceSeed',sourceSeed,'RandomSeed',result.RandomSeed, ...
                'Provenance',provenance, ...
                'ElapsedTime',numericField(provenance,'elapsedTime',NaN), ...
                'FunctionEvaluations',numericField(provenance, ...
                'evaluations',numericField(result.Output,'funcCount',NaN)), ...
                'TerminationReason',reason, ...
                'Warnings',{result.Evaluation.Warnings}, ...
                'SourceDataHashes',sourceHashes);
            artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);
            artifact.problemMetadata.configuration=configuration;
            artifact.problemConfigurationHash=configurationHash;
            lmz.io.ArtifactStore.validate(artifact);
        end
    end
end

function value=storedConfiguration(source,planRecord)
value=source;
value.StridePlan=planRecord;
lmz.io.ArtifactStore.dataHash(value);
end

function value=storedSeed(source)
if isa(source,'lmz.data.Solution')
    value=source.toStruct();
else
    value=source;
end
end

function value=storedProvenance(source,configuration)
value=source;
if isstruct(value)&&isscalar(value)&& ...
        isfield(value,'problemMetadata')&& ...
        isstruct(value.problemMetadata)&&isscalar(value.problemMetadata)
    value.problemMetadata.configuration=configuration;
end
lmz.io.ArtifactStore.dataHash(value);
end

function value=storedEvaluation(evaluation)
if ~isa(evaluation,'lmz.data.ProblemEvaluation')||~isscalar(evaluation)
    error('lmz:MultiStride:PeriodicArtifactEvaluation', ...
        'Periodic solve evaluation is invalid.');
end
blocks=cell(numel(evaluation.ResidualBlocks),1);
for index=1:numel(blocks)
    blocks{index}=evaluation.ResidualBlocks(index).toStruct();
end
simulation=evaluation.Simulation;
if isobject(simulation)&&ismethod(simulation,'toStruct')
    simulation=simulation.toStruct();
end
value=struct('ResidualBlocks',{blocks}, ...
    'Residual',evaluation.Residual, ...
    'UnscaledResidual',evaluation.UnscaledResidual, ...
    'ScaledResidual',evaluation.ScaledResidual, ...
    'ResidualNorm',evaluation.ResidualNorm, ...
    'UnscaledResidualNorm',evaluation.UnscaledResidualNorm, ...
    'ScaledResidualNorm',evaluation.ScaledResidualNorm, ...
    'Simulation',simulation,'Feasibility',evaluation.Feasibility, ...
    'PhysicalValidity',evaluation.PhysicalValidity, ...
    'Warnings',{evaluation.Warnings}, ...
    'Diagnostics',evaluation.Diagnostics);
end

function ids=sectionIds(plan,startId,stopId)
ids={startId,stopId};
for index=1:plan.CompletedStrideCount
    ids{end+1}=plan.StrideSpecs(index).StartSectionId; %#ok<AGROW>
    ids{end+1}=plan.StrideSpecs(index).StopSectionId; %#ok<AGROW>
end
end

function value=terminationReason(exitFlag,output)
if exitFlag>0
    value='converged';
elseif exitFlag==0
    value='iteration-or-evaluation-limit';
else
    value='solver-failure';
end
if isstruct(output)&&isfield(output,'algorithm')&& ...
        strcmp(output.algorithm,'accepted-existing-seed')
    value='accepted-existing-seed';
end
end

function value=numericField(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name)&& ...
        isnumeric(source.(name))&&isscalar(source.(name))
    value=source.(name);
end
end

function [decision,parameters,defaults,evaluator,configuration]=parseInputs(varargin)
if isscalar(varargin)&&isstruct(varargin{1})
    configuration=varargin{1};
    decision=requiredField(configuration,'DecisionSchema');
    evaluator=requiredField(configuration,'Evaluator');
    parameters=fieldOr(configuration,'ParameterSchema',emptySchema());
    defaults=fieldOr(configuration,'DefaultParameters',parameters.defaults());
elseif numel(varargin)==5
    decision=varargin{1};parameters=varargin{2};defaults=varargin{3};
    evaluator=varargin{4};configuration=varargin{5};
else
    error('lmz:MultiStride:PeriodicConstructor', ...
        'Use configuration-only or explicit schema/evaluator construction.');
end
if ~isa(decision,'lmz.schema.VariableSchema')|| ...
        ~isa(parameters,'lmz.schema.VariableSchema')|| ...
        ~isa(evaluator,'function_handle')||~isstruct(configuration)
    error('lmz:MultiStride:PeriodicContract', ...
        'Periodic schemas, evaluator, or configuration are invalid.');
end
parameters.validateVector(defaults);
defaults=defaults(:);
end

function [contacts,closure]=validateEvaluation(value,count,configuration)
if ~isstruct(value)||~isfield(value,'ContactResiduals')|| ...
        ~isfield(value,'FinalClosureResidual')
    error('lmz:MultiStride:PeriodicEvaluation', ...
        'Evaluator must return ContactResiduals and FinalClosureResidual.');
end
rejectHiddenSolve(value);
contacts=normalizePerStride(value.ContactResiduals,count,configuration);
closure=realVector(value.FinalClosureResidual,'final closure');
end

function blocks=contactBlocks(contacts)
blocks=lmz.data.ResidualBlock.empty(0,1);
for stride=1:numel(contacts)
    name=sprintf('stride_%d_contact_constraints',stride);
    blocks(end+1,1)=lmz.data.ResidualBlock( ...
        name,contacts{stride},ones(numel(contacts{stride}),1)); %#ok<AGROW>
end
end

function values=normalizePerStride(source,count,configuration)
if iscell(source)
    values=source(:);
elseif isnumeric(source)&&ismatrix(source)&&size(source,2)==count&&count>1
    values=arrayfun(@(index)source(:,index),1:count,'UniformOutput',false).';
elseif isnumeric(source)&&isfield(configuration,'ContactResidualCounts')
    values=splitVector(source,configuration.ContactResidualCounts,count);
elseif isnumeric(source)&&count==1
    values={source(:)};
else
    error('lmz:MultiStride:PerStrideResiduals', ...
        'Contact residuals must identify every requested stride.');
end
if numel(values)~=count
    error('lmz:MultiStride:PerStrideResiduals', ...
        'Contact residual count does not match NumberOfStrides.');
end
for index=1:count
    values{index}=realVector(values{index},'contact residual');
end
end

function values=splitVector(source,counts,count)
counts=counts(:);
if numel(counts)~=count||any(counts<0)||any(counts~=fix(counts))|| ...
        sum(counts)~=numel(source)
    error('lmz:MultiStride:ContactResidualCounts', ...
        'ContactResidualCounts do not partition the contact residual vector.');
end
values=cell(count,1);offset=0;source=source(:);
for index=1:count
    values{index}=source(offset+(1:counts(index)));
    offset=offset+counts(index);
end
end

function rejectHiddenSolve(value)
if isfield(value,'Diagnostics')&&isstruct(value.Diagnostics)&& ...
        isfield(value.Diagnostics,'HiddenTimingSolve')&& ...
        logical(value.Diagnostics.HiddenTimingSolve)
    error('lmz:MultiStride:HiddenTimingSolve', ...
        'N-stride residual evaluation cannot launch a hidden timing solve.');
end
end

function validateTimingEvidence(mode,plan,configuration,count)
if strcmp(mode,'explicit_variables')
    return
end
evidence=isfield(configuration,'TimingDataPrecompleted')&& ...
    isequal(configuration.TimingDataPrecompleted,true);
if isa(plan,'lmz.multistride.StridePlan')
    evidence=plan.CompletedStrideCount==count&& ...
        plan.RequestedStrideCount==count;
end
if ~evidence
    error('lmz:MultiStride:TimingEvidence', ...
        ['fixed_precompleted timing mode requires a complete StridePlan ' ...
        'or TimingDataPrecompleted=true.']);
end
end

function value=timingMode(configuration)
value=char(fieldOr(configuration,'TimingMode','fixed_precompleted'));
if ~any(strcmp(value,{'explicit_variables','fixed_precompleted'}))
    error('lmz:MultiStride:TimingMode','Unsupported timing mode %s.',value);
end
end

function value=realVector(source,label)
if ~isnumeric(source)||~isreal(source)||~isvector(source)
    error('lmz:MultiStride:ResidualContract','%s must be a real vector.',label);
end
value=source(:);
end

function value=positiveInteger(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)|| ...
        value<1||value~=fix(value)
    error('lmz:MultiStride:PositiveInteger','%s must be a positive integer.',name);
end
end

function value=nonnegativeInteger(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)|| ...
        value<0||value~=fix(value)
    error('lmz:MultiStride:NonnegativeInteger', ...
        '%s must be a nonnegative integer.',name);
end
end

function value=requiredField(source,name)
if ~isfield(source,name)
    error('lmz:MultiStride:MissingConfiguration','Missing configuration %s.',name);
end
value=source.(name);
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name)
    value=source.(name);
else
    value=fallback;
end
end

function value=emptySchema()
value=lmz.schema.VariableSchema(lmz.schema.VariableSpec.empty(0,1),'1.0.0');
end
