function fixture=capture_quadruped_graphics_baselines(sourceRoot,outputPath)
%CAPTURE_QUADRUPED_GRAPHICS_BASELINES Capture pinned source numeric geometry.
root=lmz.util.ProjectPaths.root();
if nargin<1||isempty(sourceRoot)
    sourceRoot=fullfile(fileparts(root),'SLIP_Model_Zoo');
end
if nargin<2||isempty(outputPath)
    outputPath=fullfile(root,'tests','fixtures','graphics', ...
        'slip_quadruped','source_capture.json');
end
commit='2c106101383ecee1b2a9d695efe09fbd72d5718a';
verifySource(sourceRoot,commit);
graphicsRoot=fullfile(sourceRoot,'SLIP_Quadruped','2_Graphic_ToolBox', ...
    'SLIP_Quadrupedal_Graphics','GraphicFunctions');
addpath(graphicsRoot);pathCleanup=onCleanup(@()rmpath(graphicsRoot));

state=zeros(14,1);state([1 3 5 7 9 11 13])=[1 1.2 .1 .2 -.15 .25 -.1];
parameters=zeros(16,1);parameters(1:9)=[.1 .4 .2 .5 .6 .9 .7 .95 1];
parameters(13)=1;parameters(15)=.4;
[lengths,angles,bodyPose,backHip,frontHip]= ...
    ComputeJoint_LegLA(.3,state,parameters);
[outlineX,outlineY,bodyFaces,bodyVertices]= ...
    ComputeBodyGraphics(bodyPose,parameters(15));
hips=[backHip frontHip backHip frontHip];legs=cell(1,4);
codes={'BL','FL','BR','FR'};
for index=1:4
    [vertices,faces]=ComputeLegGraphics(hips(:,index),lengths.(codes{index}), ...
        parameters(13),angles.(codes{index}));
    legs{index}=struct('vertices',vertices,'faces',faces);
end
[phaseBox,phaseText,phaseBars]=ComputePhaseDiagram(state(1),parameters);
ground=struct('vertexCount',20002,'faceCount',5001, ...
    'fieldX',[-15 100 100 -15],'fieldY',[0 0 -20 -20], ...
    'hatchXLimits',[-50.1 200.01],'h',.01,'n',5000,'s',.05, ...
    'w',.01,'extension',.1);
fixture=struct('schemaVersion','1.0.0','sourceRepository','SLIP_Model_Zoo', ...
    'sourceCommit',commit,'canonicalTime',.3,'state',state, ...
    'parameters',parameters,'joint',struct('lengths',lengths, ...
    'angles',angles,'bodyPose',bodyPose,'backHip',backHip,'frontHip',frontHip), ...
    'body',struct('outlineX',outlineX,'outlineY',outlineY, ...
    'faces',bodyFaces,'vertices',bodyVertices),'legs',{legs}, ...
    'phase',struct('box',phaseBox,'text',phaseText,'bars',phaseBars), ...
    'ground',ground,'camera',struct('xLimits',state(1)+[-1.5 1.5], ...
    'yLimits',[-.1 2]),'style',struct('springColor',[245 131 58]/256, ...
    'springWidth',5,'targetHatchColor',[0 0 0], ...
    'sourceHatchColorPolicy','unspecified_patch_default', ...
    'outlineColor',[0 0 0]));
writeFixture(outputPath,fixture);clear pathCleanup
fprintf('LMZ_QUADRUPED_GRAPHICS_BASELINE_OK path=%s\n',outputPath);
end

function verifySource(root,expected)
if exist(root,'dir')~=7,error('lmz:GraphicsCapture:Source','Missing source: %s',root);end
[status,head]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0||~strcmp(strtrim(head),expected)
    error('lmz:GraphicsCapture:Commit','Source commit does not match %s.',expected);
end
[status,worktree]=system(sprintf('git -C "%s" status --porcelain',root));
if status~=0||~isempty(strtrim(worktree))
    error('lmz:GraphicsCapture:DirtySource','Source worktree must be clean.');
end
end
function writeFixture(path,value)
folder=fileparts(path);if exist(folder,'dir')~=7,mkdir(folder);end
temporary=lmz.compat.Files.temporary(folder,'.json');cleanup=onCleanup(@()deleteFile(temporary));
file=fopen(temporary,'w');if file<0,error('lmz:GraphicsCapture:Write','Cannot write fixture.');end
fileCleanup=onCleanup(@()fclose(file));fprintf(file,'%s',lmz.compat.Json.encode(value,true));
clear fileCleanup;lmz.compat.Files.atomicMove(temporary,path);clear cleanup
end
function deleteFile(path),if exist(path,'file')==2,delete(path);end,end
