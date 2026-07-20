classdef TestRecordingUsesSelectedProfile < matlab.unittest.TestCase
    %TESTRECORDINGUSESSELECTEDPROFILE Recording preserves profile and frame state.
    methods (Test)
        function gifCarriesSelectedProfileSidecarAndRestoresFrame(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));
            figureHandle=figure('Visible','off','Position',[10 10 480 360]);
            figureCleanup=onCleanup(@()deleteIfValid(figureHandle));
            profile=QuadrupedGraphicsTestSupport.profile('high_contrast');
            renderer=lmzmodels.slip_quadruped.ResearchRenderer( ...
                axes('Parent',figureHandle), ...
                QuadrupedGraphicsTestSupport.simulation(),profile,struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            renderer.updateFrame(2);target=fullfile(folder,'profile.gif');
            metadata=struct('schemaVersion','1.0.0', ...
                'modelId','slip_quadruped','problemId','periodic_apex', ...
                'visualizationProfile',profile.toStruct());
            options=struct('FrameCount',3,'DelayTime',0.01,'DPI',72, ...
                'Metadata',metadata);
            lmz.services.RecorderService().recordGif(renderer,target,options);
            testCase.verifyEqual(exist(target,'file'),2);
            testCase.verifyEqual(renderer.CurrentIndex,2);
            sidecar=[target '.lmz.json'];
            testCase.verifyEqual(exist(sidecar,'file'),2);
            stored=lmz.io.SafeJson.read(sidecar,'Root',folder);
            testCase.verifyEqual(stored.modelId,'slip_quadruped');
            testCase.verifyEqual(stored.problemId,'periodic_apex');
            testCase.verifyEqual(stored.visualizationProfile.id,'high_contrast');
            testCase.verifyEqual(stored.visualizationProfile.rendererClass, ...
                'lmzmodels.slip_quadruped.ResearchRenderer');
            clear rendererCleanup figureCleanup folderCleanup
        end

        function axesGifAndPlotAcceptProfileMetadata(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));
            figureHandle=figure('Visible','off','Position',[10 10 320 240]);
            figureCleanup=onCleanup(@()deleteIfValid(figureHandle));
            axesHandle=axes('Parent',figureHandle);plot(axesHandle,0:1,0:1);
            originalColor=[0.2 0.3 0.4];backgroundColor=[0.85 0.9 0.95];
            axesHandle.Color=originalColor;
            metadata=struct('visualizationProfile', ...
                struct('id','research_legacy'));
            gifPath=fullfile(folder,'axes.gif');
            options=struct('FrameCount',2,'DelayTime',0.01,'DPI',72, ...
                'BackgroundColor',backgroundColor,'Metadata',metadata);
            lmz.services.RecorderService().recordAxesGif(axesHandle, ...
                @(phase)assertBackgroundAndTitle(axesHandle, ...
                backgroundColor,phase),gifPath,options);
            testCase.verifyEqual(exist([gifPath '.lmz.json'],'file'),2);
            testCase.verifyEqual(axesHandle.Color,originalColor,'AbsTol',1e-12);
            plotPath=fullfile(folder,'plot.png');
            lmz.services.RecorderService().exportPlot( ...
                axesHandle,plotPath,struct('DPI',72,'Metadata',metadata));
            testCase.verifyEqual(exist(plotPath,'file'),2);
            stored=lmz.io.SafeJson.read([plotPath '.lmz.json'],'Root',folder);
            testCase.verifyEqual(stored.visualizationProfile.id,'research_legacy');
            clear figureCleanup folderCleanup
        end


        function everyKeyframeCarriesProfileSidecar(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));
            figureHandle=figure('Visible','off','Position',[10 10 480 360]);
            figureCleanup=onCleanup(@()deleteIfValid(figureHandle));
            axesHandle=axes('Parent',figureHandle);
            profile=QuadrupedGraphicsTestSupport.profile('research_legacy');
            renderer=lmzmodels.slip_quadruped.ResearchRenderer(axesHandle, ...
                QuadrupedGraphicsTestSupport.simulation(),profile,struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            renderer.updateFrame(2);originalColor=[0.25 0.3 0.35];
            axesHandle.Color=originalColor;
            metadata=struct('schemaVersion','1.0.0', ...
                'artifactKind','keyframe','modelId','slip_quadruped', ...
                'visualizationProfile',profile.toStruct());
            options=struct('BackgroundColor',[0.95 0.95 0.95]);
            paths=lmz.services.RecorderService().exportKeyframes(renderer, ...
                fullfile(folder,'research.png'),[0 0.5 1], ...
                lmz.api.RunContext.synchronous(11),metadata,72,options);
            testCase.verifyEqual(numel(paths),3);
            testCase.verifyEqual(renderer.CurrentIndex,2);
            testCase.verifyEqual(axesHandle.Color,originalColor,'AbsTol',1e-12);
            for index=1:numel(paths)
                testCase.verifyEqual(exist(paths{index},'file'),2);
                sidecar=[paths{index} '.lmz.json'];
                testCase.verifyEqual(exist(sidecar,'file'),2);
                stored=lmz.io.SafeJson.read(sidecar,'Root',folder);
                testCase.verifyEqual(stored.artifactKind,'keyframe');
                testCase.verifyEqual(stored.modelId,'slip_quadruped');
                testCase.verifyEqual(stored.visualizationProfile.id, ...
                    'research_legacy');
            end
            clear rendererCleanup figureCleanup folderCleanup
        end

        function mp4CarriesSelectedProfileSidecarWhenSupported(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));
            figureHandle=figure('Visible','off','Position',[10 10 640 480]);
            figureCleanup=onCleanup(@()deleteIfValid(figureHandle));
            axesHandle=axes('Parent',figureHandle,'Units','pixels', ...
                'Position',[50 40 540 400]);
            profile=QuadrupedGraphicsTestSupport.profile('research_legacy');
            renderer=lmzmodels.slip_quadruped.ResearchRenderer(axesHandle, ...
                QuadrupedGraphicsTestSupport.simulation(),profile,struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            renderer.updateFrame(2);originalColor=[0.2 0.25 0.3];
            axesHandle.Color=originalColor;target=fullfile(folder,'profile.mp4');
            metadata=struct('schemaVersion','1.0.0', ...
                'artifactKind','animation','modelId','slip_quadruped', ...
                'visualizationProfile',profile.toStruct());
            options=struct('FrameCount',2,'FPS',5, ...
                'BackgroundColor',[1 1 1],'Metadata',metadata);
            try
                lmz.services.RecorderService().recordMP4( ...
                    renderer,target,options);
            catch exception
                if strcmp(exception.identifier,'lmz:Recorder:MP4Unsupported')
                    testCase.assumeTrue(false, ...
                        ['MPEG-4 unavailable: ' exception.message]);
                end
                rethrow(exception)
            end
            testCase.verifyEqual(exist(target,'file'),2);
            testCase.verifyEqual(renderer.CurrentIndex,2);
            testCase.verifyEqual(axesHandle.Color,originalColor,'AbsTol',1e-12);
            sidecar=[target '.lmz.json'];
            testCase.verifyEqual(exist(sidecar,'file'),2);
            stored=lmz.io.SafeJson.read(sidecar,'Root',folder);
            testCase.verifyEqual(stored.artifactKind,'animation');
            testCase.verifyEqual(stored.modelId,'slip_quadruped');
            testCase.verifyEqual(stored.visualizationProfile.id, ...
                'research_legacy');
            clear rendererCleanup figureCleanup folderCleanup
        end

        function backgroundColorRestoresWhenCaptureFails(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));
            figureHandle=figure('Visible','off','Position',[10 10 320 240]);
            figureCleanup=onCleanup(@()deleteIfValid(figureHandle));
            axesHandle=axes('Parent',figureHandle);
            originalColor=[0.15 0.2 0.25];axesHandle.Color=originalColor;
            options=struct('FrameCount',2,'DelayTime',0.01, ...
                'BackgroundColor',[1 1 1]);
            testCase.verifyError(@()lmz.services.RecorderService().recordAxesGif( ...
                axesHandle,@failFrame,fullfile(folder,'failure.gif'),options), ...
                'lmz:Test:ExpectedCaptureFailure');
            testCase.verifyEqual(axesHandle.Color,originalColor,'AbsTol',1e-12);
            clear figureCleanup folderCleanup
        end


        function clearedRendererIsRejectedBeforeCreatingOutput(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));
            figureHandle=figure('Visible','off','Position',[10 10 480 360]);
            figureCleanup=onCleanup(@()deleteIfValid(figureHandle));
            renderer=lmzmodels.slip_quadruped.ResearchRenderer( ...
                axes('Parent',figureHandle), ...
                QuadrupedGraphicsTestSupport.simulation(), ...
                QuadrupedGraphicsTestSupport.profile('research_legacy'),struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            renderer.clear();target=fullfile(folder,'cleared.gif');
            testCase.verifyError(@()lmz.services.RecorderService().recordGif( ...
                renderer,target,struct('FrameCount',2,'DelayTime',0.01)), ...
                'lmz:Recorder:Renderer');
            testCase.verifyEqual(exist(target,'file'),0);
            clear rendererCleanup figureCleanup folderCleanup
        end
    end
end

function assertBackgroundAndTitle(axesHandle,expected,phase)
assert(max(abs(double(axesHandle.Color)-double(expected)))<1e-12, ...
    'lmz:Test:BackgroundColor','Recording background color was not applied.');
title(axesHandle,sprintf('%.2f',phase));
end

function failFrame(~)
error('lmz:Test:ExpectedCaptureFailure','Intentional capture failure.');
end

function deleteIfValid(value)
if ~isempty(value)&&isgraphics(value),delete(value);end
end

function removeFolder(folder)
if exist(folder,'dir')==7,rmdir(folder,'s');end
end
