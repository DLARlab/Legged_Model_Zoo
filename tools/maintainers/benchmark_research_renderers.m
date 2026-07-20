function report=benchmark_research_renderers(options)
%BENCHMARK_RESEARCH_RENDERERS Measure source-style renderer lifecycle costs.
%   REPORT=BENCHMARK_RESEARCH_RENDERERS() constructs the three built-in
%   research renderers using repository-contained synthetic simulations.
%   It measures construction, persistent-handle frame updates, switching to
%   high contrast, frame capture, dense ground geometry, and quadruped phase
%   geometry. No external source checkout is read or placed on the path.
if nargin<1,options=struct();end
options=parseOptions(options);
definitions=modelDefinitions();
warmUp(definitions);
records=repmat(emptyRecord(),1,numel(definitions));
for index=1:numel(definitions)
    records(index)=measureRenderer(definitions(index),options);
end
ground=measureGround(options.Repetitions);
phase=measurePhase(options.Repetitions,options.UpdateCount);
report=struct('SchemaVersion','1.0.0', ...
    'RuntimeRelease',version('-release'),'Platform',computer, ...
    'Repetitions',options.Repetitions,'UpdateCount',options.UpdateCount, ...
    'CaptureFrames',options.CaptureFrames,'Records',records, ...
    'Ground',ground,'QuadrupedPhase',phase, ...
    'SourceRepositoryRuntimeDependency',false, ...
    'RuntimeRoots',{{'src','models','catalog'}});
if options.Verbose,printReport(report);end
end

function options=parseOptions(incoming)
defaults=struct('Repetitions',3,'UpdateCount',100, ...
    'CaptureFrames',true,'Verbose',true);
if ~isstruct(incoming)||~isscalar(incoming)
    error('lmz:GraphicsBenchmark:Options', ...
        'Benchmark options must be one scalar structure.');
end
names=fieldnames(incoming);
if ~all(ismember(names,fieldnames(defaults)))
    error('lmz:GraphicsBenchmark:Option', ...
        'Benchmark options contain an unknown field.');
end
options=defaults;
for index=1:numel(names),options.(names{index})=incoming.(names{index});end
integerNames={'Repetitions','UpdateCount'};
for index=1:numel(integerNames)
    name=integerNames{index};value=options.(name);
    if ~isnumeric(value)||~isscalar(value)||~isfinite(value)|| ...
            value<1||value~=fix(value)
        error('lmz:GraphicsBenchmark:Count', ...
            '%s must be a positive integer.',name);
    end
end
if options.Repetitions>10||options.UpdateCount>10000
    error('lmz:GraphicsBenchmark:Count', ...
        'Benchmark repetition and update counts exceed the safety limit.');
end
logicalNames={'CaptureFrames','Verbose'};
for index=1:numel(logicalNames)
    name=logicalNames{index};
    if ~islogical(options.(name))||~isscalar(options.(name))
        error('lmz:GraphicsBenchmark:Flag','%s must be logical.',name);
    end
end
end

function definitions=modelDefinitions()
models={'slip_quadruped','slip_biped','slip_quad_load'};
simulations={quadrupedSimulation(),bipedSimulation(),loadSimulation()};
definitions=repmat(struct('ModelId','','RendererClass','', ...
    'Simulation',[],'ResearchProfile',[],'HighContrastProfile',[]),1,3);
for index=1:numel(models)
    modelId=models{index};root=fullfile(lmz.util.ProjectPaths.catalog(),modelId);
    config=lmz.viz.GraphicsConfig.fromJson( ...
        fullfile(root,'graphics.lmz.json'),root, ...
        lmz.util.ProjectPaths.models(),'lmzmodels');
    research=config.getProfile('research_legacy');
    highContrast=config.getProfile('high_contrast');
    if ~strcmp(research.RendererClass,highContrast.RendererClass)|| ...
            isempty(strfind(research.RendererClass,'.ResearchRenderer'))
        error('lmz:GraphicsBenchmark:ProfileGeometry', ...
            'Research and high-contrast profiles must use one research renderer.');
    end
    definitions(index)=struct('ModelId',modelId, ...
        'RendererClass',research.RendererClass, ...
        'Simulation',simulations{index},'ResearchProfile',research, ...
        'HighContrastProfile',highContrast);
end
end

function warmUp(definitions)
for index=1:numel(definitions)
    definition=definitions(index);
    figureHandle=hiddenFigure();
    figureCleanup=onCleanup(@()closeFigure(figureHandle));
    axesHandle=axes('Parent',figureHandle);
    constructor=str2func(definition.RendererClass);
    renderer=constructor(axesHandle,definition.Simulation, ...
        definition.ResearchProfile,struct());
    rendererCleanup=onCleanup(@()deleteRenderer(renderer));
    renderer.updateFrame(renderer.frameCount());
    renderer.setProfile(definition.HighContrastProfile);
    clear rendererCleanup figureCleanup
end
lmzmodels.slip_quadruped.ResearchGroundGeometry.compute();
lmzmodels.slip_biped.ResearchGroundGeometry.compute();
lmzmodels.slip_quadruped.ResearchPhaseDiagramGeometry.compute(1,phaseSchedule());
end

function record=measureRenderer(definition,options)
repetitions=options.Repetitions;
construction=zeros(1,repetitions);updates=zeros(1,repetitions);
profileSwitch=zeros(1,repetitions);capture=nan(1,repetitions);
stable=true(1,repetitions);indexPreserved=true(1,repetitions);
researchClassRetained=true(1,repetitions);counts=zeros(1,repetitions);
switchCounts=zeros(1,repetitions);captureSize=[];
for repetition=1:repetitions
    figureHandle=hiddenFigure();
    figureCleanup=onCleanup(@()closeFigure(figureHandle));
    axesHandle=axes('Parent',figureHandle);
    constructor=str2func(definition.RendererClass);
    timer=tic;
    renderer=constructor(axesHandle,definition.Simulation, ...
        definition.ResearchProfile,struct());
    construction(repetition)=toc(timer);
    rendererCleanup=onCleanup(@()deleteRenderer(renderer));

    before=collectHandles(renderer.Handles);counts(repetition)=numel(before);
    frameCount=renderer.frameCount();lastIndex=1;timer=tic;
    for update=1:options.UpdateCount
        lastIndex=1+mod(update,frameCount);
        renderer.updateFrame(lastIndex);
    end
    updates(repetition)=toc(timer);
    after=collectHandles(renderer.Handles);
    stable(repetition)=sameHandles(before,after);

    timer=tic;renderer.setProfile(definition.HighContrastProfile);
    profileSwitch(repetition)=toc(timer);
    switched=collectHandles(renderer.Handles);
    switchCounts(repetition)=numel(switched);
    indexPreserved(repetition)=renderer.CurrentIndex==lastIndex;
    researchClassRetained(repetition)= ...
        isa(renderer,'lmz.viz.ResearchRenderer')&& ...
        strcmp(class(renderer),definition.RendererClass)&& ...
        strcmp(renderer.Profile.Id,'high_contrast');

    if options.CaptureFrames
        timer=tic;imageData=renderer.captureFrame();
        capture(repetition)=toc(timer);captureSize=size(imageData);
    end
    clear rendererCleanup figureCleanup
end
record=emptyRecord();record.ModelId=definition.ModelId;
record.RendererClass=definition.RendererClass;
record.ConstructionSeconds=median(construction);
record.Update100Seconds=median(updates);
record.SecondsPerUpdate=record.Update100Seconds/options.UpdateCount;
record.ProfileSwitchSeconds=median(profileSwitch);
record.CaptureFrameSeconds=median(capture);
record.HandleCount=counts(1);record.HandleCountAfterSwitch=switchCounts(1);
record.StableHandleIdentity=all(stable);
record.ProfileSwitchPreservedIndex=all(indexPreserved);
record.ProfileSwitchRetainedResearchClass=all(researchClassRetained);
record.CaptureSize=captureSize;
record.Samples=struct('ConstructionSeconds',construction, ...
    'UpdateSeconds',updates,'ProfileSwitchSeconds',profileSwitch, ...
    'CaptureFrameSeconds',capture,'HandleCounts',counts, ...
    'HandleCountsAfterSwitch',switchCounts);
end

function value=emptyRecord()
value=struct('ModelId','','RendererClass','', ...
    'ConstructionSeconds',0,'Update100Seconds',0,'SecondsPerUpdate',0, ...
    'ProfileSwitchSeconds',0,'CaptureFrameSeconds',0,'HandleCount',0, ...
    'HandleCountAfterSwitch',0,'StableHandleIdentity',false, ...
    'ProfileSwitchPreservedIndex',false, ...
    'ProfileSwitchRetainedResearchClass',false,'CaptureSize',[], ...
    'Samples',struct());
end

function value=measureGround(repetitions)
quadruped=zeros(1,repetitions);biped=zeros(1,repetitions);
quadrupedVertices=0;bipedVertices=0;
for repetition=1:repetitions
    timer=tic;quadrupedGeometry= ...
        lmzmodels.slip_quadruped.ResearchGroundGeometry.compute();
    quadruped(repetition)=toc(timer);
    timer=tic;bipedGeometry= ...
        lmzmodels.slip_biped.ResearchGroundGeometry.compute();
    biped(repetition)=toc(timer);
    quadrupedVertices=size(quadrupedGeometry.Hatch.Vertices,1);
    bipedVertices=size(bipedGeometry.Layers{2}.Vertices,1);
end
value=struct('QuadrupedSeconds',median(quadruped), ...
    'BipedSeconds',median(biped),'QuadrupedVertexCount',quadrupedVertices, ...
    'BipedVertexCount',bipedVertices, ...
    'QuadrupedSamples',quadruped,'BipedSamples',biped);
end

function value=measurePhase(repetitions,updateCount)
samples=zeros(1,repetitions);schedule=phaseSchedule();barCount=0;
for repetition=1:repetitions
    timer=tic;
    for update=1:updateCount
        phase=lmzmodels.slip_quadruped.ResearchPhaseDiagramGeometry. ...
            compute(1+update/1000,schedule);
    end
    samples(repetition)=toc(timer);barCount=numel(phase.Bars);
end
value=struct('UpdateCount',updateCount,'UpdateSeconds',median(samples), ...
    'SecondsPerUpdate',median(samples)/updateCount, ...
    'BarCount',barCount,'Samples',samples);
end

function value=phaseSchedule()
value=struct('tBL_TD',.1,'tBL_LO',.4,'tFL_TD',.2,'tFL_LO',.5, ...
    'tBR_TD',.6,'tBR_LO',.9,'tFR_TD',.7,'tFR_LO',.95,'tAPEX',1);
end

function handles=collectHandles(value)
handles={};
if isstruct(value)
    names=fieldnames(value);
    for element=1:numel(value)
        for index=1:numel(names)
            nested=collectHandles(value(element).(names{index}));
            handles=[handles nested]; %#ok<AGROW>
        end
    end
elseif iscell(value)
    for index=1:numel(value)
        nested=collectHandles(value{index});
        handles=[handles nested]; %#ok<AGROW>
    end
else
    for index=1:numel(value)
        try
            if isgraphics(value(index)),handles{end+1}=value(index);end %#ok<AGROW>
        catch
        end
    end
end
end

function result=sameHandles(first,second)
result=numel(first)==numel(second);
if ~result,return,end
for index=1:numel(first)
    if ~isgraphics(first{index})||~isgraphics(second{index})|| ...
            ~isequal(first{index},second{index})
        result=false;return
    end
end
end

function figureHandle=hiddenFigure()
figureHandle=figure('Visible','off','Color',[1 1 1], ...
    'Position',[20 20 640 480]);
end

function deleteRenderer(renderer)
try
    if ~isempty(renderer)&&isvalid(renderer),delete(renderer);end
catch
end
end

function closeFigure(figureHandle)
if ~isempty(figureHandle)&&isgraphics(figureHandle),delete(figureHandle);end
end

function simulation=quadrupedSimulation()
time=[0;.3;1];states=[ ...
    1 .8 1.2 0 .1 0 .2 0 -.15 0 .25 0 -.1 0; ...
    1.2 .8 1.2 0 .1 0 .2 0 -.15 0 .25 0 -.1 0; ...
    1.8 .8 1.2 0 .1 0 .2 0 -.15 0 .25 0 -.1 0];
modes=struct('back_left',[false;true;false], ...
    'front_left',[false;true;false],'back_right',false(3,1), ...
    'front_right',false(3,1),'period',1);
parameters=struct('k_leg',20,'k_swing',5,'J_pitch',.1, ...
    'l_leg',1,'phi_neutral',0,'l_b',.4,'k_r_leg',1);
records=quadrupedEventRecords();forces=zeros(3,12);
forces(:,5:8)=repmat([1 2 3 4],3,1);
forces(:,9:12)=repmat([10 20 30 40],3,1);
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_quadruped.PhysicalStateSchema.create(),states,modes, ...
    struct('stride_period',1),parameters,struct('benchmark',true), ...
    struct('kind','repository-contained-synthetic'), ...
    'EventRecords',records,'GroundReactionForces',forces);
end

function records=quadrupedEventRecords()
names={'BL_TD','BL_LO','FL_TD','FL_LO','BR_TD','BR_LO', ...
    'FR_TD','FR_LO','APEX'};
times=[.1 .4 .2 .5 .6 .9 .7 .95 1];
records=repmat(struct('Name','','Time',0),numel(names),1);
for index=1:numel(names)
    records(index).Name=names{index};records(index).Time=times(index);
end
end

function simulation=bipedSimulation()
time=[0;.3;1];states=[2 0 .9 0 .2 0 -.3 0; ...
    2.1 0 .92 0 .15 0 -.2 0;2.2 0 .95 0 .1 0 -.1 0];
modes=struct('left',[false;true;false],'right',[true;false;true], ...
    'period',1);names={'L_TD','L_LO','R_TD','R_LO','APEX'};
times=[.2 .6 .7 .1 1];records=repmat(struct('Name','','Time',0),5,1);
for index=1:5
    records(index).Name=names{index};records(index).Time=times(index);
end
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
    struct(),struct(),struct('benchmark',true), ...
    struct('kind','repository-contained-synthetic'),'EventRecords',records);
end

function simulation=loadSimulation()
time=[0;1.5;2.2;3.25];states=zeros(numel(time),18);
states(:,1)=[.5;.75;1;1.25];states(:,2)=.3;
states(:,3)=[1.1;1.15;1.2;1.25];states(:,5)=[.1;.15;.2;.25];
states(:,7)=[.05;.06;.07;.08];states(:,8)=[-.4;-.3;-.2;-.1];
states(:,9)=[-.08;-.07;-.06;-.05];states(:,10)=[.1;.2;.3;.4];
states(:,11)=[.11;.1;.09;.08];states(:,12)=[.5;.4;.3;.2];
states(:,13)=[-.12;-.11;-.1;-.09];states(:,14)=[-.2;-.1;0;.1];
states(:,15)=[-2;-1.8;-1.6;-1.4];states(:,17)=[.8;.75;.7;.65];
modes=struct('back_left',[false;true;true;false], ...
    'front_left',[false;false;true;false], ...
    'back_right',false(4,1),'front_right',false(4,1), ...
    'stride_index',[1;2;2;2]);
rows=[.1 .4 .5 .8 .2 .6 .7 1 1.5 8 20 4 1.1 0 .4 1 2.4; ...
    .2 .5 .6 .9 .3 .7 .8 1.1 1.75 8 21 4 1.2 0 .6 1 2.4];
quadruped=zeros(17,1);quadruped(11)=1.1;quadruped(13)=.4;
parameters=struct('stride_count',2,'per_stride_parameters',rows, ...
    'quadruped',quadruped,'load',zeros(4,1));
observables=struct('normalized_stride_time',time,'stride_count',2, ...
    'tugline_force',[.2;.45;.3;.1]);forces=zeros(numel(time),12);
interim=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_quad_load.PhysicalStateSchema.create(),states,modes, ...
    observables,parameters,struct('benchmark',true), ...
    struct('kind','repository-contained-synthetic'), ...
    'GroundReactionForces',forces);
kinematics=lmzmodels.slip_quad_load.KinematicsProvider.compute(interim);
simulation=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
    interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
    interim.Diagnostics,interim.Provenance,'GroundReactionForces',forces, ...
    'Kinematics',kinematics);
end

function printReport(report)
for index=1:numel(report.Records)
    record=report.Records(index);
    fprintf(['LMZ_RESEARCH_RENDERER_BENCHMARK model=%s construct=%.6f ' ...
        'update%d=%.6f per_frame=%.6f switch=%.6f capture=%.6f ' ...
        'handles=%d stable=%d\n'],record.ModelId, ...
        record.ConstructionSeconds,report.UpdateCount,record.Update100Seconds, ...
        record.SecondsPerUpdate,record.ProfileSwitchSeconds, ...
        record.CaptureFrameSeconds,record.HandleCount, ...
        record.StableHandleIdentity);
end
fprintf(['LMZ_RESEARCH_GEOMETRY_BENCHMARK quadruped_ground=%.6f ' ...
    'biped_ground=%.6f phase%d=%.6f\n'], ...
    report.Ground.QuadrupedSeconds,report.Ground.BipedSeconds, ...
    report.QuadrupedPhase.UpdateCount,report.QuadrupedPhase.UpdateSeconds);
fprintf('LMZ_RESEARCH_RENDERER_BENCHMARK_OK\n');
end
