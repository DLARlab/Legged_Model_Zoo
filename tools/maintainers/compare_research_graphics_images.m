function report=compare_research_graphics_images(modelId,sourceRoot,outputPath)
%COMPARE_RESEARCH_GRAPHICS_IMAGES Compare pinned source and LMZ batch renders.
%   This maintainer-only gate executes one immutable source checkout per
%   MATLAB process.  It commits numeric metrics and metadata, never source
%   or difference rasters.  Invoke the function once for each model ID.
root=lmz.util.ProjectPaths.root();
if nargin<1||isempty(modelId)
    error('lmz:GraphicsImageAudit:Model', ...
        'Supply slip_quadruped, slip_biped, or slip_quad_load.');
end
if nargin<2,sourceRoot='';end
modelId=char(modelId);[sourceRoot,commit]=sourceInformation( ...
    root,modelId,nargin>=2&&~isempty(sourceRoot),sourceRoot);
verifySource(sourceRoot,commit);
if nargin<3||isempty(outputPath)
    folder=fullfile(root,'docs','graphics-comparison',modelId);
    outputPath=fullfile(folder,'batch_metrics_r2025b_macos_arm64.json');
end
folder=fileparts(outputPath);if exist(folder,'dir')~=7,mkdir(folder);end
temporaryFolder=tempname;mkdir(temporaryFolder);
temporaryCleanup=onCleanup(@()removeFolder(temporaryFolder));
visibility=get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
visibilityCleanup=onCleanup(@()set(groot,'DefaultFigureVisible',visibility));

lmzRegressions=struct();
switch modelId
    case 'slip_quadruped'
        [frames,lmzRegressions]=compareQuadruped(sourceRoot,temporaryFolder);
    case 'slip_biped'
        frames=compareBiped(sourceRoot,temporaryFolder);
    case 'slip_quad_load'
        frames=compareLoad(sourceRoot,temporaryFolder);
    otherwise
        error('lmz:GraphicsImageAudit:Model','Unsupported model ID: %s',modelId);
end
summary=summarize(frames);
report=struct('schemaVersion','1.0.0','modelId',modelId, ...
    'sourceCommit',commit,'matlabRelease',version('-release'), ...
    'platform',computer,'graphicsEnvironment',graphicsEnvironment(), ...
    'frameSize',[640 480],'dataContract',dataContract(modelId), ...
    'canonicalCaseLabels',{{frames.caseLabel}}, ...
    'frames',frames,'lmzRegressions',lmzRegressions,'summary',summary, ...
    'thresholds',struct('normalizedRMSEMaximum',.35, ...
    'edgeMapOverlapMinimum',.60, ...
    'foregroundBoundingBoxAgreementMinimum',.84, ...
    'colorClusterAgreementMinimum',.65), ...
    'sourceImagesStored',false,'differenceImagesStored',false, ...
    'humanApproved',false,'qualification',[ ...
    'Source and LMZ were rendered headlessly at matched axes/camera. ' ...
    'Target explicit black defaults and requested camera corrections are ' ...
    'retained. No raster is redistributed; geometry tests remain primary.']);
report.passed=all([frames.passed])&&regressionsPassed(lmzRegressions);
writeReport(outputPath,report);
fprintf(['LMZ_GRAPHICS_IMAGE_COMPARE_OK model=%s frames=%d pass=%d ' ...
    'nrmse_max=%.6f edge_min=%.6f bbox_min=%.6f color_min=%.6f\n'], ...
    modelId,numel(frames),report.passed,summary.normalizedRMSEMaximum, ...
    summary.edgeMapOverlapMinimum, ...
    summary.foregroundBoundingBoxAgreementMinimum, ...
    summary.colorClusterAgreementMinimum);
clear visibilityCleanup temporaryCleanup
end

function [frames,regression]=compareQuadruped(sourceRoot,folder)
graphicsRoot=fullfile(sourceRoot,'SLIP_Quadruped','2_Graphic_ToolBox', ...
    'SLIP_Quadrupedal_Graphics','GraphicFunctions');
addpath(graphicsRoot);pathCleanup=onCleanup(@()rmpath(graphicsRoot));
[simulation,cases,parameters]=quadrupedSimulation();
[sourceFigure,sourceAxes]=fixedAxes();
sourceCleanup=onCleanup(@()deleteIfValid(sourceFigure));
sourceRenderer=SLIP_Animation_Quad(parameters,[50 40 540 400], ...
    sourceAxes,struct('AnimationMode','Detailed'));
set(sourceAxes,'Units','pixels','Position',[50 40 540 400]);
axis(sourceAxes,'equal');
[targetFigure,targetAxes]=fixedAxes();
targetCleanup=onCleanup(@()deleteIfValid(targetFigure));
profile=graphicsProfile('slip_quadruped','research_legacy');
targetRenderer=lmzmodels.slip_quadruped.ResearchRenderer( ...
    targetAxes,simulation,profile,struct('ShowForces',false, ...
    'DetailedOverlay',true,'CameraFollow',true));
rendererCleanup=onCleanup(@()delete(targetRenderer));
frames=repmat(emptyFrame(),1,numel(simulation.Time));
for index=1:numel(simulation.Time)
    sourceRenderer=sourceRenderer.update(simulation.Time(index), ...
        simulation.States(index,:).',parameters,false);
    daspect(sourceAxes,[1 1 1]);
    xlim(sourceAxes,simulation.States(index,1)+[-1.5 1.5]);
    ylim(sourceAxes,[-.1 2]);targetRenderer.updateFrame(index);
    geometry=lmzmodels.slip_quadruped.ResearchLegGeometry. ...
        frame(simulation,index);
    if ~isequal(geometry.Contact,cases(index).Metadata.expectedContacts)
        error('lmz:GraphicsImageAudit:QuadrupedContact', ...
            'Canonical quadruped contact metadata is inconsistent.');
    end
    frames(index)=compareAxes(sourceAxes,targetAxes,folder,index, ...
        simulation.Time(index),simulation.States(index,:),parameters.', ...
        cases(index));
end
regression=struct('forceVectorsOffOn',quadrupedForceRegression( ...
    targetRenderer,targetAxes,folder,3,cases(3).Label));
clear rendererCleanup targetCleanup sourceCleanup pathCleanup
end

function frames=compareBiped(sourceRoot,folder)
entries=bipedComparisonEntries();
graphicsRoot=fullfile(sourceRoot,'Stored_Functions','Graphics');
addpath(graphicsRoot);pathCleanup=onCleanup(@()rmpath(graphicsRoot));
sourceRenderer=SLIP_Model_Graphics_PointFeet_BipedalDemo(1280,900);
sourceFigure=sourceRenderer.fig;set(sourceFigure,'Visible','off', ...
    'Position',[10 10 640 480]);
sourceCleanup=onCleanup(@()deleteIfValid(sourceFigure));
sourceAxes=findobj(sourceFigure,'Type','axes');
set(sourceAxes,'Units','pixels','Position',[50 40 540 400]);
[targetFigure,targetAxes]=fixedAxes();
targetCleanup=onCleanup(@()deleteIfValid(targetFigure));
profile=graphicsProfile('slip_biped','research_legacy');
targetRenderer=lmzmodels.slip_biped.ResearchRenderer( ...
    targetAxes,[],profile,struct('CameraFollow',true));
rendererCleanup=onCleanup(@()delete(targetRenderer));
frames=repmat(emptyFrame(),1,numel(entries));currentKey='';
for index=1:numel(entries)
    entry=entries(index);simulation=entry.Simulation;
    if ~strcmp(currentKey,entry.SimulationKey)
        targetRenderer.initialize(simulation);currentKey=entry.SimulationKey;
    end
    frameIndex=entry.FrameIndex;time=simulation.Time(frameIndex);
    state=simulation.States(frameIndex,:);
    sourceRenderer=sourceRenderer.update(state.',entry.Events,time);
    set(sourceFigure,'Visible','off','Position',[10 10 640 480]);
    set(sourceAxes,'Units','pixels','Position',[50 40 540 400]);
    daspect(sourceAxes,[1 1 1]);
    xlim(sourceAxes,state(1)+[-1.5 1.5]);
    ylim(sourceAxes,[-.3 2]);
    targetRenderer.updateFrame(frameIndex);
    frames(index)=compareAxes(sourceAxes,targetAxes,folder,index, ...
        time,state,entry.Events,entry.Case);
end
clear rendererCleanup targetCleanup sourceCleanup pathCleanup
end

function frames=compareLoad(sourceRoot,folder)
graphicsRoot=fullfile(sourceRoot,'Stored_Functions','Graphics');
addpath(graphicsRoot);pathCleanup=onCleanup(@()rmpath(graphicsRoot));
[simulation,cases]=loadSimulation();
rows=simulation.Parameters.per_stride_parameters;
[sourceFigure,sourceAxes]=fixedAxes();
active=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
    select(rows,simulation.Time(1));
sourceRenderer=SLIP_Animation_Quad_Load(simulation.States, ...
    active.GlobalRow,[50 40 540 400],sourceAxes,struct());
set(sourceAxes,'Units','pixels','Position',[50 40 540 400]);
sourceCleanup=onCleanup(@()deleteIfValid(sourceFigure));
[targetFigure,targetAxes]=fixedAxes();
targetCleanup=onCleanup(@()deleteIfValid(targetFigure));
profile=graphicsProfile('slip_quad_load','research_legacy');
targetRenderer=lmzmodels.slip_quad_load.ResearchRenderer( ...
    targetAxes,simulation,profile,struct());
rendererCleanup=onCleanup(@()delete(targetRenderer));
frames=repmat(emptyFrame(),1,numel(simulation.Time));
for index=1:numel(simulation.Time)
    active=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
        select(rows,simulation.Time(index));
    if active.StrideIndex~=cases(index).Metadata.expectedStrideIndex
        error('lmz:GraphicsImageAudit:LoadStride', ...
            'Canonical load stride metadata is inconsistent.');
    end
    sourceRenderer=sourceRenderer.update(simulation.Time(index), ...
        simulation.States(index,:).',active.GlobalRow);
    set(sourceFigure,'Visible','off');
    set(sourceAxes,'Units','pixels','Position',[50 40 540 400]);
    targetRenderer.updateFrame(index);
    if targetRenderer.ActiveStrideIndex~=active.StrideIndex
        error('lmz:GraphicsImageAudit:LoadRendererStride', ...
            'Load renderer selected an unexpected stride row.');
    end
    frames(index)=compareAxes(sourceAxes,targetAxes,folder,index, ...
        simulation.Time(index),simulation.States(index,:),active.GlobalRow, ...
        cases(index));
end
clear rendererCleanup targetCleanup sourceCleanup pathCleanup
end

function frame=compareAxes(sourceAxes,targetAxes,folder,index,time,state,parameters,caseInfo)
sourcePath=fullfile(folder,sprintf('source_%02d.png',index));
targetPath=fullfile(folder,sprintf('target_%02d.png',index));
lmz.compat.Graphics.exportAxes(sourceAxes,sourcePath,120);
lmz.compat.Graphics.exportAxes(targetAxes,targetPath,120);
sourceImage=imread(sourcePath);targetImage=imread(targetPath);
sourceSize=size(sourceImage);targetSize=size(targetImage);
[sourceImage,targetImage]=matchedCanvas(sourceImage,targetImage);
metrics=lmz.viz.ImageMetrics.compare(sourceImage,targetImage);
metrics.StructuralSimilarity=finiteOrEmpty(metrics.StructuralSimilarity);
passed=metrics.NormalizedRMSE<=.35&&metrics.EdgeMapOverlap>=.60&& ...
    metrics.ForegroundBoundingBoxAgreement>=.84&& ...
    metrics.ColorClusterAgreement>=.65;
frame=struct('index',index,'caseLabel',caseInfo.Label, ...
    'caseMetadata',caseInfo.Metadata,'time',time, ...
    'state',reshape(state,1,[]),'parameters',reshape(parameters,1,[]), ...
    'sourceImageSize',sourceSize,'targetImageSize',targetSize, ...
    'metrics',metrics,'reviewOutcome','batch_metrics_pass','passed',passed);
end

function [first,second]=matchedCanvas(first,second)
if size(first,3)~=size(second,3)
    first=first(:,:,1:min(3,size(first,3)));
    second=second(:,:,1:min(3,size(second,3)));
end
rows=max(size(first,1),size(second,1));
columns=max(size(first,2),size(second,2));channels=max(size(first,3),size(second,3));
firstCanvas=cast(255*ones(rows,columns,channels),'like',first);
secondCanvas=cast(255*ones(rows,columns,channels),'like',second);
firstCanvas(1:size(first,1),1:size(first,2),1:size(first,3))=first;
secondCanvas(1:size(second,1),1:size(second,2),1:size(second,3))=second;
first=firstCanvas;second=secondCanvas;
end

function value=finiteOrEmpty(value)
if ~isfinite(value),value=[];end
end

function value=emptyFrame()
value=struct('index',0,'caseLabel','','caseMetadata',struct(), ...
    'time',0,'state',[],'parameters',[], ...
    'sourceImageSize',[],'targetImageSize',[], ...
    'metrics',struct(),'reviewOutcome','','passed',false);
end

function result=regressionsPassed(value)
result=true;
if isempty(fieldnames(value)),return,end
names=fieldnames(value);
for index=1:numel(names)
    item=value.(names{index});
    result=result&&isstruct(item)&&isscalar(item)&& ...
        isfield(item,'passed')&&item.passed;
end
end

function value=quadrupedForceRegression(renderer,axesHandle,folder,frameIndex,referenceLabel)
restoreCleanup=onCleanup(@()disableForces(renderer));
renderer.setOptions(struct('ShowForces',false),false);
renderer.updateFrame(frameIndex);
offPath=fullfile(folder,'lmz_force_off.png');
lmz.compat.Graphics.exportAxes(axesHandle,offPath,120);
offImage=imread(offPath);offStats=quadrupedForceStats(axesHandle);
renderer.setOptions(struct('ShowForces',true),false);
renderer.updateFrame(frameIndex);
onPath=fullfile(folder,'lmz_force_on.png');
lmz.compat.Graphics.exportAxes(axesHandle,onPath,120);
onImage=imread(onPath);onStats=quadrupedForceStats(axesHandle);
[offImage,onImage]=matchedCanvas(offImage,onImage);
metrics=lmz.viz.ImageMetrics.compare(offImage,onImage);
metrics.StructuralSimilarity=finiteOrEmpty(metrics.StructuralSimilarity);
offEvidence=struct('showForces',false, ...
    'visibleHandleCount',offStats.visibleHandleCount, ...
    'nonzeroVectorCount',offStats.nonzeroVectorCount, ...
    'imageSize',size(offImage),'imageChecksum',sum(double(offImage(:))));
onEvidence=struct('showForces',true, ...
    'visibleHandleCount',onStats.visibleHandleCount, ...
    'nonzeroVectorCount',onStats.nonzeroVectorCount, ...
    'imageSize',size(onImage),'imageChecksum',sum(double(onImage(:))));
passed=offStats.totalHandleCount==4&&onStats.totalHandleCount==4&& ...
    offStats.visibleHandleCount==0&&offStats.nonzeroVectorCount==0&& ...
    onStats.visibleHandleCount==4&&onStats.nonzeroVectorCount>=2&& ...
    metrics.NormalizedRMSE>0&& ...
    offEvidence.imageChecksum~=onEvidence.imageChecksum;
value=struct('caseLabel','force_vectors_off_on', ...
    'referenceCaseLabel',referenceLabel, ...
    'sourceRendererHasForceLayer',false,'forceOff',offEvidence, ...
    'forceOn',onEvidence,'differenceMetrics',metrics, ...
    'rastersStored',false,'passed',passed);
clear restoreCleanup
end

function value=quadrupedForceStats(axesHandle)
codes={'bl','fl','br','fr'};total=0;visible=0;nonzero=0;
for index=1:numel(codes)
    handle=findobj(axesHandle,'Tag',['lmz.quadruped.force.' codes{index}]);
    if isempty(handle),continue,end
    handle=handle(1);total=total+1;
    isVisible=strcmp(get(handle,'Visible'),'on');visible=visible+isVisible;
    horizontal=get(handle,'UData');vertical=get(handle,'VData');
    hasVector=any(abs(horizontal(:))>eps)||any(abs(vertical(:))>eps);
    nonzero=nonzero+(isVisible&&hasVector);
end
value=struct('totalHandleCount',total,'visibleHandleCount',visible, ...
    'nonzeroVectorCount',nonzero);
end

function disableForces(renderer)
try
    if ~isempty(renderer)&&isvalid(renderer)
        renderer.setOptions(struct('ShowForces',false),false);
    end
catch
end
end

function value=dataContract(modelId)
switch modelId
    case 'slip_quadruped'
        stateNames={'x','dx','y','dy','phi','dphi','alphaBL','dalphaBL', ...
            'alphaFL','dalphaFL','alphaBR','dalphaBR','alphaFR','dalphaFR'};
        parameterNames={'BL_TD','BL_LO','FL_TD','FL_LO','BR_TD','BR_LO', ...
            'FR_TD','FR_LO','tAPEX','k','ks','J','l_rest','osa','lb','kr'};
    case 'slip_biped'
        stateNames={'x','dx','y','dy','alphaL','dalphaL','alphaR','dalphaR'};
        parameterNames={'L_TD','L_LO','R_TD','R_LO','tAPEX'};
    case 'slip_quad_load'
        stateNames={'quad_x','quad_dx','quad_y','quad_dy','quad_phi', ...
            'quad_dphi','alphaBL','dalphaBL','alphaFL','dalphaFL', ...
            'alphaBR','dalphaBR','alphaFR','dalphaFR','load_x', ...
            'load_dx','load_y','load_dy'};
        parameterNames=arrayfun(@(index)sprintf('source_P_%02d',index), ...
            1:17,'UniformOutput',false);
    otherwise
        stateNames={};parameterNames={};
end
value=struct('stateNames',{stateNames},'parameterNames',{parameterNames});
end

function value=summarize(frames)
metrics=[frames.metrics];value=struct( ...
    'normalizedRMSEMaximum',max([metrics.NormalizedRMSE]), ...
    'edgeMapOverlapMinimum',min([metrics.EdgeMapOverlap]), ...
    'foregroundBoundingBoxAgreementMinimum', ...
    min([metrics.ForegroundBoundingBoxAgreement]), ...
    'colorClusterAgreementMinimum',min([metrics.ColorClusterAgreement]));
end

function [figureHandle,axesHandle]=fixedAxes()
figureHandle=figure('Visible','off','Color','white', ...
    'Position',[10 10 640 480]);
axesHandle=axes('Parent',figureHandle,'Units','pixels', ...
    'Position',[50 40 540 400]);
end

function profile=graphicsProfile(modelId,profileId)
root=fullfile(lmz.util.ProjectPaths.catalog(),modelId);
config=lmz.viz.GraphicsConfig.fromJson(fullfile(root,'graphics.lmz.json'), ...
    root,lmz.util.ProjectPaths.models(),'lmzmodels');
profile=config.getProfile(profileId);
end

function [simulation,cases,sourceParameters]=quadrupedSimulation()
time=[0;.15;.3;.65;.8];
states=[ ...
    1.00 .8 1.20 0  0.00 0  .20 0 -.15 0  .25 0 -.10 0; ...
    1.12 .8 1.16 0  0.04 0  .18 0 -.12 0  .22 0 -.08 0; ...
    1.24 .8 1.18 0 -0.06 0  .16 0 -.10 0  .20 0 -.06 0; ...
    1.52 .8 1.25 0  0.22 0  .28 0 -.20 0  .30 0 -.18 0; ...
    1.64 .8 1.20 0  0.10 0  .24 0 -.16 0  .26 0 -.12 0];
contacts=[false false false false;true false false false; ...
    true true false false;false false true false; ...
    false false true true];
modes=struct('back_left',contacts(:,1),'front_left',contacts(:,2), ...
    'back_right',contacts(:,3),'front_right',contacts(:,4),'period',1);
parameters=struct('k_leg',20,'k_swing',5,'J_pitch',.1, ...
    'l_leg',1,'phi_neutral',0,'l_b',.35,'k_r_leg',1);
eventNames={'BL_TD','BL_LO','FL_TD','FL_LO','BR_TD','BR_LO', ...
    'FR_TD','FR_LO','APEX'};
eventTimes=[.1 .4 .2 .5 .6 .9 .7 .95 1];
records=eventRecords(eventNames,eventTimes,14);
forces=zeros(numel(time),12);
forces(3,5)=4;forces(3,9)=24;
forces(3,6)=-3;forces(3,10)=20;
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_quadruped.PhysicalStateSchema.create(),states,modes, ...
    struct('stride_period',1),parameters,struct(),struct(), ...
    'EventRecords',records,'GroundReactionForces',forces);
sourceParameters=[eventTimes 20 5 .1 1 0 .35 1].';
cases(1)=canonicalCase('flight_apex',quadrupedCaseMetadata( ...
    {'flight','apex'},contacts(1,:),'asymmetric_l_b_0_35',true, ...
    'Start-of-stride apex convention; every leg is at resting length.'));
cases(2)=canonicalCase('one_leg_stance',quadrupedCaseMetadata( ...
    {'one_leg_stance'},contacts(2,:),'asymmetric_l_b_0_35',true, ...
    'Back-left stance exercises one compressed compound leg.'));
cases(3)=canonicalCase('two_leg_stance',quadrupedCaseMetadata( ...
    {'two_leg_stance','force_reference'},contacts(3,:), ...
    'asymmetric_l_b_0_35',true, ...
    'Back-left and front-left stance; force toggle reference frame.'));
cases(4)=canonicalCase('asymmetric_body_morphology', ...
    quadrupedCaseMetadata({'asymmetric_body_morphology'},contacts(4,:), ...
    'pitched_body_l_b_0_35',true, ...
    'Noncentral body attachment and pitch expose COM offset behavior.'));
cases(5)=canonicalCase('detailed_phase_overlay',quadrupedCaseMetadata( ...
    {'detailed_phase_overlay'},contacts(5,:), ...
    'asymmetric_l_b_0_35',true, ...
    'Title, LH/LF/RF/RH labels, box, and stance/flight bars are visible.'));
end

function metadata=quadrupedCaseMetadata(tags,contacts,morphology,overlay,note)
metadata=struct('coverageTags',{reshape(tags,1,[])}, ...
    'expectedContacts',reshape(logical(contacts),1,[]), ...
    'expectedContactCount',sum(contacts), ...
    'morphology',morphology,'detailedOverlay',logical(overlay), ...
    'note',note);
end

function entries=bipedComparisonEntries()
[simulation,events]=bipedContactSimulation();
indices=[3 4 2 1];
labels={'flight','left_stance','right_stance', ...
    'double_stance_wrapped_contact'};
tags={{'flight'},{'left_stance'},{'right_stance'}, ...
    {'double_stance','wrapped_contact'}};
firstEntry=bipedEntry('synthetic_contacts',simulation,indices(1),events, ...
    canonicalCase(labels{1},bipedCaseMetadata(tags{1},[false false], ...
    'none',indices(1),false, ...
    'Pinned source renderer strict event-contact logic.')));
entries=repmat(firstEntry,1,7);entries(1)=firstEntry;
expected={[true false],[false true],[true true]};
for index=2:4
    entries(index)=bipedEntry('synthetic_contacts',simulation, ...
        indices(index),events,canonicalCase(labels{index}, ...
        bipedCaseMetadata(tags{index},expected{index-1},'none', ...
        indices(index),index==4, ...
        'Pinned source renderer strict event-contact logic.')));
end

registry=lmz.registry.ModelRegistry.discover();
registryCleanup=onCleanup(@()delete(registry));
model=registry.createModel('slip_biped');
problem=model.createProblem('periodic_apex',struct());
catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
files={'W1.mat','R1.mat','HP1.mat'};
gaits={'walking','running','hopping'};
caseLabels={'walk_representative','run_representative','hop_representative'};
for index=1:numel(files)
    branch=catalog.loadBranch(files{index},problem,true);
    pointIndex=catalog.recommendedSeedIndex(files{index});
    fullSimulation=lmz.services.SolutionService().simulate(problem, ...
        branch.point(pointIndex),lmz.api.RunContext.synchronous(710+index));
    [~,frameIndex]=min(abs(fullSimulation.Time-0.5*fullSimulation.Time(end)));
    gaitEvents=bipedEventVector(fullSimulation);
    legFrame=lmzmodels.slip_biped.ResearchLegGeometry.frame( ...
        fullSimulation.States(frameIndex,:),gaitEvents, ...
        fullSimulation.Time(frameIndex));
    expectedContacts=[legFrame.Contact.left legFrame.Contact.right];
    single=singleBipedFrame(fullSimulation,frameIndex,expectedContacts);
    support=sprintf(['Main.m Section 2 %s example, %s index %d; ' ...
        'rendered by ShowTrajectory_BipedalDemo.'], ...
        gaits{index},files{index},pointIndex);
    metadata=bipedCaseMetadata( ...
        {'gait_representative',gaits{index}},expectedContacts, ...
        gaits{index},frameIndex, ...
        gaitEvents(1)>gaitEvents(2)||gaitEvents(3)>gaitEvents(4),support);
    entries(4+index)=bipedEntry(gaits{index},single,1,gaitEvents, ...
        canonicalCase(caseLabels{index},metadata));
end
clear registryCleanup
end

function [simulation,events]=bipedContactSimulation()
time=[.15;.3;.65;.8];
states=[2.00 0 .90 0 .20 0 -.30 0; ...
    2.08 0 .92 0 .17 0 -.25 0; ...
    2.18 0 .96 0 .12 0 -.18 0; ...
    2.28 0 .94 0 .10 0 -.14 0];
events=[.75 .25 .1 .6 1];
contacts=[true true;false true;false false;true false];
modes=struct('left',contacts(:,1),'right',contacts(:,2),'period',1);
records=eventRecords({'L_TD','L_LO','R_TD','R_LO','APEX'},events,8);
interim=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
    struct(),struct(),struct(),struct(),'EventRecords',records);
kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(interim);
simulation=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
    interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
    interim.Diagnostics,interim.Provenance,'EventRecords', ...
    interim.EventRecords,'Kinematics',kinematics);
end

function entry=bipedEntry(key,simulation,frameIndex,events,caseInfo)
entry=struct('SimulationKey',key,'Simulation',simulation, ...
    'FrameIndex',frameIndex,'Events',reshape(events,1,[]),'Case',caseInfo);
end

function metadata=bipedCaseMetadata(tags,contacts,gaitLabel,frameIndex,wrapped,note)
metadata=struct('coverageTags',{reshape(tags,1,[])}, ...
    'expectedContacts',reshape(logical(contacts),1,[]), ...
    'expectedContactCount',sum(contacts),'gaitLabel',gaitLabel, ...
    'simulationFrameIndex',frameIndex,'wrappedContact',logical(wrapped), ...
    'sourceSupport',note);
end

function events=bipedEventVector(simulation)
[events,available]=lmzmodels.slip_biped.ResearchLegGeometry. ...
    scheduleFromSimulation(simulation);
if ~available
    error('lmz:GraphicsImageAudit:BipedEvents', ...
        'Representative biped simulation has no complete event schedule.');
end
events=reshape(events,1,[]);
end

function simulation=singleBipedFrame(source,index,contacts)
modes=struct('left',logical(contacts(1)), ...
    'right',logical(contacts(2)),'period',source.Time(end));
interim=lmz.api.SimulationResult(source.Time(index),source.StateSchema, ...
    source.States(index,:),modes,struct(),struct(),struct(),struct(), ...
    'EventRecords',source.EventRecords);
kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(interim);
simulation=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
    interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
    interim.Diagnostics,interim.Provenance,'EventRecords', ...
    interim.EventRecords,'Kinematics',kinematics);
end

function [simulation,cases]=loadSimulation()
fixtureRoot=fullfile(lmz.util.ProjectPaths.tests(),'fixtures','graphics', ...
    'slip_quad_load');
fixture=lmz.io.SafeJson.read(fullfile(fixtureRoot,'source_geometry.json'), ...
    'Root',fixtureRoot);rows=fixture.parameterRows;
time=[.3;.7;1.499;1.5;1.501;2.2];states=zeros(numel(time),18);
states(:,1)=[.50;.60;.75;.751;.752;1.10];states(:,2)=.3;
states(:,3)=[1.10;1.15;1.17;1.17;1.17;1.22];
states(:,5)=[.10;.05;.14;.14;.14;.20];
states(:,7)=[.05;.03;.06;.06;.06;.08];
states(:,8)=[-.4;-.2;-.3;-.3;-.3;-.1];
states(:,9)=[-.08;-.04;-.07;-.07;-.07;-.05];
states(:,10)=[.1;.15;.2;.2;.2;.4];
states(:,11)=[.11;.05;.10;.10;.10;.09];
states(:,12)=[.5;.2;.4;.4;.4;.2];
states(:,13)=[-.12;-.06;-.11;-.11;-.11;-.09];
states(:,14)=[-.2;-.1;-.1;-.1;-.1;.1];
states(:,15)=[-2.0;.30;-1.65;-1.66;-1.67;-2.40];
states(:,17)=[.80;1.05;.74;.74;.74;.65];
modes=loadContactModes(rows,time);parameters=struct('stride_count',2, ...
    'per_stride_parameters',rows,'quadruped',zeros(17,1),'load',zeros(4,1));
tuglineForce=[.5;.02;.8;.9;1;1.8];
interim=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_quad_load.PhysicalStateSchema.create(),states,modes, ...
    struct('normalized_stride_time',time,'stride_count',2, ...
    'tugline_force',tuglineForce),parameters,struct(),struct(), ...
    'GroundReactionForces',zeros(numel(time),12));
kinematics=lmzmodels.slip_quad_load.KinematicsProvider.compute(interim);
simulation=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
    interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
    interim.Diagnostics,interim.Provenance,'GroundReactionForces', ...
    interim.GroundReactionForces,'Kinematics',kinematics);
labels={'single_stride_stance','rope_slack_low_force', ...
    'stride_boundary_before','stride_boundary_exact', ...
    'stride_boundary_after','rope_loaded'};
relations={'none','none','before','exact','after','none'};
conditions={'baseline','slack_low_force','transition','transition', ...
    'transition','loaded'};
tags={{'single_stride_stance'},{'rope_slack','low_force'}, ...
    {'stride_boundary','before'},{'stride_boundary','exact'}, ...
    {'stride_boundary','after'},{'rope_loaded'}};
for index=1:numel(time)
    active=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
        select(rows,time(index));
    contacts=[modes.back_left(index) modes.front_left(index) ...
        modes.back_right(index) modes.front_right(index)];
    ropeLength=hypot(states(index,1)-states(index,15), ...
        states(index,3)-states(index,17));
    metadata=struct('coverageTags',{reshape(tags{index},1,[])}, ...
        'expectedContacts',logical(contacts), ...
        'expectedStrideIndex',active.StrideIndex, ...
        'boundaryRelation',relations{index}, ...
        'ropeCondition',conditions{index}, ...
        'tuglineForce',tuglineForce(index),'ropeLength',ropeLength, ...
        'simulationFrameIndex',index);
    cases(index)=canonicalCase(labels{index},metadata); %#ok<AGROW>
end
end

function modes=loadContactModes(rows,time)
names={'back_left','front_left','back_right','front_right'};
columns=[1 2;3 4;5 6;7 8];modes=struct();
for leg=1:4,modes.(names{leg})=false(numel(time),1);end
modes.stride_index=zeros(numel(time),1);
for index=1:numel(time)
    active=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
        select(rows,time(index));events=active.GlobalRow;
    for leg=1:4
        touchdown=events(columns(leg,1));liftoff=events(columns(leg,2));
        modes.(names{leg})(index)=time(index)>touchdown&&time(index)<liftoff;
    end
    modes.stride_index(index)=active.StrideIndex;
end
end

function value=canonicalCase(label,metadata)
value=struct('Label',label,'Metadata',metadata);
end

function records=eventRecords(names,times,stateCount)
records=repmat(struct('Name','','Time',0,'State',zeros(1,stateCount), ...
    'PreState',zeros(1,stateCount),'PostState',zeros(1,stateCount)), ...
    numel(names),1);
for index=1:numel(names)
    records(index).Name=names{index};records(index).Time=times(index);
end
end

function [root,commit]=sourceInformation(projectRoot,modelId,hasRoot,root)
switch modelId
    case 'slip_quadruped'
        fallback=fullfile(fileparts(projectRoot),'SLIP_Model_Zoo');
        commit='2c106101383ecee1b2a9d695efe09fbd72d5718a';
    case 'slip_biped'
        fallback=fullfile(fileparts(projectRoot), ...
            '2022_A_Template_Model_Explains_Jerboa_Gait_Transitions');
        commit='4595146c5881a5313bc8fe92de85099193ef9be9';
    case 'slip_quad_load'
        fallback=fullfile(fileparts(projectRoot), ...
            '2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights');
        commit='19f3133073c988cc0c3424a647b4adbb60a90b99';
    otherwise
        error('lmz:GraphicsImageAudit:Model','Unsupported model ID: %s',modelId);
end
if ~hasRoot,root=fallback;end
end

function verifySource(root,expected)
if exist(root,'dir')~=7
    error('lmz:GraphicsImageAudit:Source','Missing source checkout: %s',root);
end
[status,head]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0||~strcmp(strtrim(head),expected)
    error('lmz:GraphicsImageAudit:Commit','Source commit mismatch.');
end
[status,worktree]=system(sprintf('git -C "%s" status --porcelain',root));
if status~=0||~isempty(strtrim(worktree))
    error('lmz:GraphicsImageAudit:DirtySource','Source checkout must be clean.');
end
end

function value=graphicsEnvironment()
figureHandle=[];
try
    if exist('rendererinfo','file')==0
        error('lmz:GraphicsImageAudit:RendererInfo','rendererinfo unavailable.');
    end
    figureHandle=figure('Visible','off');axesHandle=axes('Parent',figureHandle);
    information=rendererinfo(axesHandle);
    value=struct('renderer',information.GraphicsRenderer, ...
        'vendor',information.Vendor,'version',information.Version, ...
        'device',information.RendererDevice);
catch
    value=struct('renderer','unavailable','vendor','unavailable', ...
        'version','unavailable','device','unavailable');
end
deleteIfValid(figureHandle);
end

function writeReport(path,value)
temporary=lmz.compat.Files.temporary(fileparts(path),'.json');
cleanup=onCleanup(@()deleteIfPresent(temporary));
file=fopen(temporary,'w');
if file<0,error('lmz:GraphicsImageAudit:Write','Cannot write metric report.');end
fileCleanup=onCleanup(@()fclose(file));
text=lmz.compat.Json.encode(value,true);count=fwrite(file,text,'char');
if count~=numel(text)
    error('lmz:GraphicsImageAudit:Write','Incomplete metric report write.');
end
clear fileCleanup;lmz.compat.Files.atomicMove(temporary,path);clear cleanup
end

function deleteIfPresent(path)
if exist(path,'file')==2,delete(path);end
end

function deleteIfValid(value)
if ~isempty(value)&&isgraphics(value),delete(value);end
end

function removeFolder(folder)
if exist(folder,'dir')==7,rmdir(folder,'s');end
end
