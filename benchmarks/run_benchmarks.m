function report = run_benchmarks(options)
%RUN_BENCHMARKS Measure representative release-candidate workflows.
%   REPORT = RUN_BENCHMARKS() performs three warm-process repetitions.
%   REPORT = RUN_BENCHMARKS(OPTIONS) accepts Repetitions, GateOnly, and
%   OutputPath fields. MemoryBytes is a shallow returned-value estimate.

if nargin < 1
    options = struct();
end
repetitions = option(options, 'Repetitions', 3);
gateOnly = option(options, 'GateOnly', false);
if ~isscalar(repetitions) || repetitions < 1 || repetitions ~= fix(repetitions)
    error('lmz:Benchmarks:Repetitions', ...
        'Repetitions must be a positive integer.');
end

startup;
root = lmz.util.ProjectPaths.root();
registry = lmz.registry.ModelRegistry.discover();
context = lmz.api.RunContext.synchronous(7107);
branchService = lmz.services.BranchService();

quadrupedModel = registry.createModel('slip_quadruped');
quadrupedProblem = quadrupedModel.createProblem('periodic_apex', struct());
roadMap = lmzmodels.slip_quadruped.RoadMapCatalog.default();
quadrupedBranch = branchService.loadRoadMapBranch( ...
    quadrupedProblem, roadMap.defaultBranchPath());
quadrupedIndex = roadMap.recommendedSeedIndex(roadMap.defaultBranchPath());
quadrupedSeed = quadrupedBranch.point(quadrupedIndex);
quadrupedEvaluation = quadrupedProblem.evaluate( ...
    quadrupedSeed.DecisionValues, quadrupedSeed.ParameterValues, context, true);

bipedModel = registry.createModel('slip_biped');
bipedProblem = bipedModel.createProblem('periodic_apex', struct());
gaitMap = lmzmodels.slip_biped.GaitMapCatalog.default();
bipedBranch = gaitMap.loadBranch(gaitMap.defaultBranchPath(), bipedProblem, true);
bipedIndex = gaitMap.recommendedSeedIndex(gaitMap.defaultBranchPath());
bipedSeed = bipedBranch.point(bipedIndex);

loadModel = registry.createModel('slip_quad_load');
loadProblem = loadModel.createProblem('multi_stride_fit', ...
    struct('InitialPerturbation', 0));
loadSeed = loadProblem.makeSolution( ...
    loadProblem.getDecisionSchema().defaults(), ...
    loadProblem.getParameterSchema().defaults(), []);

definitions = { ...
    definition('startup_registry', @() startupRegistry(), ...
        'startup + built-in registry discovery', 10); ...
    definition('roadmap_one_branch', @() loadRoadMapOne(), ...
        'default quadruped RoadMap branch', 20); ...
    definition('roadmap_all_branches', @() loadRoadMapAll(), ...
        'all quadruped RoadMap branches', 60); ...
    definition('gaitmap_all_branches', @() loadGaitMapAll(), ...
        'all biped GaitMap branches', 60); ...
    definition('load_multi_stride_dataset', @() loadMultiStride(), ...
        'default load-pulling multi-stride dataset', 20); ...
    definition('evaluate_biped_scientific', @() evaluateBiped(), ...
        'recommended W1 biped point', 60); ...
    definition('evaluate_quadruped_scientific', @() evaluateQuadruped(), ...
        'recommended quadruped RoadMap point', 60); ...
    definition('evaluate_load_scientific', @() simulateLoad(), ...
        'default load-pulling multi-stride decision', 90); ...
    definition('render_100_frames', @() renderFrames(), ...
        'quadruped scientific simulation', 60); ...
    definition('short_biped_solve', @() solveBiped(), ...
        'recommended W1 biped seed', 120); ...
    definition('short_quadruped_continuation', @() continueQuadruped(), ...
        'three-point quadruped continuation', 180); ...
    definition('evaluate_load_objective', @() evaluateLoadObjective(), ...
        'default load-pulling objective', 90); ...
    definition('build_gui', @() buildGui(), ...
        'headless controller and all GUI components', 30); ...
    definition('artifact_save_load', @() artifactRoundTrip(), ...
        'recommended quadruped solution', 15)};

if gateOnly
    keep = {'startup_registry', 'roadmap_one_branch', ...
        'evaluate_biped_scientific', 'evaluate_quadruped_scientific', ...
        'evaluate_load_objective', 'build_gui', 'artifact_save_load'};
    definitions = definitions(cellfun(@(item) any(strcmp(item.Name, keep)), ...
        definitions));
end

records = repmat(emptyRecord(), numel(definitions), 1);
for index = 1:numel(definitions)
    item = definitions{index};
    samples = zeros(repetitions, 1);
    memory = zeros(repetitions, 1);
    for repeat = 1:repetitions
        started = tic;
        value = item.Function();
        samples(repeat) = toc(started);
        information = whos('value');
        memory(repeat) = information.bytes;
        clear value
    end
    records(index) = emptyRecord();
    records(index).Name = item.Name;
    records(index).MedianSeconds = median(samples);
    records(index).SpreadSeconds = median(abs(samples - median(samples)));
    records(index).MemoryBytes = median(memory);
    records(index).Samples = samples.';
    records(index).BudgetSeconds = item.BudgetSeconds;
    records(index).Fixture = item.Fixture;
    fprintf('LMZ_BENCHMARK name=%s median=%.6f spread=%.6f bytes=%d\n', ...
        item.Name, records(index).MedianSeconds, ...
        records(index).SpreadSeconds, round(records(index).MemoryBytes));
end

report = struct('schemaVersion', '1.0.0', ...
    'frameworkVersion', lmz.util.Version.current(), ...
    'matlabRelease', version('-release'), 'matlabVersion', version, ...
    'hardware', hardware(), 'repetitions', repetitions, ...
    'gateOnly', gateOnly, 'measuredAt', lmz.compat.Timestamp.current(), ...
    'records', records, 'notes', ...
    ['Warm-process timings; spread is median absolute deviation; ' ...
    'memory is the shallow size of the returned MATLAB value.']);

if isfield(options, 'OutputPath') && ~isempty(options.OutputPath)
    writeReport(options.OutputPath, report);
end
fprintf('LMZ_BENCHMARKS_OK records=%d release=%s\n', ...
    numel(records), report.matlabRelease);

    function value = startupRegistry()
        startup;
        value = lmz.registry.ModelRegistry.discover();
    end
    function value = loadRoadMapOne()
        value = branchService.loadRoadMapBranch( ...
            quadrupedProblem, roadMap.defaultBranchPath());
    end
    function value = loadRoadMapAll()
        value = branchService.loadAllRoadMapBranches(quadrupedProblem);
    end
    function value = loadGaitMapAll()
        value = branchService.loadAllGaitMapBranches(bipedProblem);
    end
    function value = loadMultiStride()
        catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
        value = catalog.load(catalog.Manifest.defaultMultiStride);
    end
    function value = evaluateBiped()
        value = bipedProblem.evaluate(bipedSeed.DecisionValues, ...
            bipedSeed.ParameterValues, context, true);
    end
    function value = evaluateQuadruped()
        value = quadrupedProblem.evaluate(quadrupedSeed.DecisionValues, ...
            quadrupedSeed.ParameterValues, context, true);
    end
    function value = simulateLoad()
        value = loadProblem.simulateDecision(loadSeed.DecisionValues, context);
    end
    function value = renderFrames()
        figureHandle = figure('Visible', 'off');
        cleanup = onCleanup(@() delete(figureHandle));
        renderer = lmzmodels.slip_quadruped.QuadrupedRenderer( ...
            axes('Parent', figureHandle), quadrupedEvaluation.Simulation);
        frameCount = numel(quadrupedEvaluation.Simulation.Time);
        for frame = 1:100
            renderer.updateFrame(1 + round((frame - 1) / 99 * (frameCount - 1)));
        end
        value = renderer.CurrentIndex;
        clear cleanup
    end
    function value = solveBiped()
        value = lmz.services.SolveService().solve( ...
            bipedProblem, bipedSeed, struct(), context);
    end
    function value = continueQuadruped()
        pair = lmz.services.SeedService().adjacentBranchPair( ...
            quadrupedProblem, quadrupedBranch, quadrupedIndex, 1, ...
            struct(), context);
        continuationOptions = struct('MaximumPoints', 3, ...
            'BothDirections', false, ...
            'InitialStep', pair.AchievedRadius, ...
            'MaximumStep', pair.AchievedRadius);
        value = lmz.services.ContinuationService().run( ...
            quadrupedProblem, pair, continuationOptions, context);
    end
    function value = evaluateLoadObjective()
        [objective, terms, diagnostics] = loadProblem.evaluateObjective( ...
            loadSeed.DecisionValues, loadSeed.ParameterValues, context);
        value = struct('Objective', objective, 'Terms', terms, ...
            'Diagnostics', diagnostics);
    end
    function value = buildGui()
        % Exercise the real figure, tab construction, subscriptions, and
        % initial refresh.  CreateFigure=false is intentionally reserved for
        % headless controller tests and is not a GUI-construction benchmark.
        application = lmz.gui.LeggedModelZooApp();
        cleanup = onCleanup(@() delete(application));
        if ~isempty(application.Figure) && isgraphics(application.Figure)
            application.Figure.Visible = 'off';
            drawnow;
        end
        value = application.Controller.modelIds();
        clear cleanup
    end
    function value = artifactRoundTrip()
        path = lmz.compat.Files.temporary(tempdir, '.mat');
        cleanup = onCleanup(@() deleteIfPresent(path));
        lmz.io.ArtifactStore.save(path, quadrupedSeed.toArtifact());
        value = lmz.io.ArtifactStore.load(path);
        clear cleanup
    end
end

function value = definition(name, functionHandle, fixture, budget)
value = struct('Name', name, 'Function', functionHandle, ...
    'Fixture', fixture, 'BudgetSeconds', budget);
end

function value = emptyRecord()
value = struct('Name', '', 'MedianSeconds', 0, 'SpreadSeconds', 0, ...
    'MemoryBytes', 0, 'Samples', [], 'BudgetSeconds', 0, 'Fixture', '');
end

function value = option(options, name, fallback)
if isfield(options, name)
    value = options.(name);
else
    value = fallback;
end
end

function value = hardware()
value = struct('architecture', computer('arch'), 'computer', computer, ...
    'operatingSystem', systemName(), 'logicalCores', logicalCores());
end

function value = systemName()
if ismac
    value = 'macOS';
elseif ispc
    value = 'Windows';
else
    value = 'Linux/Unix';
end
end

function value = logicalCores()
try
    value = feature('numcores');
catch
    value = NaN;
end
end

function writeReport(path, report)
path = lmz.compat.Text.character(path, 'benchmark output path');
[folder, ~, ~] = fileparts(path);
if isempty(folder)
    folder = pwd;
end
temporary = lmz.compat.Files.temporary(folder, '.json');
cleanup = onCleanup(@() deleteIfPresent(temporary));
file = fopen(temporary, 'w');
if file < 0
    error('lmz:Benchmarks:Output', 'Could not open benchmark output.');
end
fileCleanup = onCleanup(@() fclose(file));
fprintf(file, '%s\n', lmz.compat.Json.encode(report, true));
clear fileCleanup
lmz.compat.Files.atomicMove(temporary, path);
if exist(path, 'file') ~= 2
    error('lmz:Benchmarks:OutputFinalize', ...
        'Atomic benchmark report finalization produced no output.');
end
clear cleanup
if exist(path, 'file') ~= 2
    error('lmz:Benchmarks:OutputCleanup', ...
        'Benchmark report cleanup removed the finalized output.');
end
fprintf('LMZ_BENCHMARK_REPORT_OK path=%s\n', path);
end

function deleteIfPresent(path)
if exist(path, 'file') == 2
    delete(path);
end
end
