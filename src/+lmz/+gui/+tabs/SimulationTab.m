classdef SimulationTab < lmz.gui.tabs.BaseTab
    %SIMULATIONTAB Physical rendering, playback, and recording workspace.
    properties (SetAccess=private)
        Axes
        TorsoAxes
        BackLegAxes
        FrontLegAxes
        GRFAxes
        OscillatorAxes
        TimeSlider
        NormalizedTimeField
        FPSSpinner
        SpeedSpinner
        LoopCheckBox
        ForceCheckBox
        TrajectoryModeDropDown
        VisualProfileDropDown
        DetailedOverlayCheckBox
        GroundStyleDropDown
        CameraFollowCheckBox
        ResetCameraButton
        ProfileMetadataLabel
        SimulateButton
        AnimationRenderer
        AnimationPlayer
        ProfileRegistry
        RendererFactory
        CurrentProfile
    end

    methods
        function obj=SimulationTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Physical Simulation','Tag','lmz-tab-simulation');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
            obj.ProfileRegistry=lmz.viz.VisualizationProfileRegistry(controller.Registry);
            obj.RendererFactory=lmz.viz.RendererFactory( ...
                controller.Registry,obj.ProfileRegistry);
            obj.Id='simulation';obj.CapabilityName='simulate';obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.SimulationChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            rootGrid=uigridlayout(obj.Root,[3 2]);
            rootGrid.RowHeight={'1x','1x',150};rootGrid.ColumnWidth={'1.12x','1x'};
            obj.Axes=uiaxes(rootGrid,'Tag','lmz-simulation-animation');place(obj.Axes,[1 2],1);
            title(obj.Axes,'Select and simulate a branch point');
            trajectories=uitabgroup(rootGrid);place(trajectories,1,2);
            obj.TorsoAxes=tabAxes(trajectories,'Torso','lmz-simulation-torso');
            obj.BackLegAxes=tabAxes(trajectories,'Back legs','lmz-simulation-back');
            obj.FrontLegAxes=tabAxes(trajectories,'Front legs','lmz-simulation-front');
            lower=uigridlayout(rootGrid,[1 2]);place(lower,2,2);
            obj.GRFAxes=uiaxes(lower,'Tag','lmz-simulation-grf');
            obj.OscillatorAxes=uiaxes(lower,'Tag','lmz-simulation-oscillator');
            controls=uigridlayout(rootGrid,[4 12]);place(controls,3,[1 2]);
            controls.RowHeight={30,30,22,34};
            controls.ColumnWidth={110,'1x','1x','1x',72,58,84,66,72,86,92,105};
            label=uilabel(controls,'Text','Normalized stride');place(label,1,1);
            obj.TimeSlider=uislider(controls,'Limits',[0 1],'Tag','lmz-simulation-time', ...
                'Tooltip','Scrub through normalized stride time.', ...
                'ValueChangingFcn',@(~,event)obj.setAnimationTime(event.Value), ...
                'ValueChangedFcn',@(~,~)obj.setAnimationTime(obj.TimeSlider.Value));place(obj.TimeSlider,1,[2 4]);
            obj.NormalizedTimeField=uieditfield(controls,'numeric','Limits',[0 1], ...
                'Value',0,'Tag','lmz-simulation-time-field', ...
                'ValueChangedFcn',@(~,~)obj.setAnimationTime(obj.NormalizedTimeField.Value));place(obj.NormalizedTimeField,1,5);
            label=uilabel(controls,'Text','FPS');place(label,1,6);
            obj.FPSSpinner=uispinner(controls,'Limits',[1 120],'Value',25,'Step',1, ...
                'Tag','lmz-simulation-fps','Tooltip','Playback and video frames per second.');place(obj.FPSSpinner,1,7);
            label=uilabel(controls,'Text','Speed');place(label,1,8);
            obj.SpeedSpinner=uispinner(controls,'Limits',[0.1 10],'Value',1,'Step',0.1, ...
                'Tag','lmz-simulation-speed','Tooltip','Playback speed multiplier.');place(obj.SpeedSpinner,1,9);
            obj.LoopCheckBox=uicheckbox(controls,'Text','Loop','Value',false, ...
                'Tag','lmz-simulation-loop');place(obj.LoopCheckBox,1,10);
            obj.TrajectoryModeDropDown=uidropdown(controls,'Items',{'Complete','Progressive'}, ...
                'Value','Complete','Tag','lmz-simulation-trajectory-mode', ...
                'Tooltip','Show complete trajectories or reveal them progressively.', ...
                'ValueChangedFcn',@(~,~)obj.frameChanged(obj.NormalizedTimeField.Value,[]));
            place(obj.TrajectoryModeDropDown,1,[11 12]);

            label=uilabel(controls,'Text','Visual profile');place(label,2,1);
            obj.VisualProfileDropDown=uidropdown(controls, ...
                'Items',{'Clean generic'},'ItemsData',{'clean_generic'}, ...
                'Value','clean_generic','Tag','lmz-simulation-visual-profile', ...
                'Tooltip','Choose research legacy, clean generic, or high-contrast graphics.', ...
                'ValueChangedFcn',@(~,~)obj.profileChanged());
            place(obj.VisualProfileDropDown,2,[2 4]);
            obj.DetailedOverlayCheckBox=uicheckbox(controls,'Text','Detailed', ...
                'Value',false,'Tag','lmz-simulation-detailed-overlay', ...
                'Tooltip','Show source phase/details overlay where supported.', ...
                'ValueChangedFcn',@(~,~)obj.visualOptionsChanged());place(obj.DetailedOverlayCheckBox,2,5);
            label=uilabel(controls,'Text','Ground');place(label,2,6);
            obj.GroundStyleDropDown=uidropdown(controls, ...
                'Items',{'Line','Hidden'},'Value','Line', ...
                'Tag','lmz-simulation-ground-style', ...
                'Tooltip','Choose the supported ground treatment.', ...
                'ValueChangedFcn',@(~,~)obj.visualOptionsChanged());place(obj.GroundStyleDropDown,2,7);
            obj.ForceCheckBox=uicheckbox(controls,'Text','Forces','Value',false, ...
                'Tag','lmz-simulation-forces','Tooltip','Show physical force arrows when supported.', ...
                'ValueChangedFcn',@(~,~)obj.visualOptionsChanged());place(obj.ForceCheckBox,2,8);
            obj.CameraFollowCheckBox=uicheckbox(controls,'Text','Follow', ...
                'Value',true,'Tag','lmz-simulation-camera-follow', ...
                'Tooltip','Keep the profile camera centered on the moving model.', ...
                'ValueChangedFcn',@(~,~)obj.visualOptionsChanged());place(obj.CameraFollowCheckBox,2,9);
            obj.ResetCameraButton=uibutton(controls,'Text','Reset camera', ...
                'Tag','lmz-simulation-reset-camera', ...
                'Tooltip','Restore the selected profile camera.', ...
                'ButtonPushedFcn',@(~,~)obj.resetCamera());place(obj.ResetCameraButton,2,10);
            paletteLabel=uilabel(controls,'Text','Profile controls renderer palette', ...
                'HorizontalAlignment','center');place(paletteLabel,2,[11 12]);
            obj.ProfileMetadataLabel=uilabel(controls,'Text','', ...
                'Tag','lmz-simulation-profile-metadata', ...
                'FontAngle','italic','HorizontalAlignment','left');
            place(obj.ProfileMetadataLabel,3,[1 12]);
            labels={'Play','Pause','Stop','Reset','Simulate point','GIF…','MP4…', ...
                'Keyframes…','Export plots…','Oscillator GIF…','Cancel export'};
            tags={'play','pause','stop','reset','simulate','gif','mp4','keyframes', ...
                'export-plots','oscillator-gif','cancel-export'};
            callbacks={@()obj.play(),@()obj.pause(),@()obj.stop(),@()obj.reset(), ...
                @()obj.simulate(),@()obj.recordGif(),@()obj.recordMP4(), ...
                @()obj.recordKeyframes(),@()obj.exportPlots(),@()obj.recordOscillatorGif(), ...
                @()obj.Controller.stopRecording()};
            buttons=cell(1,numel(labels));
            for index=1:numel(labels)
                buttons{index}=uibutton(controls,'Text',labels{index}, ...
                    'Tag',['lmz-simulation-' tags{index}], ...
                    'ButtonPushedFcn',@(~,~)callbacks{index}());place(buttons{index},4,index);
            end
            obj.SimulateButton=buttons{5};
            obj.ActionControls=[buttons(1:10) {obj.TimeSlider obj.NormalizedTimeField ...
                obj.FPSSpinner obj.SpeedSpinner obj.LoopCheckBox obj.ForceCheckBox ...
                obj.TrajectoryModeDropDown obj.VisualProfileDropDown ...
                obj.DetailedOverlayCheckBox obj.GroundStyleDropDown ...
                obj.CameraFollowCheckBox obj.ResetCameraButton}];
            obj.CancelControls=buttons(11);
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            obj.refreshProfileControls();
            simulation=obj.Controller.State.Simulation;
            if isempty(simulation)
                obj.clearPresentation();return
            end
            obj.renderSimulation(simulation);
        end

        function stopAnimation(obj),obj.stop();end

        function hooks=testHooks(obj)
            hooks=testHooks@lmz.gui.tabs.BaseTab(obj);hooks.Controls=obj.controlMap();
        end
    end

    methods (Static)
        function value=descriptor()
            value=struct('Id','simulation','Title','Physical Simulation', ...
                'Purpose','Animate and inspect model-specific physical output.');
        end
    end

    methods (Access=protected)
        function onPresentationEvents(obj,batch)
            names={batch.Name};
            if any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.SelectionChanged, ...
                    lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                    lmz.gui.PresentationEvents.SimulationChanged}))
                obj.refresh(batch);
            end
        end

        function beforeDelete(obj)
            obj.disposeAnimation();
        end

        function value=cancelControlsEnabled(obj)
            recording=obj.Controller.State.RecordingState;
            value=obj.IsBusy&&isstruct(recording)&&isscalar(recording)&& ...
                isfield(recording,'Active')&&islogical(recording.Active)&& ...
                isscalar(recording.Active)&&recording.Active;
        end

        function controls=controlMap(obj)
            controls=struct('Axes',obj.Axes,'TorsoAxes',obj.TorsoAxes, ...
                'BackLegAxes',obj.BackLegAxes,'FrontLegAxes',obj.FrontLegAxes, ...
                'GRFAxes',obj.GRFAxes,'OscillatorAxes',obj.OscillatorAxes, ...
                'TimeSlider',obj.TimeSlider,'NormalizedTimeField',obj.NormalizedTimeField, ...
                'FPSSpinner',obj.FPSSpinner,'SimulateButton',obj.SimulateButton, ...
                'VisualProfileDropDown',obj.VisualProfileDropDown, ...
                'ForceCheckBox',obj.ForceCheckBox, ...
                'DetailedOverlayCheckBox',obj.DetailedOverlayCheckBox, ...
                'GroundStyleDropDown',obj.GroundStyleDropDown, ...
                'CameraFollowCheckBox',obj.CameraFollowCheckBox, ...
                'ResetCameraButton',obj.ResetCameraButton, ...
                'ProfileMetadataLabel',obj.ProfileMetadataLabel);
        end
    end

    methods (Access=private)
        function simulate(obj)
            try,obj.Controller.simulateWorkingSolution();catch exception,obj.reportError(exception);end
        end

        function renderSimulation(obj,simulation)
            obj.disposeAnimation();
            modelId=obj.Controller.State.ModelId;
            problemId=obj.Controller.State.ProblemId;
            try
                options=obj.rendererOptions();
                [obj.AnimationRenderer,obj.CurrentProfile]= ...
                    obj.RendererFactory.createRenderer(obj.Axes,simulation, ...
                    modelId,problemId,obj.VisualProfileDropDown.Value,options);
                axesMap=struct('Torso',obj.TorsoAxes,'Back',obj.BackLegAxes, ...
                    'Front',obj.FrontLegAxes,'Forces',obj.GRFAxes, ...
                    'Auxiliary',obj.OscillatorAxes);
                if ~obj.RendererFactory.renderPlots(axesMap,simulation, ...
                        modelId,obj.CurrentProfile)
                    obj.renderGenericPlots(simulation);
                end
                obj.updateProfileMetadata();
                if ~isempty(obj.AnimationRenderer)
                    obj.AnimationPlayer=lmz.gui.AnimationController(simulation,obj.AnimationRenderer);
                    obj.AnimationPlayer.FrameChangedFcn=@(value,index)obj.frameChanged(value,index);
                    obj.frameChanged(0,1);
                end
            catch exception
                obj.disposeAnimation();obj.renderGeneric(simulation);obj.reportError(exception);
            end
        end

        function renderGenericPlots(obj,simulation)
            axesList={obj.TorsoAxes,obj.BackLegAxes,obj.FrontLegAxes, ...
                obj.GRFAxes,obj.OscillatorAxes};
            for index=1:numel(axesList),cla(axesList{index});end
            names=simulation.StateSchema.names();
            plot(obj.TorsoAxes,simulation.Time,simulation.States,'LineWidth',1.1);
            grid(obj.TorsoAxes,'on');xlabel(obj.TorsoAxes,'Time');
            title(obj.TorsoAxes,'State trajectories');
            if numel(names)<=12,legend(obj.TorsoAxes,names,'Interpreter','none', ...
                    'Location','best');end
        end

        function refreshProfileControls(obj)
            try
                modelId=obj.Controller.State.ModelId;
                problemId=obj.Controller.State.ProblemId;
                profiles=obj.ProfileRegistry.profilesForProblem(modelId,problemId);
                if isempty(profiles),return,end
                ids=cellfun(@(item)item.Id,profiles,'UniformOutput',false);
                labels=cellfun(@(item)item.Label,profiles,'UniformOutput',false);
                fallback=obj.ProfileRegistry.defaultProfile(modelId,problemId).Id;
                preferred=obj.Preferences.visualizationProfile( ...
                    modelId,problemId,fallback);
                if ~any(strcmp(preferred,ids)),preferred=fallback;end
                obj.VisualProfileDropDown.Items=labels;
                obj.VisualProfileDropDown.ItemsData=ids;
                obj.VisualProfileDropDown.Value=preferred;
                profile=obj.ProfileRegistry.resolve(modelId,problemId,preferred);
                obj.applyProfileControlDefaults(profile);
                obj.CurrentProfile=profile;obj.updateProfileMetadata();
            catch exception
                obj.ProfileMetadataLabel.Text=['Profile configuration error: ' exception.message];
            end
        end

        function profileChanged(obj)
            try
                modelId=obj.Controller.State.ModelId;
                problemId=obj.Controller.State.ProblemId;
                profileId=obj.VisualProfileDropDown.Value;
                obj.Preferences.setVisualizationProfile(modelId,problemId,profileId);
                profile=obj.ProfileRegistry.resolve(modelId,problemId,profileId);
                obj.CurrentProfile=profile;
                obj.applyProfileControlDefaults(profile);
                simulation=obj.Controller.State.Simulation;
                if ~isempty(simulation),obj.renderSimulation(simulation);else,obj.updateProfileMetadata();end
            catch exception,obj.reportError(exception);end
        end

        function applyProfileControlDefaults(obj,profile)
            obj.CameraFollowCheckBox.Value=fieldOr(profile.Camera,'follow',false);
            if isfield(profile.RecordingProfile,'fps')
                obj.FPSSpinner.Value=profile.RecordingProfile.fps;
            end
            obj.ForceCheckBox.Value=any(strcmp('force_vectors',profile.Overlays));
            obj.DetailedOverlayCheckBox.Value= ...
                any(strcmp('detailed_phase',profile.Overlays));
            [items,value]=groundControlDefaults(profile);
            obj.GroundStyleDropDown.Items=items;
            obj.GroundStyleDropDown.Value=value;
        end

        function visualOptionsChanged(obj)
            if isempty(obj.AnimationRenderer)||~isvalid(obj.AnimationRenderer),return,end
            try,obj.AnimationRenderer.setOptions(obj.rendererOptions());
            catch exception,obj.reportError(exception);end
        end

        function options=rendererOptions(obj)
            ground=obj.GroundStyleDropDown.Value;
            options=struct('ShowForces',logical(obj.ForceCheckBox.Value), ...
                'DetailedOverlay',logical(obj.DetailedOverlayCheckBox.Value), ...
                'GroundVisible',~strcmp(ground,'Hidden'), ...
                'CameraFollow',logical(obj.CameraFollowCheckBox.Value), ...
                'GroundStyle',lower(ground), ...
                'Palette',obj.VisualProfileDropDown.Value);
        end

        function updateProfileMetadata(obj)
            if isempty(obj.CurrentProfile)
                obj.ProfileMetadataLabel.Text='';return
            end
            obj.ProfileMetadataLabel.Text=sprintf( ...
                '%s — renderer: %s — plot profile: %s', ...
                obj.CurrentProfile.Label,obj.CurrentProfile.RendererClass, ...
                obj.CurrentProfile.PlotProfile);
        end

        function resetCamera(obj)
            if isempty(obj.AnimationRenderer)||~isvalid(obj.AnimationRenderer),return,end
            try
                obj.AnimationRenderer.resetCamera();
                obj.CameraFollowCheckBox.Value=obj.AnimationRenderer.CameraFollow;
            catch exception,obj.reportError(exception);end
        end

        function disposeAnimation(obj)
            obj.stop();
            if ~isempty(obj.AnimationPlayer)&&isvalid(obj.AnimationPlayer)
                obj.AnimationPlayer.FrameChangedFcn=[];delete(obj.AnimationPlayer);
            end
            if ~isempty(obj.AnimationRenderer)&&isvalid(obj.AnimationRenderer)
                delete(obj.AnimationRenderer);
            end
            obj.AnimationPlayer=[];obj.AnimationRenderer=[];
        end

        function renderGeneric(obj,simulation)
            obj.clearAxesOnly();
            names=obj.Controller.bodyTrajectoryNames();
            if numel(names)>=2
                plot(obj.Axes,simulation.state(names{1}),simulation.state(names{2}), ...
                    'LineWidth',2);grid(obj.Axes,'on');
                xlabel(obj.Axes,names{1},'Interpreter','none');
                ylabel(obj.Axes,names{2},'Interpreter','none');
                title(obj.Axes,[obj.Controller.State.ModelId ' trajectory'],'Interpreter','none');
            else
                text(obj.Axes,.5,.5,'No visualization plugin supplied', ...
                    'HorizontalAlignment','center');axis(obj.Axes,'off');
            end
        end

        function setAnimationTime(obj,value)
            if isempty(obj.AnimationPlayer)||~isvalid(obj.AnimationPlayer),return,end
            if obj.AnimationPlayer.IsPlaying,obj.AnimationPlayer.pause();end
            obj.AnimationPlayer.setNormalizedTime(value);
        end
        function frameChanged(obj,value,~)
            if isempty(value)||~isfinite(value),return,end
            obj.TimeSlider.Value=max(0,min(1,value));
            obj.NormalizedTimeField.Value=obj.TimeSlider.Value;
            simulation=obj.Controller.State.Simulation;if isempty(simulation),return,end
            axesList=[obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes obj.GRFAxes];time=simulation.Time;
            if strcmp(obj.TrajectoryModeDropDown.Value,'Progressive')
                upper=time(1)+obj.TimeSlider.Value*(time(end)-time(1));
                upper=max(upper,time(min(2,numel(time))));
                for index=1:numel(axesList),xlim(axesList(index),[time(1) upper]);end
            else
                for index=1:numel(axesList),xlim(axesList(index),[time(1) time(end)]);end
            end
        end
        function play(obj)
            if isempty(obj.AnimationPlayer),obj.simulate();end
            if isempty(obj.AnimationPlayer),return,end
            obj.AnimationPlayer.FPS=obj.FPSSpinner.Value;
            obj.AnimationPlayer.Speed=obj.SpeedSpinner.Value;
            obj.AnimationPlayer.Loop=obj.LoopCheckBox.Value;obj.AnimationPlayer.play();
        end
        function pause(obj),if ~isempty(obj.AnimationPlayer),obj.AnimationPlayer.pause();end,end
        function stop(obj),if ~isempty(obj.AnimationPlayer)&&isvalid(obj.AnimationPlayer),obj.AnimationPlayer.stop();end,end
        function reset(obj),if ~isempty(obj.AnimationPlayer),obj.AnimationPlayer.reset();end,end
        function recordGif(obj),obj.record('gif','*.gif','Save scientific animation',struct());end
        function recordMP4(obj),obj.record('mp4','*.mp4','Save scientific video',struct('FPS',obj.FPSSpinner.Value));end
        function recordKeyframes(obj),obj.record('keyframes',{'*.png';'*.pdf'},'Export animation keyframes',struct('NormalizedTimes',[0 .25 .5 .75 1]));end
        function record(obj,format,filter,titleText,options)
            if isempty(obj.AnimationRenderer),obj.simulate();end
            if isempty(obj.AnimationRenderer),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(filter,titleText,start);if isequal(file,0),return,end
            try
                options=obj.profileRecordingOptions(format,options);
                options.Metadata=obj.profileMetadata(['animation_' format]);
                obj.Controller.recordAnimation(format,fullfile(path,file), ...
                    obj.AnimationRenderer,options);obj.Preferences.rememberOutputFolder(path);
                obj.frameChanged(obj.AnimationPlayer.NormalizedTime,[]);
            catch exception,obj.reportError(exception);end
        end
        function recordOscillatorGif(obj)
            if isempty(obj.Controller.State.Simulation),obj.simulate();end
            if isempty(obj.Controller.State.Simulation),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.gif'),'Save oscillator GIF');
            if isequal(file,0),return,end
            try
                options=obj.profileRecordingOptions('gif',struct());
                options.Metadata=obj.profileMetadata('oscillator_gif');
                obj.Controller.recordAxesGif(obj.OscillatorAxes,@(phase)obj.updateCursor(phase), ...
                    fullfile(path,file),options);
                obj.Preferences.rememberOutputFolder(path);
                obj.updateCursor(obj.NormalizedTimeField.Value);
            catch exception,obj.reportError(exception);end
        end
        function updateCursor(obj,phase)
            delete(findobj(obj.OscillatorAxes,'Tag','OscillatorCursor'));
            cursor=xline(obj.OscillatorAxes,phase,'r-','LineWidth',2);cursor.Tag='OscillatorCursor';
        end
        function exportPlots(obj)
            if isempty(obj.Controller.State.Simulation),obj.simulate();end
            if isempty(obj.Controller.State.Simulation),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile({'*.png';'*.pdf'},'Export trajectory and force plots',start);
            if isequal(file,0),return,end
            [~,name,extension]=fileparts(file);
            axesList={obj.TorsoAxes,obj.BackLegAxes,obj.FrontLegAxes,obj.GRFAxes,obj.OscillatorAxes};
            suffix={'torso','back_legs','front_legs','grf','oscillator'};
            try
                for index=1:numel(axesList)
                    metadata=obj.profileMetadata(['plot_' suffix{index}]);
                    options=obj.profileRecordingOptions('plot', ...
                        struct('Metadata',metadata));
                    obj.Controller.exportPlot(axesList{index}, ...
                        fullfile(path,sprintf('%s_%s%s',name,suffix{index},extension)), ...
                        options);
                end
                obj.Preferences.rememberOutputFolder(path);
            catch exception,obj.reportError(exception);end
        end
        function clearPresentation(obj)
            obj.disposeAnimation();
            obj.clearAxesOnly();obj.TimeSlider.Value=0;obj.NormalizedTimeField.Value=0;
        end
        function clearAxesOnly(obj)
            values=[obj.Axes obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes obj.GRFAxes obj.OscillatorAxes];
            for index=1:numel(values),if isgraphics(values(index)),cla(values(index));end,end
        end

        function options=profileRecordingOptions(obj,format,options)
            if nargin<3||isempty(options),options=struct();end
            if isempty(obj.CurrentProfile),return,end
            recording=obj.CurrentProfile.RecordingProfile;
            if isfield(recording,'frameCount')&&~isfield(options,'FrameCount')&& ...
                    any(strcmp(format,{'gif','mp4'}))
                options.FrameCount=recording.frameCount;
            end
            if isfield(recording,'fps')
                if strcmp(format,'gif')&&~isfield(options,'DelayTime')
                    options.DelayTime=1/recording.fps;
                elseif strcmp(format,'mp4')&&~isfield(options,'FPS')
                    options.FPS=recording.fps;
                end
            end
            if isfield(recording,'dpi')&&~isfield(options,'DPI')
                options.DPI=recording.dpi;
            end
            if isfield(recording,'backgroundColor')
                options.BackgroundColor=recording.backgroundColor;
            end
        end

        function metadata=profileMetadata(obj,artifactKind)
            metadata=struct();
            if isempty(obj.CurrentProfile),return,end
            metadata=struct('schemaVersion','1.0.0', ...
                'artifactKind',artifactKind, ...
                'modelId',obj.Controller.State.ModelId, ...
                'problemId',obj.Controller.State.ProblemId, ...
                'visualizationProfile',obj.CurrentProfile.toStruct(), ...
                'createdAt',lmz.compat.Timestamp.current());
        end
    end
end

function axesHandle=tabAxes(group,titleText,tag)
tab=uitab(group,'Title',titleText);layout=uigridlayout(tab,[1 1]);
layout.Padding=[8 8 8 8];axesHandle=uiaxes(layout,'Tag',tag);
end
function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end

function [items,value]=groundControlDefaults(profile)
if strcmp(profile.Id,'clean_generic')||~isempty(profile.ScenePath)
    % Declarative scenes and clean profiles define a line ground.
    items={'Line','Hidden'};value='Line';return
end
researchProfile=any(strcmp(profile.Id,{'research_legacy','high_contrast'}));
if researchProfile&&any(strcmp('phase',profile.Layers))
    % Compound profiles with a phase layer support suppressing the hatch.
    items={'Hatched','Line','Hidden'};value='Hatched';return
end
if researchProfile
    % Remaining built-in research profiles own source-faithful hatching.
    items={'Hatched','Hidden'};value='Hatched';return
end
% Unknown custom renderers receive the conservative generic line control.
items={'Line','Hidden'};value='Line';
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
