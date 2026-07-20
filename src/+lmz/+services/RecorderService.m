classdef RecorderService
    %RECORDERSERVICE Atomic, cancellation-aware animation and plot export.
    methods
        function recordGif(~,renderer,path,options,context)
            if nargin<4,options=struct();end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            [count,delay]=gifOptions(options);validateRenderer(renderer);target=validateTarget(path,'.gif');
            original=renderer.CurrentIndex;temporary=lmz.compat.Files.temporary(fileparts(target),'.gif');frameImage=lmz.compat.Files.temporary(tempdir,'.png');
            cleanup=onCleanup(@()finishRendererExport(renderer,original,{temporary,frameImage}));
            for frame=1:count
                context.check();renderer.updateFrame(frameIndex(frame,count,numel(renderer.Simulation.Time)));
                lmz.compat.Graphics.exportAxes(renderer.Axes,frameImage,120);
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
            if nargin<4,options=struct();end
            if nargin<5,context=lmz.api.RunContext.synchronous(0);end
            count=positiveInteger(options,'FrameCount',60,2);fps=positiveScalar(options,'FPS',25);
            validateRenderer(renderer);target=validateTarget(path,'.mp4');original=renderer.CurrentIndex;
            temporary=lmz.compat.Files.temporary(fileparts(target),'.mp4');
            try
                writer=lmz.compat.Video.create(temporary,{'MPEG-4'});
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
                paths{index}=fullfile(folder,sprintf('%s_%02d%s',name,index,extension));temporary=lmz.compat.Files.temporary(folder,extension);temporaryCleanup=onCleanup(@()deleteIfPresent(temporary));
                lmz.compat.Graphics.exportAxes(renderer.Axes,temporary,150);commitTemporary(temporary,paths{index});clear temporaryCleanup
                context.progress(index/numel(normalizedTimes),sprintf('Exported keyframe %d of %d',index,numel(normalizedTimes)));
            end
            clear cleanup
        end
        function exportPlot(~,axesHandle,path)
            if isempty(axesHandle)||~isgraphics(axesHandle,'axes'),error('lmz:Recorder:Axes','A valid axes is required.');end
            target=validateTarget(path,'');[folder,~,extension]=fileparts(target);if isempty(extension),error('lmz:Recorder:PlotType','Plot path needs an extension.');end
            temporary=lmz.compat.Files.temporary(folder,extension);cleanup=onCleanup(@()deleteIfPresent(temporary));
            lmz.compat.Graphics.exportAxes(axesHandle,temporary,150);commitTemporary(temporary,target);clear cleanup
        end
        function recordAxesGif(~,axesHandle,frameFcn,path,options,context)
            if nargin<5,options=struct();end
            if nargin<6,context=lmz.api.RunContext.synchronous(0);end
            if isempty(axesHandle)||~isgraphics(axesHandle,'axes')||~isa(frameFcn,'function_handle'),error('lmz:Recorder:AxesFrameSource','A valid axes and frame callback are required.');end
            [count,delay]=gifOptions(options);target=validateTarget(path,'.gif');temporary=lmz.compat.Files.temporary(fileparts(target),'.gif');frameImage=lmz.compat.Files.temporary(tempdir,'.png');cleanup=onCleanup(@()deleteMany({temporary,frameImage}));
            for frame=1:count
                context.check();frameFcn((frame-1)/(count-1));drawnow limitrate;lmz.compat.Graphics.exportAxes(axesHandle,frameImage,120);
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
lmz.compat.Files.atomicMove(temporary,target);
end
function deleteMany(paths),for index=1:numel(paths),deleteIfPresent(paths{index});end,end
function deleteIfPresent(path),if exist(path,'file')==2,delete(path);end,end
function value=fieldOr(source,name,fallback),if isfield(source,name),value=source.(name);else,value=fallback;end,end
