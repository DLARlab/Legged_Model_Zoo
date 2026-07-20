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
        SimulateButton
        AnimationRenderer
        AnimationPlayer
    end

    methods
        function obj=SimulationTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Physical Simulation','Tag','lmz-tab-simulation');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
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
            rootGrid.RowHeight={'1x','1x',82};rootGrid.ColumnWidth={'1.12x','1x'};
            obj.Axes=uiaxes(rootGrid,'Tag','lmz-simulation-animation');place(obj.Axes,[1 2],1);
            title(obj.Axes,'Select and simulate a branch point');
            trajectories=uitabgroup(rootGrid);place(trajectories,1,2);
            obj.TorsoAxes=tabAxes(trajectories,'Torso','lmz-simulation-torso');
            obj.BackLegAxes=tabAxes(trajectories,'Back legs','lmz-simulation-back');
            obj.FrontLegAxes=tabAxes(trajectories,'Front legs','lmz-simulation-front');
            lower=uigridlayout(rootGrid,[1 2]);place(lower,2,2);
            obj.GRFAxes=uiaxes(lower,'Tag','lmz-simulation-grf');
            obj.OscillatorAxes=uiaxes(lower,'Tag','lmz-simulation-oscillator');
            controls=uigridlayout(rootGrid,[2 12]);place(controls,3,[1 2]);
            controls.RowHeight={30,34};
            controls.ColumnWidth={110,'1x','1x','1x',72,36,64,42,48,55,70,100};
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
            obj.ForceCheckBox=uicheckbox(controls,'Text','Forces','Value',true, ...
                'Tag','lmz-simulation-forces','Tooltip','Show physical force arrows when supported.', ...
                'ValueChangedFcn',@(~,~)obj.forceChanged());place(obj.ForceCheckBox,1,11);
            obj.TrajectoryModeDropDown=uidropdown(controls,'Items',{'Complete','Progressive'}, ...
                'Value','Complete','Tag','lmz-simulation-trajectory-mode', ...
                'Tooltip','Show complete trajectories or reveal them progressively.', ...
                'ValueChangedFcn',@(~,~)obj.frameChanged(obj.NormalizedTimeField.Value,[]));place(obj.TrajectoryModeDropDown,1,12);
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
                    'ButtonPushedFcn',@(~,~)callbacks{index}());place(buttons{index},2,index);
            end
            obj.SimulateButton=buttons{5};
            obj.ActionControls=[buttons(1:10) {obj.TimeSlider obj.NormalizedTimeField ...
                obj.FPSSpinner obj.SpeedSpinner obj.LoopCheckBox obj.ForceCheckBox ...
                obj.TrajectoryModeDropDown}];
            obj.CancelControls=buttons(11);
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
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
            obj.stop();
            if ~isempty(obj.AnimationPlayer)&&isvalid(obj.AnimationPlayer)
                obj.AnimationPlayer.FrameChangedFcn=[];delete(obj.AnimationPlayer);
            end
            obj.AnimationPlayer=[];obj.AnimationRenderer=[];
        end

        function controls=controlMap(obj)
            controls=struct('Axes',obj.Axes,'TorsoAxes',obj.TorsoAxes, ...
                'BackLegAxes',obj.BackLegAxes,'FrontLegAxes',obj.FrontLegAxes, ...
                'GRFAxes',obj.GRFAxes,'OscillatorAxes',obj.OscillatorAxes, ...
                'TimeSlider',obj.TimeSlider,'NormalizedTimeField',obj.NormalizedTimeField, ...
                'FPSSpinner',obj.FPSSpinner,'SimulateButton',obj.SimulateButton);
        end
    end

    methods (Access=private)
        function simulate(obj)
            try,obj.Controller.simulateWorkingSolution();catch exception,obj.reportError(exception);end
        end

        function renderSimulation(obj,simulation)
            obj.stop();obj.AnimationRenderer=[];obj.AnimationPlayer=[];
            modelId=obj.Controller.State.ModelId;
            try
                switch modelId
                    case 'slip_quadruped'
                        obj.AnimationRenderer=lmzmodels.slip_quadruped.QuadrupedRenderer(obj.Axes,simulation);
                        lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotTorso(obj.TorsoAxes,simulation);
                        lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotBackLegs(obj.BackLegAxes,simulation);
                        lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotFrontLegs(obj.FrontLegAxes,simulation);
                        lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotGRF(obj.GRFAxes,simulation);
                        lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotOscillator(obj.OscillatorAxes,simulation);
                    case 'slip_biped'
                        obj.AnimationRenderer=lmzmodels.slip_biped.BipedRenderer(obj.Axes,simulation);
                        lmzmodels.slip_biped.BipedPlotProvider.plotBody(obj.TorsoAxes,simulation);
                        lmzmodels.slip_biped.BipedPlotProvider.plotLegs(obj.BackLegAxes,simulation);
                        lmzmodels.slip_biped.BipedPlotProvider.plotFootfall(obj.FrontLegAxes,simulation);
                        lmzmodels.slip_biped.BipedPlotProvider.plotGRF(obj.GRFAxes,simulation);
                        lmzmodels.slip_biped.BipedPlotProvider.plotFootfall(obj.OscillatorAxes,simulation);
                    case 'slip_quad_load'
                        obj.AnimationRenderer=lmzmodels.slip_quad_load.QuadLoadRenderer(obj.Axes,simulation);
                        lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotBodyAndLegs(obj.TorsoAxes,simulation);
                        lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotLoad(obj.BackLegAxes,simulation);
                        lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotFootfall(obj.FrontLegAxes,simulation);
                        lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotGRF(obj.GRFAxes,simulation);
                        lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotTugline(obj.OscillatorAxes,simulation);
                    otherwise
                        if ~obj.renderPlugin(simulation),obj.renderGeneric(simulation);end
                end
                if ~isempty(obj.AnimationRenderer)&&isprop(obj.AnimationRenderer,'ShowForces')
                    obj.AnimationRenderer.ShowForces=obj.ForceCheckBox.Value;
                end
                if ~isempty(obj.AnimationRenderer)
                    obj.AnimationPlayer=lmz.gui.AnimationController(simulation,obj.AnimationRenderer);
                    obj.AnimationPlayer.FrameChangedFcn=@(value,index)obj.frameChanged(value,index);
                    obj.frameChanged(0,1);
                end
            catch exception
                obj.renderGeneric(simulation);obj.reportError(exception);
            end
        end

        function rendered=renderPlugin(obj,simulation)
            rendered=false;model=obj.Controller.Registry.createModel(obj.Controller.State.ModelId);
            if ~ismethod(model,'getVisualizationPlugin'),return,end
            plugin=model.getVisualizationPlugin();if isempty(plugin),return,end
            if ismethod(plugin,'createRenderer')
                obj.AnimationRenderer=plugin.createRenderer(obj.Axes,simulation);
            end
            if ismethod(plugin,'plotSimulation')
                plugin.plotSimulation(struct('Torso',obj.TorsoAxes,'Back',obj.BackLegAxes, ...
                    'Front',obj.FrontLegAxes,'Forces',obj.GRFAxes, ...
                    'Auxiliary',obj.OscillatorAxes),simulation);
            end
            rendered=~isempty(obj.AnimationRenderer)||ismethod(plugin,'plotSimulation');
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
        function forceChanged(obj)
            if ~isempty(obj.AnimationRenderer)&&isprop(obj.AnimationRenderer,'ShowForces')
                obj.AnimationRenderer.ShowForces=obj.ForceCheckBox.Value;
                obj.AnimationRenderer.updateFrame(obj.AnimationRenderer.CurrentIndex);
            end
        end
        function recordGif(obj),obj.record('gif','*.gif','Save scientific animation',struct('FrameCount',40));end
        function recordMP4(obj),obj.record('mp4','*.mp4','Save scientific video',struct('FrameCount',60,'FPS',obj.FPSSpinner.Value));end
        function recordKeyframes(obj),obj.record('keyframes',{'*.png';'*.pdf'},'Export animation keyframes',struct('NormalizedTimes',[0 .25 .5 .75 1]));end
        function record(obj,format,filter,titleText,options)
            if isempty(obj.AnimationRenderer),obj.simulate();end
            if isempty(obj.AnimationRenderer),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(filter,titleText,start);if isequal(file,0),return,end
            try
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
                obj.Controller.recordAxesGif(obj.OscillatorAxes,@(phase)obj.updateCursor(phase), ...
                    fullfile(path,file),struct('FrameCount',40));
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
                    obj.Controller.exportPlot(axesList{index}, ...
                        fullfile(path,sprintf('%s_%s%s',name,suffix{index},extension)));
                end
                obj.Preferences.rememberOutputFolder(path);
            catch exception,obj.reportError(exception);end
        end
        function clearPresentation(obj)
            obj.stop();obj.AnimationRenderer=[];obj.AnimationPlayer=[];
            obj.clearAxesOnly();obj.TimeSlider.Value=0;obj.NormalizedTimeField.Value=0;
        end
        function clearAxesOnly(obj)
            values=[obj.Axes obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes obj.GRFAxes obj.OscillatorAxes];
            for index=1:numel(values),if isgraphics(values(index)),cla(values(index));end,end
        end
    end
end

function axesHandle=tabAxes(group,titleText,tag)
tab=uitab(group,'Title',titleText);layout=uigridlayout(tab,[1 1]);
layout.Padding=[8 8 8 8];axesHandle=uiaxes(layout,'Tag',tag);
end
function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end
