function [result, report] = reproduceRun(source, options)
%REPRODUCERUN Reconstruct a recorded numerical or workflow run.
%   RESULT = lmz.services.reproduceRun(ARTIFACT) verifies versions and
%   recorded built-in hashes, reconstructs the original options and source
%   seed/pair, and executes the recorded public service again.
if nargin < 2
    options = struct();
end
if ischar(source) || (isstring(source) && isscalar(source))
    artifact = lmz.io.ArtifactStore.load(char(source));
elseif isstruct(source) && isscalar(source)
    artifact = source;
    lmz.io.ArtifactStore.validate(artifact);
else
    error('lmz:Reproduce:Source', ...
        'Source must be an artifact struct or artifact MAT path.');
end

required = {'frameworkVersion', 'options', 'randomSeed', ...
    'sourceDataHashes', 'artifactType'};
for index = 1:numel(required)
    if ~isfield(artifact, required{index})
        error('lmz:Reproduce:MissingMetadata', ...
            'Run artifact is missing %s.', required{index});
    end
end
if ~lmz.util.Version.isCompatible( ...
        lmz.util.Version.current(), artifact.frameworkVersion)
    error('lmz:Reproduce:FrameworkVersion', ...
        'Framework %s cannot reproduce artifact framework %s.', ...
        lmz.util.Version.current(), artifact.frameworkVersion);
end

if isfield(options, 'Registry') && ~isempty(options.Registry)
    registry = options.Registry;
else
    registry = lmz.registry.ModelRegistry.discover();
end
manifest = registry.getManifest(artifact.modelId);
if ~strcmp(manifest.version, artifact.modelVersion)
    error('lmz:Reproduce:ModelVersion', ...
        'Model version %s does not match artifact version %s.', ...
        manifest.version, artifact.modelVersion);
end
model = registry.createModel(artifact.modelId);
configuration = struct();
if isfield(artifact, 'problemMetadata') && ...
        isstruct(artifact.problemMetadata) && ...
        isfield(artifact.problemMetadata, 'configuration')
    configuration = artifact.problemMetadata.configuration;
end
if strcmp(artifact.artifactType,'n-stride-periodic-run')
    requireField(artifact,'stridePlan');
    configuration.StridePlan=lmz.multistride.StridePlan.fromStruct( ...
        artifact.stridePlan);
end
problem = [];
if any(strcmp(artifact.artifactType,{'multiple-shooting-run', ...
        'horizon-feasibility-run','horizon-continuation-run'}))
    requireField(artifact,'shootingHorizon');
    requireField(artifact,'shootingProblemContract');
    contract=artifact.shootingProblemContract;
    configuration=contract.Configuration;
    configuration.Horizon=lmz.shooting.ShootingHorizon.fromStruct( ...
        artifact.shootingHorizon);
    configuration.ShootingDecisionSchema= ...
        lmz.shooting.ShootingDecisionSchema.fromStruct( ...
        contract.DecisionSchema);
    problem=model.createProblem(artifact.problemId,configuration);
    reproducedContract=problem.contract();
    if ~strcmp(lmz.io.ArtifactStore.dataHash(reproducedContract), ...
            artifact.shootingProblemContractHash)
        error('lmz:Reproduce:ShootingProblemContract', ...
            ['Reconstructed shooting problem does not match the recorded ' ...
            'hash-bound problem contract.']);
    end
elseif strcmp(artifact.artifactType,'contact-timing-run')
    storedTiming=lmz.data.ContactTimingResult.fromStruct( ...
        artifact.contactTimingResult);
    configuration.InitialState=storedTiming.FixedInitialState;
    configuration.PhysicalParameters=storedTiming.FixedPhysicalParameters;
    configuration.EventSchedule=storedTiming.InputSchedule;
    configuration.StartSectionId=storedTiming.InputSchedule.StartSectionId;
    configuration.StopSectionId=storedTiming.InputSchedule.StopSectionId;
    timingFamily=fieldOr(configuration,'TimingFamily',false);
    gauges=fieldOr(configuration,'TimingGauges',{});
    base=model.createProblem(artifact.problemId,configuration);
    if timingFamily
        problem=lmz.schedule.TimingFamilyProblem(base, ...
            lmz.schedule.TimingGauge.arrayFrom(gauges),configuration);
    else
        problem=base;
    end
elseif strcmp(artifact.artifactType,'continuation-run')&& ...
        fieldOr(configuration,'TimingFamily',false)
    contract=fieldOr(artifact.runProvenance, ...
        'TimingFamilyProblemContract',struct());
    base=reconstructTimingFamilyBase(model,artifact.problemId, ...
        configuration,contract);
    problem=lmz.schedule.TimingFamilyProblem(base, ...
        lmz.schedule.TimingGauge.arrayFrom(fieldOr( ...
        configuration,'TimingGauges',{})),configuration);
elseif ~any(strcmp(artifact.artifactType, ...
        {'section-transfer-run','stride-plan-completion-run', ...
        'n-stride-simulation-run'}))
    problem = model.createProblem(artifact.problemId, configuration);
end
if ~isempty(problem)&&~strcmp(problem.Version, artifact.problemVersion)
    error('lmz:Reproduce:ProblemVersion', ...
        'Problem version %s does not match artifact version %s.', ...
        problem.Version, artifact.problemVersion);
end

hashChecks = verifyHashes(artifact.sourceDataHashes,artifact);
if isfield(options, 'Context') && ~isempty(options.Context)
    context = options.Context;
else
    context = lmz.api.RunContext.synchronous(artifact.randomSeed);
end
runOptions = artifact.options;
started = tic;
switch artifact.artifactType
    case 'solve-run'
        requireField(artifact, 'sourceSeed');
        seed = restoreSeed(artifact.sourceSeed);
        result = lmz.services.SolveService().solve( ...
            problem, seed, runOptions, context);
    case 'continuation-run'
        requireField(artifact, 'sourcePair');
        pair = restorePair(artifact.sourcePair);
        runOptions = clearCallbacks(runOptions);
        result = lmz.services.ContinuationService().run( ...
            problem, pair, runOptions, context);
    case 'optimization-run'
        requireField(artifact, 'sourceSeed');
        seed = restoreSeed(artifact.sourceSeed);
        result = lmz.services.OptimizationService().run( ...
            problem, seed, runOptions, context);
    case 'contact-timing-run'
        result=lmz.services.ContactTimingService().solve( ...
            problem,storedTiming.InputSchedule,runOptions,context);
    case 'section-transfer-run'
        requireField(artifact,'sourceSeed');
        sourceSolution=restoreSeed(artifact.sourceSeed);
        result=lmz.services.SectionTransferService().transfer( ...
            model,sourceSolution,artifact.targetSectionId,context);
    case {'stride-plan-completion-run','n-stride-simulation-run'}
        requireField(artifact,'request');
        request=lmz.multistride.MultiStrideRequest.fromStruct( ...
            artifact.request);
        result=lmz.services.MultiStrideSimulationService().simulate( ...
            model,request,context);
    case 'n-stride-periodic-run'
        requireField(artifact,'sourceSeed');
        seed=restoreSeed(artifact.sourceSeed);
        result=lmz.services.SolveService().solve( ...
            problem,seed,runOptions,context);
    case 'multiple-shooting-run'
        requireField(artifact,'sourceSeed');
        seed=restoreSeed(artifact.sourceSeed);
        result=lmz.services.MultipleShootingService().solve( ...
            problem,seed,runOptions,context);
    case 'horizon-feasibility-run'
        requireField(artifact,'sourceSeed');
        seed=restoreSeed(artifact.sourceSeed);
        parameters=artifact.parameterValues;
        if isa(seed,'lmz.data.Solution')
            parameters=seed.ParameterValues;
            seed=seed.DecisionValues;
        end
        result=lmz.services.FeasibilityAnalysisService().analyze( ...
            problem,seed,parameters, ...
            runOptions,context);
    case 'horizon-continuation-run'
        requireField(artifact,'horizonContinuation');
        protocol=artifact.horizonContinuation;
        result=lmz.services.HorizonContinuationService().run( ...
            model,artifact.problemId,protocol.Configurations, ...
            protocol.InitialSeed,protocol.Options,context);
        if ~strcmp(lmz.io.ArtifactStore.dataHash( ...
                result.Horizon.toStruct()),artifact.shootingHorizonHash)
            error('lmz:Reproduce:HorizonContinuationResult', ...
                ['Reproduced continuation ended on a different ' ...
                'hash-bound horizon.']);
        end
    otherwise
        error('lmz:Reproduce:ArtifactType', ...
            'Artifact type %s is not a reproducible run.', artifact.artifactType);
end

report = struct('ArtifactType', artifact.artifactType, ...
    'FrameworkVersionRecorded', artifact.frameworkVersion, ...
    'FrameworkVersionCurrent', lmz.util.Version.current(), ...
    'ModelVersion', artifact.modelVersion, ...
    'ProblemVersion', artifact.problemVersion, ...
    'RandomSeed', artifact.randomSeed, 'Options', runOptions, ...
    'SourceArtifactId', fieldOr(artifact, 'sourceArtifactId', ''), ...
    'HashChecks', hashChecks, ...
    'VerifiedHashCount', sum([hashChecks.Verified]), ...
    'UnresolvedHashCount', sum(~[hashChecks.Verified]), ...
    'ElapsedTime', toc(started), ...
    'NumericalEqualityPolicy', ...
    ['Options and lineage are reconstructed exactly; numerical results use ' ...
    'the model-specific solver/platform tolerances.']);
end

function seed = restoreSeed(value)
if isnumeric(value)
    seed = value(:);
elseif isstruct(value) && isscalar(value) && ...
        isfield(value, 'DecisionSchema') && isfield(value, 'DecisionValues')
    seed = lmz.data.Solution.fromStruct(value);
else
    error('lmz:Reproduce:SourceSeed', ...
        'Recorded source seed is missing or malformed.');
end
end

function pair = restorePair(value)
required = {'First', 'Second', 'RequestedRadius', ...
    'AchievedRadius', 'Diagnostics'};
for index = 1:numel(required)
    if ~isstruct(value) || ~isscalar(value) || ...
            ~isfield(value, required{index})
        error('lmz:Reproduce:SourcePair', ...
            'Recorded continuation seed pair is malformed.');
    end
end
first = lmz.data.Solution.fromStruct(value.First);
second = lmz.data.Solution.fromStruct(value.Second);
pair = lmz.data.SolutionPair(first, second, value.RequestedRadius, ...
    value.AchievedRadius, value.Diagnostics);
end

function options = clearCallbacks(options)
names = {'PredictionFcn', 'AcceptedFcn', 'RejectedFcn', 'AcceptanceFcn'};
for index = 1:numel(names)
    if isfield(options, names{index})
        options.(names{index}) = [];
    end
end
end

function checks = verifyHashes(values,artifact)
checks = struct('Name', {}, 'RelativePath', {}, 'Expected', {}, ...
    'Actual', {}, 'Verified', {}, 'Status', {});
names = fieldnames(values);
root = lmz.util.ProjectPaths.root();
for index = 1:numel(names)
    item = values.(names{index});
    record = struct('Name', names{index}, 'RelativePath', '', ...
        'Expected', '', 'Actual', '', 'Verified', false, ...
        'Status', 'digest-recorded-without-built-in-path');
    if isstruct(item) && isscalar(item)
        record.RelativePath = firstField(item, ...
            {'relativePath', 'RelativePath', 'path', 'Path'}, '');
        record.Expected = firstField(item, ...
            {'sha256', 'SHA256', 'hash', 'Hash'}, '');
    elseif ischar(item)
        record.Expected = item;
    end
    if strcmp(names{index},'ProblemConfiguration')
        record.Actual=configurationPayloadHash(artifact);
        if ~isempty(record.Actual)
            if ~strcmpi(record.Actual,record.Expected)|| ...
                    ~isfield(artifact,'problemConfigurationHash')|| ...
                    ~strcmpi(record.Actual, ...
                    artifact.problemConfigurationHash)
                error('lmz:Reproduce:SourceHashMismatch', ...
                    ['Recorded problem-configuration hash does not match ' ...
                    'its stored payload.']);
            end
            record.Verified=true;
            record.Status='verified-payload';
        end
    end
    if ~isempty(record.RelativePath)
        if isAbsolute(record.RelativePath) || ...
                any(strcmp(strsplit(strrep(record.RelativePath, '\', '/'), '/'), '..'))
            error('lmz:Reproduce:UnsafeHashPath', ...
                'Recorded source hash path is unsafe: %s', record.RelativePath);
        end
        path = fullfile(root, record.RelativePath);
        if exist(path, 'file') ~= 2
            error('lmz:Reproduce:MissingSourceData', ...
                'Recorded built-in source is unavailable: %s', ...
                record.RelativePath);
        end
        record.Actual = lmz.util.FileHash.sha256(path);
        if ~strcmpi(record.Actual, record.Expected)
            error('lmz:Reproduce:SourceHashMismatch', ...
                'Recorded source hash is stale for %s.', record.RelativePath);
        end
        record.Verified = true;
        record.Status = 'verified';
    end
    checks(end + 1) = record; %#ok<AGROW>
end
end

function value=configurationPayloadHash(artifact)
value='';configuration=[];
if isfield(artifact,'shootingProblemContract')&& ...
        isstruct(artifact.shootingProblemContract)&& ...
        isfield(artifact.shootingProblemContract,'Configuration')
    configuration=artifact.shootingProblemContract.Configuration;
elseif isfield(artifact,'problemMetadata')&& ...
        isstruct(artifact.problemMetadata)&& ...
        isfield(artifact.problemMetadata,'configuration')
    configuration=artifact.problemMetadata.configuration;
end
if ~isempty(configuration)
    value=lmz.io.ArtifactStore.dataHash(configuration);
end
end

function value = firstField(source, names, fallback)
value = fallback;
for index = 1:numel(names)
    if isfield(source, names{index})
        value = source.(names{index});
        return
    end
end
end

function tf = isAbsolute(path)
tf = ~isempty(path) && (path(1) == filesep || ...
    ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once')));
end

function requireField(value, name)
if ~isfield(value, name)
    error('lmz:Reproduce:MissingMetadata', ...
        'Run artifact is missing %s.', name);
end
end

function value = fieldOr(source, name, fallback)
if isstruct(source)&&isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end

function base=reconstructTimingFamilyBase(model,problemId,configuration,contract)
base=[];
required={'ProviderClass','FixedInitialState', ...
    'FixedPhysicalParameters','InputSchedule','BaseConfiguration'};
if isstruct(contract)&&isscalar(contract)&&all(isfield(contract,required))
    providerClass=contract.ProviderClass;
    trusted= ischar(providerClass)&&~isempty(regexp(providerClass, ...
        '^(lmzmodels|lmzexamples)(\.[A-Za-z][A-Za-z0-9_]*)+$','once'));
    if ~trusted
        error('lmz:Reproduce:TimingProviderClass', ...
            'Recorded timing provider is outside trusted namespaces.');
    end
    try
        provider=feval(providerClass);
        if ~isa(provider,'lmz.schedule.ContactConstraintProvider')
            error('lmz:Reproduce:TimingProviderType', ...
                'Recorded timing provider does not implement the contract.');
        end
        schedule=lmz.schedule.EventSchedule.fromStruct( ...
            contract.InputSchedule);
        base=lmz.schedule.SectionReturnTimingProblem(model,problemId, ...
            provider,contract.FixedInitialState, ...
            contract.FixedPhysicalParameters,schedule, ...
            contract.BaseConfiguration);
    catch exception
        if strcmp(providerClass,'lmzexamples.AffineTimingFamilyProvider')
            rethrow(exception);
        end
        base=[];
    end
end
if isempty(base)
    base=model.createProblem(problemId,configuration);
end
end
