function [result, report] = reproduceRun(source, options)
%REPRODUCERUN Reconstruct a recorded solve, continuation, or optimization.
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
problem = model.createProblem(artifact.problemId, configuration);
if ~strcmp(problem.Version, artifact.problemVersion)
    error('lmz:Reproduce:ProblemVersion', ...
        'Problem version %s does not match artifact version %s.', ...
        problem.Version, artifact.problemVersion);
end

hashChecks = verifyHashes(artifact.sourceDataHashes);
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

function checks = verifyHashes(values)
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
if isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
