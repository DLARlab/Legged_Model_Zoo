function report = run_standalone_all_scientific_models
%RUN_STANDALONE_ALL_SCIENTIFIC_MODELS Exercise repository-contained workflows.
% This entry point is intended to run from a clean MATLAB process after the
% repository has been copied beneath an otherwise empty temporary parent.

root = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
directoryCleanup = onCleanup(@()cd(originalDirectory));
cd(root);
startup;
assertRepositoryCodeIsLocal(root);

registry = lmz.registry.ModelRegistry.discover();
expectedIds = {'slip_biped','slip_quad_load','slip_quadruped'};
registryIds = registry.listModels();
assert(all(ismember(expectedIds,registryIds)), ...
    'lmz:Isolation:Models', 'The three scientific models were not discovered.');

context = lmz.api.RunContext.synchronous(906);
branchService = lmz.services.BranchService();

% Load, evaluate, simulate, solve, and continue the biped gait map.
bipedModel = registry.createModel('slip_biped');
bipedProblem = bipedModel.createProblem('periodic_apex',struct());
bipedBranch = branchService.loadBuiltInBranch(registry,'slip_biped');
bipedCatalog = lmzmodels.slip_biped.GaitMapCatalog.default();
bipedIndex = bipedCatalog.recommendedSeedIndex(bipedCatalog.defaultBranchPath());
bipedSeed = bipedBranch.point(bipedIndex);
bipedEvaluation = bipedProblem.evaluate(bipedSeed.DecisionValues, ...
    bipedSeed.ParameterValues,context,true);
assert(isa(bipedEvaluation.Simulation,'lmz.api.SimulationResult'), ...
    'lmz:Isolation:BipedSimulation', 'Biped scientific simulation failed.');
bipedSolve = lmz.services.SolveService().solve( ...
    bipedProblem,bipedSeed,struct(),context);
bipedPair = lmz.services.SeedService().adjacentBranchPair( ...
    bipedProblem,bipedBranch,bipedIndex,1,struct(),context);
bipedContinuation = lmz.services.ContinuationService().run( ...
    bipedProblem,bipedPair,continuationOptions(bipedPair),context);

% Load, evaluate, simulate, solve, and continue the quadruped RoadMap.
quadrupedModel = registry.createModel('slip_quadruped');
quadrupedProblem = quadrupedModel.createProblem('periodic_apex',struct());
quadrupedBranch = branchService.loadBuiltInBranch(registry,'slip_quadruped');
quadrupedCatalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
quadrupedIndex = quadrupedCatalog.recommendedSeedIndex( ...
    quadrupedCatalog.defaultBranchPath());
quadrupedSeed = quadrupedBranch.point(quadrupedIndex);
quadrupedEvaluation = quadrupedProblem.evaluate( ...
    quadrupedSeed.DecisionValues,quadrupedSeed.ParameterValues,context,true);
assert(isa(quadrupedEvaluation.Simulation,'lmz.api.SimulationResult'), ...
    'lmz:Isolation:QuadrupedSimulation', ...
    'Quadruped scientific simulation failed.');
quadrupedSolve = lmz.services.SolveService().solve( ...
    quadrupedProblem,quadrupedSeed,struct(),context);
quadrupedPair = lmz.services.SeedService().adjacentBranchPair( ...
    quadrupedProblem,quadrupedBranch,quadrupedIndex,1,struct(),context);
quadrupedContinuation = lmz.services.ContinuationService().run( ...
    quadrupedProblem,quadrupedPair,continuationOptions(quadrupedPair),context);

% Load and simulate a scientific load-pulling dataset, then invoke the
% bounded multi-stride optimization workflow.
loadModel = registry.createModel('slip_quad_load');
loadProblem = loadModel.createProblem('multi_stride_fit', ...
    struct('InitialPerturbation',0));
loadBranch = branchService.loadBuiltInBranch(registry,'slip_quad_load');
loadSeed = loadBranch.point(1);
loadSimulation = loadProblem.simulateDecision(loadSeed.DecisionValues,context);
assert(isa(loadSimulation,'lmz.api.SimulationResult'), ...
    'lmz:Isolation:LoadSimulation', ...
    'Load-pulling scientific simulation failed.');
optimizationOptions = struct('Algorithm','sqp','Display','off', ...
    'MaxIterations',1,'MaxFunctionEvaluations',20, ...
    'OptimalityTolerance',1e-3,'StepTolerance',1e-3, ...
    'ConstraintTolerance',1e-3);
loadOptimization = lmz.services.OptimizationService().run( ...
    loadProblem,loadSeed,optimizationOptions,context);
assert(isa(loadOptimization,'lmz.data.OptimizationResult'), ...
    'lmz:Isolation:LoadOptimization', ...
    'Load-pulling optimization did not return its public result type.');

% Resolve the public research profile contract and render one actual frame
% for every scientific model on hidden classic axes. Because this process
% runs beneath an otherwise empty parent, success also proves that no
% sibling legacy source repository is needed at run time.
researchGraphics = renderResearchGraphics(registry, ...
    {'slip_biped','slip_quadruped','slip_quad_load'}, ...
    {'periodic_apex','periodic_apex','multi_stride_fit'}, ...
    {bipedEvaluation.Simulation,quadrupedEvaluation.Simulation,loadSimulation});

% Build every GUI tab when graphics are available. The batch-safe fallback
% still constructs the complete controller when a display is unavailable.
[guiMode,guiApp] = constructGui();
guiCleanup = onCleanup(@()delete(guiApp));
assert(isequal(guiApp.Controller.modelIds(),registryIds), ...
    'lmz:Isolation:GUIModels', 'The GUI did not expose all registered models.');

artifactDirectory = tempname;
mkdir(artifactDirectory);
artifactCleanup = onCleanup(@()removeDirectory(artifactDirectory));
artifacts = {quadrupedBranch.toArtifact(),bipedSolve.Solution.toArtifact(), ...
    bipedContinuation.toArtifact(),loadOptimization.toArtifact()};
expectedTypes = {'branch','solution','continuation-run','optimization-run'};
for index = 1:numel(artifacts)
    artifactPath = fullfile(artifactDirectory,sprintf('artifact_%d.mat',index));
    lmz.io.ArtifactStore.save(artifactPath,artifacts{index});
    restored = lmz.io.ArtifactStore.load(artifactPath);
    assert(strcmp(restored.artifactType,expectedTypes{index}), ...
        'lmz:Isolation:ArtifactType', 'Artifact round-trip type mismatch.');
end

report = struct('Success',true,'Root',root,'ModelIds',{registryIds}, ...
    'BipedBranchPoints',bipedBranch.pointCount(), ...
    'QuadrupedBranchPoints',quadrupedBranch.pointCount(), ...
    'LoadBranchPoints',loadBranch.pointCount(), ...
    'BipedSolveExitFlag',bipedSolve.ExitFlag, ...
    'QuadrupedSolveExitFlag',quadrupedSolve.ExitFlag, ...
    'BipedContinuationPoints',bipedContinuation.Branch.pointCount(), ...
    'QuadrupedContinuationPoints',quadrupedContinuation.Branch.pointCount(), ...
    'LoadOptimizationExitFlag',loadOptimization.ExitFlag, ...
    'ResearchGraphics',researchGraphics, ...
    'GuiMode',guiMode,'ArtifactTypes',{expectedTypes});
fprintf('ISOLATED_RESEARCH_GRAPHICS_OK %s\n', ...
    strjoin({researchGraphics.ModelId},','));
fprintf('ISOLATED_ALL_SCIENTIFIC_MODELS_OK\n');

clear artifactCleanup guiCleanup directoryCleanup
end

function evidence = renderResearchGraphics(registry,modelIds,problemIds,simulations)
factory = lmz.viz.RendererFactory(registry);
empty = struct('ModelId','','ProblemId','','ProfileId','', ...
    'RendererClass','','AxesClass','','FrameIndex',0, ...
    'FrameImageSize',zeros(1,3),'FrameChecksum',0,'GraphicsHandleCount',0);
evidence = repmat(empty,1,numel(modelIds));
for index = 1:numel(modelIds)
    figureHandle = figure('Visible','off','Color','white', ...
        'Position',[100 100 640 420]);
    figureCleanup = onCleanup(@()deleteFigure(figureHandle));
    axesHandle = axes('Parent',figureHandle, ...
        'Position',[0.05 0.08 0.9 0.86]);
    assert(isa(axesHandle,'matlab.graphics.axis.Axes'), ...
        'lmz:Isolation:ResearchAxes', ...
        'Research graphics verification requires classic MATLAB axes.');
    [renderer,profile] = factory.createRenderer(axesHandle, ...
        simulations{index},modelIds{index},problemIds{index}, ...
        'research_legacy',struct());
    rendererCleanup = onCleanup(@()deleteRenderer(renderer));
    assert(isa(renderer,'lmz.viz.ResearchRenderer'), ...
        'lmz:Isolation:ResearchRenderer', ...
        'The research_legacy profile did not construct a research renderer.');
    assert(strcmp(profile.Id,'research_legacy'), ...
        'lmz:Isolation:ResearchProfile', ...
        'The renderer factory did not resolve the requested research profile.');
    frameIndex = max(1,round(renderer.frameCount()/2));
    renderer.updateFrame(frameIndex);
    frame = renderer.captureFrame();
    assert(~isempty(frame)&&isnumeric(frame)&&all(isfinite(double(frame(:)))), ...
        'lmz:Isolation:ResearchFrame', ...
        'The research renderer did not produce a finite image frame.');
    dimensions = size(frame);dimensions(end+1:3) = 1;
    handleCount = numel(findall(axesHandle));
    assert(handleCount>1, ...
        'lmz:Isolation:ResearchHandles', ...
        'The research renderer did not create graphics primitives.');
    evidence(index) = struct('ModelId',modelIds{index}, ...
        'ProblemId',problemIds{index},'ProfileId',profile.Id, ...
        'RendererClass',class(renderer),'AxesClass',class(axesHandle), ...
        'FrameIndex',frameIndex,'FrameImageSize',dimensions(1:3), ...
        'FrameChecksum',sum(double(frame(:))), ...
        'GraphicsHandleCount',handleCount);
    clear rendererCleanup figureCleanup
end
end

function options = continuationOptions(pair)
options = struct('MaximumPoints',3,'BothDirections',false, ...
    'InitialStep',pair.AchievedRadius,'MaximumStep',pair.AchievedRadius);
end

function assertRepositoryCodeIsLocal(root)
implementations = {which('lmz.registry.ModelRegistry'), ...
    which('lmzmodels.slip_biped.Model'), ...
    which('lmzmodels.slip_quad_load.Model'), ...
    which('lmzmodels.slip_quadruped.Model'), ...
    which('lmzmodels.tutorial_hopper.Model')};
canonicalRoot = canonicalPath(root);
for index = 1:numel(implementations)
    implementation = canonicalPath(implementations{index});
    assert(pathStartsWith(implementation,canonicalRoot), ...
        'lmz:Isolation:ExternalImplementation', ...
        'A model implementation resolved outside the isolated repository.');
end
parent = fileparts(canonicalRoot);
entries = dir(parent);
names = {entries([entries.isdir]).name};
names = names(~ismember(names,{'.','..'}));
assert(isscalar(names) && strcmp(names{1},fileName(canonicalRoot)), ...
    'lmz:Isolation:NonemptyParent', ...
    'The isolated repository parent contains another directory.');
end

function [mode,app] = constructGui
try
    app = lmz.gui.LeggedModelZooApp();
    drawnow;
    mode = 'complete-figure';
catch exception
    if ~isDisplayUnavailable(exception)
        rethrow(exception);
    end
    app = lmz.gui.LeggedModelZooApp('CreateFigure',false);
    mode = 'headless-controller';
end
end

function value = isDisplayUnavailable(exception)
message = lower(exception.message);
identifiers = {'display','window system','graphics','jvm','uifigure'};
value = false;
for index = 1:numel(identifiers)
    if ~isempty(strfind(message,identifiers{index}))
        value = true;
        return
    end
end
end

function value = canonicalPath(value)
[ok,attributes] = fileattrib(value);
assert(ok,'lmz:Isolation:MissingPath','Required path is missing: %s',value);
value = attributes.Name;
end

function value = pathStartsWith(candidate,root)
separator = filesep;
value = strcmp(candidate,root) || ...
    (numel(candidate)>numel(root) && ...
    strncmp(candidate,[root separator],numel(root)+1));
end

function value = fileName(path)
[~,value,extension] = fileparts(path);
value = [value extension];
end

function removeDirectory(path)
if exist(path,'dir')==7
    rmdir(path,'s');
end
end

function deleteRenderer(renderer)
try
    if ~isempty(renderer)&&isvalid(renderer),delete(renderer);end
catch
end
end

function deleteFigure(figureHandle)
try
    if ~isempty(figureHandle)&&isgraphics(figureHandle)
        delete(figureHandle);
    end
catch
end
end
