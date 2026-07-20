classdef RecorderService
    %RECORDERSERVICE Atomic, cancellation-aware animation and plot export.
    methods
        function recordGif(~,renderer,path,options,context)
            if nargin<4,options=struct();end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            [count,delay]=gifOptions(options);dpi=positiveScalar(options,'DPI',120);
            validateRenderer(renderer);target=validateTarget(path,'.gif');
            original=renderer.CurrentIndex;temporary=lmz.compat.Files.temporary(fileparts(target),'.gif');frameImage=lmz.compat.Files.temporary(tempdir,'.png');
            backgroundCleanup=applyBackgroundColor(renderer.Axes,options); %#ok<NASGU>
            cleanup=onCleanup(@()finishRendererExport(renderer,original,{temporary,frameImage}));
            for frame=1:count
                context.check();renderer.updateFrame(frameIndex(frame,count,numel(renderer.Simulation.Time)));
                lmz.compat.Graphics.exportAxes(renderer.Axes,frameImage,dpi);
                [image,map]=rgb2ind(imread(frameImage),256);
                if frame==1
                    imwrite(image,map,temporary,'gif','LoopCount',Inf,'DelayTime',delay);
                else
                    imwrite(image,map,temporary,'gif','WriteMode','append','DelayTime',delay);
                end
                context.progress(frame/count,sprintf('Recorded animation frame %d of %d',frame,count));
            end
            commitTemporary(temporary,target);writeMetadata(target,options);
            clear cleanup backgroundCleanup
        end
        function recordMP4(~,renderer,path,options,context)
            if nargin<4,options=struct();end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            count=positiveInteger(options,'FrameCount',60,2);
            fps=positiveScalar(options,'FPS',25);
            dpi=positiveScalar(options,'DPI',120);
            validateRenderer(renderer);target=validateTarget(path,'.mp4');original=renderer.CurrentIndex;
            temporary=lmz.compat.Files.temporary(fileparts(target),'.mp4');
            backgroundCleanup=applyBackgroundColor(renderer.Axes,options); %#ok<NASGU>
            try
                writer=lmz.compat.Video.create(temporary,{'MPEG-4'});
            catch exception
                deleteIfPresent(temporary);
                error('lmz:Recorder:MP4Unsupported', ...
                    'The MPEG-4 VideoWriter profile is unavailable: %s', ...
                    exception.message);
            end
            cleanup=onCleanup(@()finishVideoExport( ...
                writer,renderer,original,temporary));
            writer.FrameRate=fps;
            open(writer);
            for frame=1:count
                context.check();renderer.updateFrame(frameIndex(frame,count,numel(renderer.Simulation.Time)));
                imageData=lmz.compat.Graphics.captureAxes(renderer.Axes,dpi);
                writeVideo(writer,imageData);context.progress(frame/count,sprintf('Recorded video frame %d of %d',frame,count));
            end
            close(writer);commitTemporary(temporary,target);writeMetadata(target,options);
            clear cleanup backgroundCleanup
        end
        function paths=exportKeyframes(~,renderer,path,normalizedTimes,context,metadata,dpi,options)
            if nargin<4||isempty(normalizedTimes),normalizedTimes=[0 0.25 0.5 0.75 1];end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            if nargin<6,metadata=struct();end
            if nargin<7,dpi=150;end
            if nargin<8,options=struct();end
            dpi=positiveScalar(struct('DPI',dpi),'DPI',150);
            validateRenderer(renderer);
            if ~isnumeric(normalizedTimes)||any(~isfinite(normalizedTimes))||any(normalizedTimes<0)||any(normalizedTimes>1)
                error('lmz:Recorder:NormalizedTimes','Keyframe times must be finite values in [0,1].');
            end
            [folder,name,extension]=fileparts(path);if isempty(folder),folder=pwd;end;if isempty(extension),extension='.png';end
            if ~any(strcmpi(extension,{'.png','.pdf'})),error('lmz:Recorder:KeyframeType','Keyframes support PNG or PDF.');end
            if exist(folder,'dir')~=7,error('lmz:Recorder:Folder','Export folder does not exist.');end
            backgroundCleanup=applyBackgroundColor(renderer.Axes,options); %#ok<NASGU>
            original=renderer.CurrentIndex;cleanup=onCleanup(@()renderer.updateFrame(original));paths=cell(1,numel(normalizedTimes));
            for index=1:numel(normalizedTimes)
                context.check();renderer.updateFrame(1+round(normalizedTimes(index)*(numel(renderer.Simulation.Time)-1)));
                paths{index}=fullfile(folder,sprintf('%s_%02d%s',name,index,extension));temporary=lmz.compat.Files.temporary(folder,extension);temporaryCleanup=onCleanup(@()deleteIfPresent(temporary));
                lmz.compat.Graphics.exportAxes(renderer.Axes,temporary,dpi);commitTemporary(temporary,paths{index});clear temporaryCleanup
                writeMetadata(paths{index},struct('Metadata',metadata));
                context.progress(index/numel(normalizedTimes),sprintf('Exported keyframe %d of %d',index,numel(normalizedTimes)));
            end
            clear cleanup backgroundCleanup
        end
        function exportPlot(~,axesHandle,path,options)
            if nargin<4,options=struct();end
            if isempty(axesHandle)||~isgraphics(axesHandle,'axes'),error('lmz:Recorder:Axes','A valid axes is required.');end
            target=validateTarget(path,'');[folder,~,extension]=fileparts(target);if isempty(extension),error('lmz:Recorder:PlotType','Plot path needs an extension.');end
            temporary=lmz.compat.Files.temporary(folder,extension);cleanup=onCleanup(@()deleteIfPresent(temporary));
            dpi=positiveScalar(options,'DPI',150);
            backgroundCleanup=applyBackgroundColor(axesHandle,options); %#ok<NASGU>
            lmz.compat.Graphics.exportAxes(axesHandle,temporary,dpi);commitTemporary(temporary,target);
            writeMetadata(target,options);clear cleanup backgroundCleanup
        end
        function recordAxesGif(~,axesHandle,frameFcn,path,options,context)
            if nargin<5,options=struct();end
            if nargin<6,context=lmz.api.RunContext.synchronous(0);end
            if isempty(axesHandle)||~isgraphics(axesHandle,'axes')||~isa(frameFcn,'function_handle'),error('lmz:Recorder:AxesFrameSource','A valid axes and frame callback are required.');end
            [count,delay]=gifOptions(options);dpi=positiveScalar(options,'DPI',120);
            target=validateTarget(path,'.gif');temporary=lmz.compat.Files.temporary(fileparts(target),'.gif');frameImage=lmz.compat.Files.temporary(tempdir,'.png');
            backgroundCleanup=applyBackgroundColor(axesHandle,options); %#ok<NASGU>
            cleanup=onCleanup(@()deleteMany({temporary,frameImage}));
            for frame=1:count
                context.check();frameFcn((frame-1)/(count-1));drawnow limitrate;lmz.compat.Graphics.exportAxes(axesHandle,frameImage,dpi);
                [image,map]=rgb2ind(imread(frameImage),256);
                if frame==1,imwrite(image,map,temporary,'gif','LoopCount',Inf,'DelayTime',delay);else,imwrite(image,map,temporary,'gif','WriteMode','append','DelayTime',delay);end
                context.progress(frame/count,sprintf('Recorded plot frame %d of %d',frame,count));
            end
            commitTemporary(temporary,target);writeMetadata(target,options);
            clear cleanup backgroundCleanup
        end
    end
end

function [count,delay]=gifOptions(options)
count=positiveInteger(options,'FrameCount',40,2);delay=positiveScalar(options,'DelayTime',0.04);
end
function value=positiveInteger(options,name,fallback,minimum)
value=fieldOr(options,name,fallback);if ~isscalar(value)||~isfinite(value)||value~=fix(value)||value<minimum,error('lmz:Recorder:FrameCount','%s must be an integer of at least %d.',name,minimum);end
end
function value=positiveScalar(options,name,fallback)
value=fieldOr(options,name,fallback);if ~isscalar(value)||~isfinite(value)||value<=0,error('lmz:Recorder:Rate','%s must be positive and finite.',name);end
end
function validateRenderer(renderer)
if isempty(renderer)||~isa(renderer,'lmz.viz.Renderer')||~isvalid(renderer)|| ...
        ~renderer.IsInitialized||isempty(renderer.Simulation)|| ...
        ~isgraphics(renderer.Axes,'axes')
    error('lmz:Recorder:Renderer','A valid initialized renderer is required.');
end
end
function target=validateTarget(path,requiredExtension)
if ~(ischar(path)&&~isempty(path)),error('lmz:Recorder:Path','Export path must be nonempty text.');end
[folder,~,extension]=fileparts(path);if isempty(folder),folder=pwd;path=fullfile(folder,path);end
if exist(folder,'dir')~=7,error('lmz:Recorder:Folder','Export folder does not exist.');end
if ~isempty(requiredExtension)&&~strcmpi(extension,requiredExtension),error('lmz:Recorder:Extension','Export path must use %s.',requiredExtension);end
target=path;
end
function index=frameIndex(frame,count,sampleCount),index=1+round((frame-1)/(count-1)*(sampleCount-1));end
function finishRendererExport(renderer,index,paths),safeRestore(renderer,index);deleteMany(paths);end
function finishVideoExport(writer,renderer,index,temporary),safeClose(writer);safeRestore(renderer,index);deleteIfPresent(temporary);end
function safeClose(writer)
try
    close(writer);
catch
end
end
function safeRestore(renderer,index)
try
    if ~isempty(renderer)&&isvalid(renderer),renderer.updateFrame(index);end
catch
end
end
function cleanup=applyBackgroundColor(axesHandle,options)
cleanup=[];
if ~isstruct(options)||~isfield(options,'BackgroundColor'),return,end
color=options.BackgroundColor;
if ~isnumeric(color)||~isreal(color)||numel(color)~=3|| ...
        any(~isfinite(color(:)))||any(color(:)<0)||any(color(:)>1)
    error('lmz:Recorder:BackgroundColor', ...
        'BackgroundColor must be an RGB value in [0,1].');
end
original=get(axesHandle,'Color');
cleanup=onCleanup(@()safeRestoreAxesColor(axesHandle,original));
set(axesHandle,'Color',reshape(double(color),1,3));
end
function safeRestoreAxesColor(axesHandle,color)
try
    if ~isempty(axesHandle)&&isgraphics(axesHandle,'axes')
        set(axesHandle,'Color',color);
    end
catch
end
end
function commitTemporary(temporary,target)
lmz.compat.Files.atomicMove(temporary,target);
end
function deleteMany(paths),for index=1:numel(paths),deleteIfPresent(paths{index});end,end
function deleteIfPresent(path),if exist(path,'file')==2,delete(path);end,end
function value=fieldOr(source,name,fallback),if isfield(source,name),value=source.(name);else,value=fallback;end,end
function writeMetadata(target,options)
if ~isstruct(options)||~isfield(options,'Metadata')|| ...
        ~isstruct(options.Metadata)||isempty(fieldnames(options.Metadata)),return,end
metadataPath=[target '.lmz.json'];folder=fileparts(metadataPath);
if isempty(folder),folder=pwd;end
temporary=lmz.compat.Files.temporary(folder,'.json');
cleanup=onCleanup(@()deleteIfPresent(temporary));
text=lmz.compat.Json.encode(options.Metadata,true);
file=fopen(temporary,'w');
if file<0,error('lmz:Recorder:Metadata','Could not create recording metadata.');end
fileCleanup=onCleanup(@()fclose(file));
count=fwrite(file,text,'char');
if count~=numel(text),error('lmz:Recorder:Metadata','Could not write recording metadata.');end
clear fileCleanup
commitTemporary(temporary,metadataPath);clear cleanup
end
