classdef RecorderService
    %RECORDERSERVICE Atomic, cancellation-aware animation and plot export.
    methods
        function recordGif(~,renderer,path,options,context)
            if nargin<4,options=struct();end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            [count,delay]=gifOptions(options);validateRenderer(renderer);target=validateTarget(path,'.gif');
            original=renderer.CurrentIndex;temporary=[tempname(fileparts(target)) '.gif'];frameImage=[tempname '.png'];
            cleanup=onCleanup(@()finishRendererExport(renderer,original,{temporary,frameImage}));
            for frame=1:count
                context.check();renderer.updateFrame(frameIndex(frame,count,numel(renderer.Simulation.Time)));
                exportAxes(renderer.Axes,frameImage,120);
                [image,map]=rgb2ind(imread(frameImage),256);
                if frame==1
                    imwrite(image,map,temporary,'gif','LoopCount',Inf,'DelayTime',delay);
                else
                    imwrite(image,map,temporary,'gif','WriteMode','append','DelayTime',delay);
                end
                context.progress(frame/count,sprintf('Recorded animation frame %d of %d',frame,count));
            end
            commitTemporary(temporary,target);clear cleanup
        end
        function recordMP4(~,renderer,path,options,context)
            if exist('VideoWriter','class')~=8,error('lmz:Recorder:MP4Unsupported','VideoWriter is unavailable.');end
            if nargin<4,options=struct();end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            count=positiveInteger(options,'FrameCount',60,2);fps=positiveScalar(options,'FPS',25);
            validateRenderer(renderer);target=validateTarget(path,'.mp4');original=renderer.CurrentIndex;
            temporary=[tempname(fileparts(target)) '.mp4'];
            try
                writer=VideoWriter(temporary,'MPEG-4');
            catch exception
                deleteIfPresent(temporary);
                error('lmz:Recorder:MP4Unsupported', ...
                    'The MPEG-4 VideoWriter profile is unavailable: %s', ...
                    exception.message);
            end
            writer.FrameRate=fps;
            open(writer);cleanup=onCleanup(@()finishVideoExport(writer,renderer,original,temporary));
            for frame=1:count
                context.check();renderer.updateFrame(frameIndex(frame,count,numel(renderer.Simulation.Time)));
                writeVideo(writer,getframe(renderer.Axes));context.progress(frame/count,sprintf('Recorded video frame %d of %d',frame,count));
            end
            close(writer);commitTemporary(temporary,target);clear cleanup
        end
        function paths=exportKeyframes(~,renderer,path,normalizedTimes,context)
            if nargin<4||isempty(normalizedTimes),normalizedTimes=[0 0.25 0.5 0.75 1];end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            validateRenderer(renderer);
            if ~isnumeric(normalizedTimes)||any(~isfinite(normalizedTimes))||any(normalizedTimes<0)||any(normalizedTimes>1)
                error('lmz:Recorder:NormalizedTimes','Keyframe times must be finite values in [0,1].');
            end
            [folder,name,extension]=fileparts(path);if isempty(folder),folder=pwd;end;if isempty(extension),extension='.png';end
            if ~any(strcmpi(extension,{'.png','.pdf'})),error('lmz:Recorder:KeyframeType','Keyframes support PNG or PDF.');end
            if exist(folder,'dir')~=7,error('lmz:Recorder:Folder','Export folder does not exist.');end
            original=renderer.CurrentIndex;cleanup=onCleanup(@()renderer.updateFrame(original));paths=cell(1,numel(normalizedTimes));
            for index=1:numel(normalizedTimes)
                context.check();renderer.updateFrame(1+round(normalizedTimes(index)*(numel(renderer.Simulation.Time)-1)));
                paths{index}=fullfile(folder,sprintf('%s_%02d%s',name,index,extension));temporary=[tempname(folder) extension];temporaryCleanup=onCleanup(@()deleteIfPresent(temporary));
                exportAxes(renderer.Axes,temporary,150);commitTemporary(temporary,paths{index});clear temporaryCleanup
                context.progress(index/numel(normalizedTimes),sprintf('Exported keyframe %d of %d',index,numel(normalizedTimes)));
            end
            clear cleanup
        end
        function exportPlot(~,axesHandle,path)
            if isempty(axesHandle)||~isgraphics(axesHandle,'axes'),error('lmz:Recorder:Axes','A valid axes is required.');end
            target=validateTarget(path,'');[folder,~,extension]=fileparts(target);if isempty(extension),error('lmz:Recorder:PlotType','Plot path needs an extension.');end
            temporary=[tempname(folder) extension];cleanup=onCleanup(@()deleteIfPresent(temporary));
            exportAxes(axesHandle,temporary,150);commitTemporary(temporary,target);clear cleanup
        end
        function recordAxesGif(~,axesHandle,frameFcn,path,options,context)
            if nargin<5,options=struct();end
            if nargin<6,context=lmz.api.RunContext.synchronous(0);end
            if isempty(axesHandle)||~isgraphics(axesHandle,'axes')||~isa(frameFcn,'function_handle'),error('lmz:Recorder:AxesFrameSource','A valid axes and frame callback are required.');end
            [count,delay]=gifOptions(options);target=validateTarget(path,'.gif');temporary=[tempname(fileparts(target)) '.gif'];frameImage=[tempname '.png'];cleanup=onCleanup(@()deleteMany({temporary,frameImage}));
            for frame=1:count
                context.check();frameFcn((frame-1)/(count-1));drawnow limitrate;exportAxes(axesHandle,frameImage,120);
                [image,map]=rgb2ind(imread(frameImage),256);
                if frame==1,imwrite(image,map,temporary,'gif','LoopCount',Inf,'DelayTime',delay);else,imwrite(image,map,temporary,'gif','WriteMode','append','DelayTime',delay);end
                context.progress(frame/count,sprintf('Recorded plot frame %d of %d',frame,count));
            end
            commitTemporary(temporary,target);clear cleanup
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
if isempty(renderer)||~isprop(renderer,'Axes')||~isprop(renderer,'Simulation')||~isprop(renderer,'CurrentIndex')||isempty(renderer.Simulation)||~isgraphics(renderer.Axes,'axes'),error('lmz:Recorder:Renderer','A valid initialized renderer is required.');end
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
function safeClose(writer),try,close(writer);catch,end,end
function safeRestore(renderer,index),try,if ~isempty(renderer)&&isvalid(renderer),renderer.updateFrame(index);end;catch,end,end
function commitTemporary(temporary,target)
[ok,message]=movefile(temporary,target,'f');if ~ok,error('lmz:Recorder:Commit','Could not finalize export: %s',message);end
end
function deleteMany(paths),for index=1:numel(paths),deleteIfPresent(paths{index});end,end
function deleteIfPresent(path),if exist(path,'file')==2,delete(path);end,end
function value=fieldOr(source,name,fallback),if isfield(source,name),value=source.(name);else,value=fallback;end,end
function exportAxes(axesHandle,path,resolution)
% R2019b fallback is raster-based because exportgraphics starts in R2020a.
if exist('exportgraphics','file')==2
    [~,~,extension]=fileparts(path);
    if strcmpi(extension,'.pdf')
        exportgraphics(axesHandle,path,'ContentType','auto');
    else
        exportgraphics(axesHandle,path,'Resolution',resolution);
    end
    return
end
drawnow;
frame=getframe(axesHandle);
[~,~,extension]=fileparts(path);
switch lower(extension)
    case {'.png','.jpg','.jpeg','.tif','.tiff'}
        imwrite(frame.cdata,path);
    case '.pdf'
        figureHandle=figure('Visible','off','Color','white');
        cleanup=onCleanup(@()delete(figureHandle));
        copyAxes=axes('Parent',figureHandle,'Position',[0 0 1 1]);
        image(copyAxes,frame.cdata);axis(copyAxes,'image');axis(copyAxes,'off');
        set(copyAxes,'YDir','reverse');
        print(figureHandle,path,'-dpdf',sprintf('-r%d',resolution));
        clear cleanup
    otherwise
        error('lmz:Recorder:PlotType', ...
            'R2019b export supports PNG, JPEG, TIFF, and PDF files.');
end
end
