function fixture=capture_biped_graphics_baselines(sourceRoot,outputPath)
%CAPTURE_BIPED_GRAPHICS_BASELINES Capture pinned post-update patch geometry.
root=lmz.util.ProjectPaths.root();
if nargin<1||isempty(sourceRoot)
    sourceRoot=fullfile(fileparts(root), ...
        '2022_A_Template_Model_Explains_Jerboa_Gait_Transitions');
end
if nargin<2||isempty(outputPath)
    outputPath=fullfile(root,'tests','fixtures','graphics', ...
        'slip_biped','source_capture.json');
end
commit='4595146c5881a5313bc8fe92de85099193ef9be9';verifySource(sourceRoot,commit);
graphicsRoot=fullfile(sourceRoot,'Stored_Functions','Graphics');
addpath(graphicsRoot);pathCleanup=onCleanup(@()rmpath(graphicsRoot));
figureHandle=figure('Visible','off','Color','white');figureCleanup=onCleanup(@()delete(figureHandle));
axesHandle=axes('Parent',figureHandle);hold(axesHandle,'on');
x=2;y=.9;leftAngle=.2;rightAngle=-.3;leftLength=y/cos(leftAngle);rightLength=1;
body=DrawBody(x,y);left=DrawLegsLeftPointFeet(x,y,leftLength,leftAngle);
right=DrawLegsPointFeet(x,y,rightLength,rightAngle);
SetDrawLegsPointFeet(x,y,leftLength,leftAngle,left);
SetDrawLegsPointFeet(x,y,rightLength,rightAngle,right);
fixture=struct('schemaVersion','1.0.0', ...
    'sourceRepository','2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
    'sourceCommit',commit,'canonicalState',struct('x',x,'y',y, ...
    'alphaLeft',leftAngle,'alphaRight',rightAngle), ...
    'canonicalEvents',[.2 .6 .7 .1 1],'contact',[true false], ...
    'legLength',[leftLength rightLength], ...
    'footPosition',[x+leftLength*sin(leftAngle),0; ...
    x+sin(rightAngle),y-cos(rightAngle)], ...
    'body',struct('xData',get(body.B_out,'XData'), ...
    'yData',get(body.B_out,'YData')), ...
    'leftLeg',extractLeg(left),'rightLeg',extractLeg(right), ...
    'cog',cogGeometry(x,y),'ground',groundSummary(), ...
    'camera',struct('xLimits',x+[-1.5 1.5],'yLimits',[-.3 2], ...
    'dataAspectRatio',[1 1 1]),'style',struct( ...
    'springColor',[0 68 158]/256,'springWidth',5, ...
    'leftFaceColor',[202 202 202]/256,'rightFaceColor',[1 1 1]));
writeFixture(outputPath,fixture);
clear figureCleanup pathCleanup
fprintf('LMZ_BIPED_GRAPHICS_BASELINE_OK path=%s\n',outputPath);
end

function value=extractLeg(handles)
names={'L_Sp1','L_low','L_Sp2','L_Upo'};value=struct();
for index=1:numel(names)
    handle=handles.(names{index});value.(names{index})=struct( ...
        'vertices',get(handle,'Vertices'),'faces',get(handle,'Faces'));
end
end
function value=cogGeometry(x,y)
angle=linspace(0,pi/2,10);a=[0 .1*sin(angle) 0];b=[0 .1*cos(angle) 0];
value=struct('x',[a;a;-a;-a].'+x,'y',[b;-b;-b;b].'+y, ...
    'colors',cat(3,[1 0 1 0],[1 0 1 0],[1 0 1 0]));
end
function value=groundSummary()
value=struct('fieldX',[-20 100 100 -20],'fieldY',[0 0 -40 -40], ...
    'vertexCount',20002,'faceCount',5001,'hatchXLimits',[-50.1 200.01]);
end
function verifySource(root,expected)
[status,head]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0||~strcmp(strtrim(head),expected),error('lmz:GraphicsCapture:Commit', ...
        'Biped source commit mismatch.');end
[status,worktree]=system(sprintf('git -C "%s" status --porcelain',root));
if status~=0||~isempty(strtrim(worktree)),error('lmz:GraphicsCapture:DirtySource', ...
        'Biped source must be clean.');end
end
function writeFixture(path,value)
folder=fileparts(path);if exist(folder,'dir')~=7,mkdir(folder);end
temporary=lmz.compat.Files.temporary(folder,'.json');cleanup=onCleanup(@()deleteFile(temporary));
file=fopen(temporary,'w');if file<0,error('lmz:GraphicsCapture:Write','Cannot write fixture.');end
fileCleanup=onCleanup(@()fclose(file));fprintf(file,'%s',lmz.compat.Json.encode(value,true));
clear fileCleanup;lmz.compat.Files.atomicMove(temporary,path);clear cleanup
end
function deleteFile(path),if exist(path,'file')==2,delete(path);end,end
