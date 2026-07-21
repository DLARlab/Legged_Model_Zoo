classdef SeedService
    methods
        function [solution,diagnostics]=project(~,problem,solution,options,context)
            [u,diagnostics]=problem.projectSeed(solution.DecisionValues,solution.ParameterValues,options,context); solution=solution.withDecisionValues(u);
        end
        function solution=perturb(~,problem,solution,magnitude,mode,seed)
            stream=RandStream('mt19937ar','Seed',seed); noise=randn(stream,size(solution.DecisionValues));
            switch mode
                case 'absolute',delta=magnitude*noise;
                case 'relative',delta=magnitude*max(abs(solution.DecisionValues),eps).*noise;
                case 'schema-scaled',delta=magnitude*problem.scale(solution.DecisionValues).*noise;
                otherwise,error('lmz:Seed:NoiseMode','Unknown noise mode.');
            end
            solution=solution.withDecisionValues(problem.retract(solution.DecisionValues,delta));
        end
        function pair=makeSecondSeed(~,problem,first,radius,options,context)
            assertSectionConfigurationLocal(problem,first.Lineage);
            jacobian=problem.optionalJacobian(first.DecisionValues,first.ParameterValues,context);
            if isempty(jacobian),jacobian=finiteJacobian(problem,first.DecisionValues,first.ParameterValues,context);end
            [direction,rankValue,localDimension,rankTolerance]= ...
                continuationDirection(jacobian,options);
            metric=lmz.schema.DiagonalMetric(problem.scale(first.DecisionValues)); direction=direction/metric.norm(direction); prediction=problem.retract(first.DecisionValues,radius*direction);
            correctOptions=lmz.continuation.ContinuationOptions(struct('CorrectorTolerance',1e-10,'MaxCorrectorIterations',200));
            [u,exitFlag,output,residualNorm]=lmz.continuation.PseudoArclengthCorrector().correct(problem,prediction,direction,first.ParameterValues,correctOptions,context);
            evaluation=problem.evaluate(u,first.ParameterValues,context,false); second=problem.makeSolution(u,first.ParameterValues,evaluation); achieved=metric.norm(problem.difference(second.DecisionValues,first.DecisionValues));
            diagnostics=struct('ExitFlag',exitFlag,'Output',output, ...
                'ResidualNorm',residualNorm,'DistanceError',achieved-radius, ...
                'JacobianRank',rankValue,'LocalDimension',localDimension, ...
                'RankTolerance',rankTolerance);
            pair=lmz.data.SolutionPair(first,second,radius,achieved,diagnostics);
        end
        function pair=adjacentBranchPair(~,problem,branch,index,direction,options,context)
            if nargin<6||isempty(options),options=struct();end
            if nargin<7,context=lmz.api.RunContext.synchronous(0);end
            context.check(); n=branch.pointCount();
            if index<1||index>n||index~=fix(index)||n<2
                error('lmz:Seed:BranchIndex','Adjacent seed index is invalid.');
            end
            if ~(isscalar(direction)&&isfinite(direction)&&direction~=0)
                error('lmz:Seed:Direction','Adjacent seed direction must be nonzero.');
            end
            neighbor=index+sign(direction); inwardAdjusted=false;
            if neighbor<1||neighbor>n,neighbor=index-sign(direction);inwardAdjusted=true;end
            if neighbor<1||neighbor>n||neighbor==index
                error('lmz:Seed:NoNeighbor','No distinct inward neighbor is available.');
            end
            pair=lmz.services.SeedService().branchPair(problem,branch,index,neighbor,options,context);
            diagnostics=pair.Diagnostics;
            diagnostics.InwardAdjusted=inwardAdjusted;
            pair=lmz.data.SolutionPair(pair.First,pair.Second,pair.RequestedRadius, ...
                pair.AchievedRadius,diagnostics);
        end
        function pair=branchPair(~,problem,branch,firstIndex,secondIndex,options,context)
            if nargin<6||isempty(options),options=struct();end
            if nargin<7,context=lmz.api.RunContext.synchronous(0);end
            context.check();n=branch.pointCount();
            indices=[firstIndex secondIndex];
            if any(indices<1)||any(indices>n)||any(indices~=fix(indices))
                error('lmz:Seed:BranchIndex','Seed indices are invalid.');
            end
            if firstIndex==secondIndex
                error('lmz:Seed:DuplicateSeeds','Seed indices must be distinct.');
            end
            first=branch.point(firstIndex);second=branch.point(secondIndex);
            assertSectionConfigurationLocal(problem,branch.Lineage);
            if ~strcmp(first.ModelId,problem.getDescriptor().modelId)|| ...
                    ~strcmp(first.ProblemId,problem.Id)
                error('lmz:Seed:ProblemMismatch','Branch is incompatible with the problem.');
            end
            parameterTolerance=option(options,'ParameterTolerance',1e-10);
            if any(abs(first.ParameterValues-second.ParameterValues)> ...
                    parameterTolerance.*max(1,abs(first.ParameterValues)))
                error('lmz:Seed:ParameterMismatch','Adjacent seeds have incompatible parameters.');
            end
            delta=problem.difference(second.DecisionValues,first.DecisionValues);
            metric=lmz.schema.DiagonalMetric(problem.scale(first.DecisionValues));
            distance=metric.norm(delta);
            if ~isfinite(distance)||distance<=option(options,'MinimumSeparation',1e-10)
                error('lmz:Seed:DuplicateSeeds','Adjacent points are not chart-distinct.');
            end
            firstEvaluation=problem.evaluate(first.DecisionValues,first.ParameterValues,context,false);
            secondEvaluation=problem.evaluate(second.DecisionValues,second.ParameterValues,context,false);
            tolerance=option(options,'ResidualTolerance',1e-6);
            if max(firstEvaluation.ScaledResidualNorm,secondEvaluation.ScaledResidualNorm)>tolerance
                error('lmz:Seed:ResidualTooLarge','Adjacent seed residual exceeds tolerance.');
            end
            requireSameGait=option(options,'RequireSameGait',true);
            firstGait=gaitAbbreviation(first.Classification);
            secondGait=gaitAbbreviation(second.Classification);
            if requireSameGait&&~isempty(firstGait)&&~isempty(secondGait)&&~strcmp(firstGait,secondGait)
                error('lmz:Seed:GaitMismatch','Adjacent seeds cross the configured gait policy.');
            end
            diagnostics=struct('SourceBranchId',branch.Id,'SourceIndices',indices, ...
                'InwardAdjusted',false,'ResidualNorms', ...
                [firstEvaluation.ScaledResidualNorm secondEvaluation.ScaledResidualNorm], ...
                'Gaits',{{firstGait,secondGait}}, ...
                'ChartDistance',distance,'ParameterTolerance',parameterTolerance);
            pair=lmz.data.SolutionPair(first,second,distance,distance,diagnostics);
        end
    end

    methods (Static)
        function validateSectionConfiguration(problem,lineage)
            %VALIDATESECTIONCONFIGURATION Reject stale section-bound seeds.
            assertSectionConfigurationLocal(problem,lineage);
        end
    end
end

function value=option(options,name,fallback)
if isfield(options,name),value=options.(name);else,value=fallback;end
end

function value=gaitAbbreviation(classification)
value='';if isstruct(classification)&&isfield(classification,'Abbreviation'),value=classification.Abbreviation;end
end

function assertSectionConfigurationLocal(problem,lineage)
if ~isstruct(lineage)||~isscalar(lineage)|| ...
        (~isfield(lineage,'Configuration')&& ...
        ~isfield(lineage,'StartSectionHash'))
    return
end
descriptor=problem.getDescriptor();
if ~strcmp(problem.Id,'periodic_orbit')
    return
end
current=resolvedSectionIdentity(descriptor.modelId,problem.Id, ...
    descriptor.configuration);
if isfield(lineage,'Configuration')
    source=resolvedSectionIdentity(descriptor.modelId,problem.Id, ...
        lineage.Configuration);
    fields={'StartSectionId','StopSectionId','StartStateSide', ...
        'StopStateSide','CrossingDirection','MinimumReturnTime', ...
        'RequiredEventSequence','ReturnOccurrence','SymmetryId'};
    for index=1:numel(fields)
        if ~isequal(source.(fields{index}),current.(fields{index}))
            error('lmz:Seed:SectionConfigurationMismatch', ...
                ['The seed was created for a different Poincare section ' ...
                'configuration. Generate or transfer compatible seeds.']);
        end
    end
end
hashFields={'StartSectionHash','StopSectionHash','SectionCatalogHash'};
for index=1:numel(hashFields)
    name=hashFields{index};
    if isfield(lineage,name)&&~strcmp(lineage.(name),current.(name))
        error('lmz:Seed:SectionConfigurationMismatch', ...
            ['The seed Poincare descriptor or catalog hash is stale for ' ...
            'the selected problem configuration.']);
    end
end
end

function value=resolvedSectionIdentity(modelId,problemId,configuration)
if ~isstruct(configuration)||~isscalar(configuration)
    error('lmz:Seed:SectionConfiguration', ...
        'Poincare problem configuration must be a scalar struct.');
end
registry=lmz.registry.ModelRegistry.discover();
catalog=registry.getPoincareSectionRegistry(modelId);
defaultSection=catalog.defaultSection(problemId);
default=defaultSection.Descriptor;
startId=configurationField(configuration,'StartSectionId',default.Id);
stopId=configurationField(configuration,'StopSectionId',default.Id);
start=configuredDescriptor(catalog.descriptor(startId),configuration,'Start');
stop=configuredDescriptor(catalog.descriptor(stopId),configuration,'Stop');
symmetry=catalog.symmetryFor(stopId).Id;
if isfield(configuration,'SymmetryId')
    symmetry=configuration.SymmetryId;
end
value=struct('StartSectionId',start.Id,'StopSectionId',stop.Id, ...
    'StartStateSide',start.StateSide,'StopStateSide',stop.StateSide, ...
    'CrossingDirection',stop.CrossingDirection, ...
    'MinimumReturnTime',stop.MinimumReturnTime, ...
    'RequiredEventSequence',{stop.RequiredEventSequence}, ...
    'ReturnOccurrence',stop.ReturnOccurrence,'SymmetryId',symmetry, ...
    'StartSectionHash',start.fingerprint(), ...
    'StopSectionHash',stop.fingerprint(), ...
    'SectionCatalogHash',catalog.CatalogHash);
end

function descriptor=configuredDescriptor(descriptor,configuration,prefix)
value=descriptor.toStruct();
fields={'StateSide','CrossingDirection','MinimumReturnTime', ...
    'RequiredEventSequence','ReturnOccurrence'};
targets={'stateSide','crossingDirection','minimumReturnTime', ...
    'requiredEventSequence','returnOccurrence'};
for index=1:numel(fields)
    name=[prefix fields{index}];
    if isfield(configuration,name)
        value.(targets{index})=configuration.(name);
    elseif strcmp(prefix,'Stop')&&isfield(configuration,fields{index})
        value.(targets{index})=configuration.(fields{index});
    end
end
descriptor=lmz.poincare.PoincareSectionDescriptor(value);
end

function value=configurationField(configuration,name,fallback)
if isfield(configuration,name),value=configuration.(name);else,value=fallback;end
end

function jacobian=finiteJacobian(problem,u,p,context)
base=problem.residual(u,p,context);jacobian=zeros(numel(base),numel(u));
for index=1:numel(u),step=sqrt(eps)*max(1,abs(u(index)));candidate=u;candidate(index)=candidate(index)+step;jacobian(:,index)=(problem.residual(candidate,p,context)-base)/step;end
end

function [direction,rankValue,localDimension,tolerance]= ...
        continuationDirection(jacobian,options)
if ~isnumeric(jacobian)||~ismatrix(jacobian)||isempty(jacobian)|| ...
        any(~isfinite(jacobian(:)))
    error('lmz:Seed:Jacobian','The seed Jacobian must be a finite matrix.');
end
[~,singularValues,vectors]=svd(jacobian);
count=min(size(singularValues));
values=diag(singularValues(1:count,1:count));
values=values(:);
% These Jacobians may be supplied by finite differences of adaptive hybrid
% integrations.  A square-root-epsilon relative threshold distinguishes the
% continuation null direction from integration/finite-difference noise while
% remaining scale aware.
defaultTolerance=max(size(jacobian))*sqrt(eps)*max([values;1]);
tolerance=option(options,'RankTolerance',defaultTolerance);
if ~(isnumeric(tolerance)&&isscalar(tolerance)&&isfinite(tolerance)&& ...
        tolerance>=0)
    error('lmz:Seed:RankTolerance', ...
        'RankTolerance must be a finite nonnegative scalar.');
end
rankValue=sum(values>tolerance);
localDimension=size(jacobian,2)-rankValue;
expected=option(options,'ExpectedLocalDimension',1);
if ~(isnumeric(expected)&&isscalar(expected)&&isfinite(expected)&& ...
        expected>=1&&expected==fix(expected))
    error('lmz:Seed:ExpectedLocalDimension', ...
        'ExpectedLocalDimension must be a positive integer.');
end
if localDimension~=expected
    error('lmz:Seed:LocalDimension', ...
        ['Continuation requires unknown count minus Jacobian rank to equal ' ...
        '%d; the measured local dimension is %d (rank %d of %d).'], ...
        expected,localDimension,rankValue,size(jacobian,2));
end
nullBasis=vectors(:,rankValue+1:end);
direction=nullBasis(:,1);
firstNonzero=find(abs(direction)>max(tolerance,1e-12),1);
if isempty(firstNonzero)
    error('lmz:Seed:NullDirection','The continuation null direction is degenerate.');
end
if direction(firstNonzero)<0,direction=-direction;end
end
