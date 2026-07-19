classdef TestRoadMapRecordingSmoke < matlab.unittest.TestCase
    methods (Test)
        function gifClosesResources(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');simulation=controller.simulateWorkingSolution();figureHandle=figure('Visible','off');path=[tempname '.gif'];cleanup=onCleanup(@()clean(figureHandle,path));renderer=lmzmodels.slip_quadruped.QuadrupedRenderer(axes(figureHandle),simulation);
            renderer.updateFrame(7);controller.recordAnimation('gif',path,renderer,struct('FrameCount',3,'DelayTime',0.01));testCase.verifyEqual(exist(path,'file'),2);testCase.verifyEqual(renderer.CurrentIndex,7);testCase.verifyFalse(controller.State.RecordingState.Active);clear cleanup
        end
        function keyframesPlotAxesGifAndValidation(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');simulation=controller.simulateWorkingSolution();figureHandle=figure('Visible','off');axesHandle=axes(figureHandle);renderer=lmzmodels.slip_quadruped.QuadrupedRenderer(axesHandle,simulation);
            keyframeBase=[tempname '.png'];plotPath=[tempname '.png'];axesGif=[tempname '.gif'];badPath=[tempname '.gif'];mp4Path=[tempname '.mp4'];paths={plotPath,axesGif,badPath,mp4Path};for index=1:3,[folder,name,extension]=fileparts(keyframeBase);paths{end+1}=fullfile(folder,sprintf('%s_%02d%s',name,index,extension));end;cleanup=onCleanup(@()cleanMany(figureHandle,paths));
            controller.recordAnimation('keyframes',keyframeBase,renderer,struct('NormalizedTimes',[0 .5 1]));for index=5:7,testCase.verifyEqual(exist(paths{index},'file'),2);end
            controller.exportPlot(axesHandle,plotPath);testCase.verifyEqual(exist(plotPath,'file'),2);
            controller.recordAxesGif(axesHandle,@(phase)title(axesHandle,sprintf('phase %.2f',phase)),axesGif,struct('FrameCount',3,'DelayTime',0.01));testCase.verifyEqual(exist(axesGif,'file'),2);
            if exist('VideoWriter','class')==8,controller.recordAnimation('mp4',mp4Path,renderer,struct('FrameCount',3,'FPS',10));testCase.verifyEqual(exist(mp4Path,'file'),2);end
            testCase.verifyError(@()controller.recordAnimation('gif',badPath,renderer,struct('FrameCount',1)),'lmz:Recorder:FrameCount');testCase.verifyEqual(exist(badPath,'file'),0);clear cleanup
        end
    end
end
function clean(figureHandle,path),if isgraphics(figureHandle),delete(figureHandle);end;if exist(path,'file')==2,delete(path);end,end
function cleanMany(figureHandle,paths),if isgraphics(figureHandle),delete(figureHandle);end;for index=1:numel(paths),if exist(paths{index},'file')==2,delete(paths{index});end,end,end
