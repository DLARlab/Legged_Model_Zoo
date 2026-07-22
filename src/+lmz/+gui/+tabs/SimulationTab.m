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
        StridePlanTable
        StrideCountSpinner
        CompletionPolicyDropDown
        FailurePolicyDropDown
        EnergyNeutralCheckBox
        EnergyDiagnosticLabel
        UsePreviousButton
        ApplyOverridesButton
        ValidateEnergyButton
        SolveTimingsButton
        CompletePlanButton
        ValidatePlanButton
        SimulatePlanButton
        SavePlanButton
        LoadPlanButton
        LastStridePreferenceKey = ''
        AnimationRenderer
        AnimationPlayer
        ProfileRegistry
        RendererFactory
        CurrentProfile
    end

    methods
        function obj=SimulationTab(parent,controller,eventBus,preferences,varargin)
            [root,hostOptions,baseArguments]= ...
                lmz.gui.layout.ComponentHost.create(parent, ...
                'Physical Simulation','lmz-tab-simulation',varargin{:});
            obj@lmz.gui.tabs.BaseTab(root,controller,eventBus,preferences, ...
                baseArguments{:});
            obj.HostMode=hostOptions.HostMode;
            obj.ProfileRegistry=lmz.viz.VisualizationProfileRegistry(controller.Registry);
            obj.RendererFactory=lmz.viz.RendererFactory( ...
                controller.Registry,obj.ProfileRegistry);
            obj.Id='simulation';obj.CapabilityName='simulate';obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.SimulationChanged, ...
                lmz.gui.PresentationEvents.StridePlanChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            rootGrid=uigridlayout(obj.Root,[3 2]);
            rootGrid.RowHeight={'1x','1x',225};rootGrid.ColumnWidth={'1.12x','1x'};
            obj.Axes=uiaxes(rootGrid,'Tag','lmz-simulation-animation');place(obj.Axes,[1 2],1);
            title(obj.Axes,'Select and simulate a branch point');
            trajectories=uitabgroup(rootGrid);place(trajectories,1,2);
            obj.TorsoAxes=tabAxes(trajectories,'Torso','lmz-simulation-torso');
            obj.BackLegAxes=tabAxes(trajectories,'Back legs','lmz-simulation-back');
            obj.FrontLegAxes=tabAxes(trajectories,'Front legs','lmz-simulation-front');
            planTab=uitab(trajectories,'Title','Stride plan');
            planGrid=uigridlayout(planTab,[1 1]);
            planGrid.Padding=[0 0 0 0];
            obj.StridePlanTable=uitable(planGrid, ...
                'ColumnName',{'#','Start → stop','Status','Physical (read-only)', ...
                'Post-swing stiffness','Event-time seed','Energy Δ','Declared work'}, ...
                'ColumnEditable',[false false false false true true false true], ...
                'Tag','lmz-simulation-stride-plan');
            lower=uigridlayout(rootGrid,[1 2]);place(lower,2,2);
            obj.GRFAxes=uiaxes(lower,'Tag','lmz-simulation-grf');
            obj.OscillatorAxes=uiaxes(lower,'Tag','lmz-simulation-oscillator');
            controls=uigridlayout(rootGrid,[6 12]);place(controls,3,[1 2]);
            controls.RowHeight={30,30,22,30,34,34};
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
            label=uilabel(controls,'Text','Requested strides');place(label,4,1);
            obj.StrideCountSpinner=uispinner(controls,'Limits',[1 100], ...
                'Value',1,'Step',1,'RoundFractionalValues','on', ...
                'Tag','lmz-simulation-stride-count', ...
                'ValueChangedFcn',@(~,~)obj.strideSettingsChanged());
            place(obj.StrideCountSpinner,4,2);
            obj.CompletionPolicyDropDown=uidropdown(controls, ...
                'Items',lmz.multistride.MissingStridePolicy.values(), ...
                'Value','error_if_missing', ...
                'Tag','lmz-simulation-completion-policy', ...
                'ValueChangedFcn',@(~,~)obj.strideSettingsChanged());
            place(obj.CompletionPolicyDropDown,4,[3 4]);
            obj.FailurePolicyDropDown=uidropdown(controls, ...
                'Items',{'return_partial','error'},'Value','return_partial', ...
                'Tag','lmz-simulation-failure-policy', ...
                'ValueChangedFcn',@(~,~)obj.strideSettingsChanged());
            place(obj.FailurePolicyDropDown,4,[5 6]);
            obj.EnergyNeutralCheckBox=uicheckbox(controls, ...
                'Text','Energy neutral only','Value',true, ...
                'Tag','lmz-simulation-energy-neutral', ...
                'ValueChangedFcn',@(~,~)obj.strideSettingsChanged());
            place(obj.EnergyNeutralCheckBox,4,[7 8]);
            obj.EnergyDiagnosticLabel=uilabel(controls, ...
                'Text','Energy transition: not evaluated', ...
                'Tag','lmz-simulation-energy-diagnostic');
            place(obj.EnergyDiagnosticLabel,4,[9 12]);

            obj.UsePreviousButton=uibutton(controls,'Text','Use previous defaults', ...
                'Tag','lmz-simulation-use-previous', ...
                'ButtonPushedFcn',@(~,~)obj.usePreviousDefaults());
            place(obj.UsePreviousButton,5,[1 2]);
            obj.ApplyOverridesButton=uibutton(controls,'Text','Apply overrides', ...
                'Tag','lmz-simulation-apply-overrides', ...
                'ButtonPushedFcn',@(~,~)obj.applyStrideOverrides());
            place(obj.ApplyOverridesButton,5,3);
            obj.ValidateEnergyButton=uibutton(controls,'Text','Validate energy', ...
                'Tag','lmz-simulation-validate-energy', ...
                'ButtonPushedFcn',@(~,~)obj.validateEnergy());
            place(obj.ValidateEnergyButton,5,4);
            obj.SolveTimingsButton=uibutton(controls,'Text','Solve timings', ...
                'Tag','lmz-simulation-solve-timings', ...
                'ButtonPushedFcn',@(~,~)obj.solveMissingTimings());
            place(obj.SolveTimingsButton,5,[5 6]);
            obj.CompletePlanButton=uibutton(controls,'Text','Complete remaining', ...
                'Tag','lmz-simulation-complete-plan', ...
                'ButtonPushedFcn',@(~,~)obj.completePlan());
            place(obj.CompletePlanButton,5,[7 8]);
            obj.ValidatePlanButton=uibutton(controls,'Text','Validate', ...
                'Tag','lmz-simulation-validate-plan', ...
                'ButtonPushedFcn',@(~,~)obj.validatePlan());
            place(obj.ValidatePlanButton,5,9);
            obj.SimulatePlanButton=uibutton(controls,'Text','Simulate plan', ...
                'Tag','lmz-simulation-simulate-plan', ...
                'ButtonPushedFcn',@(~,~)obj.simulatePlan());
            place(obj.SimulatePlanButton,5,10);
            obj.SavePlanButton=uibutton(controls,'Text','Save plan…', ...
                'Tag','lmz-simulation-save-plan', ...
                'ButtonPushedFcn',@(~,~)obj.savePlan());place(obj.SavePlanButton,5,11);
            obj.LoadPlanButton=uibutton(controls,'Text','Load plan…', ...
                'Tag','lmz-simulation-load-plan', ...
                'ButtonPushedFcn',@(~,~)obj.loadPlan());place(obj.LoadPlanButton,5,12);
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
                    'ButtonPushedFcn',@(~,~)callbacks{index}());
                place(buttons{index},6,index);
            end
            obj.SimulateButton=buttons{5};
            obj.ActionControls=[buttons(1:10) {obj.TimeSlider obj.NormalizedTimeField ...
                obj.FPSSpinner obj.SpeedSpinner obj.LoopCheckBox obj.ForceCheckBox ...
                obj.TrajectoryModeDropDown obj.VisualProfileDropDown ...
                obj.DetailedOverlayCheckBox obj.GroundStyleDropDown ...
                obj.CameraFollowCheckBox obj.ResetCameraButton ...
                obj.StrideCountSpinner obj.CompletionPolicyDropDown ...
                obj.FailurePolicyDropDown obj.EnergyNeutralCheckBox ...
                obj.UsePreviousButton obj.ApplyOverridesButton ...
                obj.ValidateEnergyButton obj.SolveTimingsButton ...
                obj.CompletePlanButton obj.ValidatePlanButton ...
                obj.SimulatePlanButton obj.SavePlanButton obj.LoadPlanButton}];
            obj.CancelControls=buttons(11);
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            obj.refreshProfileControls();
            obj.refreshStridePlan();
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
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.SelectionChanged, ...
                    lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                    lmz.gui.PresentationEvents.SimulationChanged, ...
                    lmz.gui.PresentationEvents.StridePlanChanged}))
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
                'ProfileMetadataLabel',obj.ProfileMetadataLabel, ...
                'StridePlanTable',obj.StridePlanTable, ...
                'StrideCountSpinner',obj.StrideCountSpinner, ...
                'CompletionPolicyDropDown',obj.CompletionPolicyDropDown, ...
                'FailurePolicyDropDown',obj.FailurePolicyDropDown, ...
                'EnergyNeutralCheckBox',obj.EnergyNeutralCheckBox, ...
                'EnergyDiagnosticLabel',obj.EnergyDiagnosticLabel, ...
                'UsePreviousButton',obj.UsePreviousButton, ...
                'ApplyOverridesButton',obj.ApplyOverridesButton, ...
                'ValidateEnergyButton',obj.ValidateEnergyButton, ...
                'SolveTimingsButton',obj.SolveTimingsButton, ...
                'CompletePlanButton',obj.CompletePlanButton, ...
                'ValidatePlanButton',obj.ValidatePlanButton, ...
                'SimulatePlanButton',obj.SimulatePlanButton, ...
                'SavePlanButton',obj.SavePlanButton, ...
                'LoadPlanButton',obj.LoadPlanButton);
        end
    end

    methods (Access=private)
        function refreshStridePlan(obj)
            state=obj.Controller.State;
            key=[state.ModelId '/' state.ProblemId];
            if ~strcmp(key,obj.LastStridePreferenceKey)
                obj.LastStridePreferenceKey=key;
                fallback=stridePreferenceStruct(state);
                preferred=obj.Preferences.stridePreference( ...
                    state.ModelId,state.ProblemId,fallback);
                if ~isequaln(preferred,fallback)
                    try
                        obj.Controller.setStrideSettings( ...
                            preferred.RequestedStrideCount, ...
                            preferred.CompletionPolicy, ...
                            preferred.FailurePolicy, ...
                            logical(preferred.EnergyNeutralOnly));
                        state=obj.Controller.State;
                    catch
                    end
                end
            end
            obj.StrideCountSpinner.Value=state.RequestedStrideCount;
            obj.CompletionPolicyDropDown.Value=state.CompletionPolicy;
            obj.FailurePolicyDropDown.Value=state.FailurePolicy;
            obj.EnergyNeutralCheckBox.Value=state.EnergyNeutralOnly;
            rows=cell(state.RequestedStrideCount,8);plan=state.StridePlan;
            for index=1:state.RequestedStrideCount
                if ~isempty(plan)&&index<=plan.CompletedStrideCount
                    spec=plan.StrideSpecs(index);
                    sections=[spec.StartSectionId ' → ' spec.StopSectionId];
                    stiffness=controlText(spec.ControlParameters, ...
                        'PostSwingStiffness');
                    physical=physicalText(spec.PhysicalParameters);
                    schedule=scheduleText(spec.EventSchedule);
                    energy=energyText(spec.Diagnostics);
                    rows(index,:)={index,sections,spec.CompletionStatus, ...
                        physical,stiffness,schedule,energy,declaredWorkAt( ...
                        state.DeclaredWork,index)};
                else
                    rows(index,:)={index,'configured sections','missing', ...
                        'copied on completion','', '',NaN, ...
                        declaredWorkAt(state.DeclaredWork,index)};
                end
            end
            obj.StridePlanTable.Data=rows;
            result=state.MultiStrideResult;
            validation=state.PlanValidation;
            if (isempty(result)||isempty(result.EnergyDiagnostics))&& ...
                    isstruct(validation)&& ...
                    isfield(validation,'EnergyDiagnostics')&& ...
                    ~isempty(validation.EnergyDiagnostics)&& ...
                    isfield(validation,'Valid')&&validation.Valid
                obj.EnergyDiagnosticLabel.Text=sprintf( ...
                    'Energy preview accepted • %d pending transitions', ...
                    numel(validation.EnergyDiagnostics));
            elseif isempty(result)||isempty(result.EnergyDiagnostics)
                obj.EnergyDiagnosticLabel.Text= ...
                    'Energy transition: not evaluated';
            else
                obj.EnergyDiagnosticLabel.Text=sprintf( ...
                    'Energy policy %s • %d transitions accepted', ...
                    result.Plan.EnergyPolicy.Id,numel(result.EnergyDiagnostics));
            end
        end

        function strideSettingsChanged(obj)
            try
                obj.Controller.setStrideSettings( ...
                    obj.StrideCountSpinner.Value, ...
                    obj.CompletionPolicyDropDown.Value, ...
                    obj.FailurePolicyDropDown.Value, ...
                    logical(obj.EnergyNeutralCheckBox.Value));
                state=obj.Controller.State;
                obj.Preferences.setStridePreference(state.ModelId, ...
                    state.ProblemId,stridePreferenceStruct(state));
            catch exception
                obj.refreshStridePlan();obj.reportError(exception);
            end
        end

        function usePreviousDefaults(obj)
            obj.CompletionPolicyDropDown.Value='carry_forward';
            obj.strideSettingsChanged();
            obj.reportStatus('Missing strides will copy the previous defaults.');
        end

        function applyStrideOverrides(obj)
            try
                rows=obj.StridePlanTable.Data;overrides=struct();
                work=zeros(size(rows,1),1);
                for index=1:size(rows,1)
                    item=struct();stiffness=parseNumericVector(rows{index,5});
                    if ~isempty(stiffness)
                        if numel(stiffness)~=4
                            error('lmz:GUI:StrideStiffness', ...
                                'Post-swing stiffness requires four values.');
                        end
                        item.PostSwingStiffness=stiffness(:);
                    end
                    timing=parseNumericVector(rows{index,6});
                    if ~isempty(timing)
                        item.EventSchedule=obj.scheduleOverride(index,timing);
                    end
                    if ~isempty(fieldnames(item))
                        overrides.(sprintf('stride%d',index))=item;
                    end
                    value=rows{index,8};
                    if ischar(value)||isstring(value),value=str2double(value);end
                    if isempty(value),value=0;end
                    if ~isnumeric(value)||~isscalar(value)||~isfinite(value)
                        error('lmz:GUI:DeclaredWork', ...
                            'Declared work must be one finite value per stride.');
                    end
                    work(index)=value;
                end
                obj.Controller.setStrideOverrides(overrides,work);
            catch exception
                obj.refreshStridePlan();obj.reportError(exception);
            end
        end

        function schedule=scheduleOverride(obj,index,timing)
            schedule=obj.Controller.strideScheduleOverride(index,timing);
        end

        function validateEnergy(obj)
            try
                obj.applyStrideOverrides();
                report=obj.Controller.validateStrideEnergy();
                obj.EnergyDiagnosticLabel.Text=sprintf( ...
                    'Energy preview accepted • %d pending transitions', ...
                    numel(report.EnergyDiagnostics));
            catch exception
                obj.reportError(exception);
            end
        end

        function solveMissingTimings(obj)
            obj.CompletionPolicyDropDown.Value= ...
                'carry_forward_and_solve_timings';
            obj.strideSettingsChanged();obj.completePlan();
        end

        function completePlan(obj)
            try
                obj.applyStrideOverrides();
                obj.Controller.completeStridePlan();
            catch exception
                obj.reportError(exception);
            end
        end

        function validatePlan(obj)
            try,obj.Controller.validateStridePlan(false); ...
            catch exception,obj.reportError(exception);end
        end

        function simulatePlan(obj)
            try,obj.Controller.simulateStridePlan(); ...
            catch exception,obj.reportError(exception);end
        end

        function savePlan(obj)
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'), ...
                'Save stride plan');
            if isequal(file,0),return,end
            try
                obj.Controller.saveStridePlan(fullfile(path,file));
                obj.Preferences.rememberOutputFolder(path);
            catch exception,obj.reportError(exception);end
        end

        function loadPlan(obj)
            start=obj.Preferences.recentDataFolder(pwd);
            [file,path]=uigetfile(fullfile(start,'*.lmz.mat'), ...
                'Load stride plan');
            if isequal(file,0),return,end
            try
                obj.Controller.loadStridePlan(fullfile(path,file));
                obj.Preferences.rememberDataFolder(path);
            catch exception,obj.reportError(exception);end
        end

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

function value=controlText(source,name)
value='';
if isstruct(source)&&isfield(source,name)
    item=source.(name);value=mat2str(item(:).',6);
end
end

function value=physicalText(source)
value='';
if ~isstruct(source),return,end
parts=cell(1,2);count=0;
if isfield(source,'QuadrupedInvariantVector')
    count=count+1;
    parts{count}=sprintf('quadruped %s', ...
        mat2str(source.QuadrupedInvariantVector(:).',4));
end
if isfield(source,'LoadVector')
    count=count+1;
    parts{count}=sprintf('load %s', ...
        mat2str(source.LoadVector(:).',4));
end
if count==0
    names=fieldnames(source);
    parts=names(:).';
else
    parts=parts(1:count);
end
value=strjoin(parts,'; ');
end

function value=scheduleText(source)
value='';
if isobject(source)&&ismethod(source,'toStruct'),source=source.toStruct();end
if isstruct(source)&&isfield(source,'Times')
    value=mat2str(source.Times(:).',6);
elseif isstruct(source)&&isfield(source,'Occurrences')
    stored=source.Occurrences;
    if isstruct(stored),stored=num2cell(stored);end
    times=cellfun(@(item)item.Time,stored);
    value=mat2str([times(:);source.ReturnTime].',6);
end
end

function value=energyText(source)
value=NaN;
if ~isstruct(source),return,end
energy=fieldOr(source,'Energy',struct());
if isstruct(energy)
    value=fieldOr(energy,'EnergyDelta',fieldOr(energy,'Delta',NaN));
end
end

function value=declaredWorkAt(source,index)
if isempty(source),value=0; ...
elseif isscalar(source),value=source; ...
elseif index<=numel(source),value=source(index); ...
else,value=0;end
end

function values=parseNumericVector(source)
if isempty(source),values=zeros(0,1);return,end
if isnumeric(source)
    values=source(:);
elseif ischar(source)||(isstring(source)&&isscalar(source))
    text=char(source);
    if isempty(strtrim(text)),values=zeros(0,1);return,end
    if isempty(regexp(text,'^[0-9eE+\-.,;\[\]() \t]+$','once'))
        error('lmz:GUI:NumericVector', ...
            'Vector text may contain only finite numeric literals.');
    end
    text=regexprep(text,'[\[\](),;]',' ');
    values=sscanf(text,'%f');
else
    error('lmz:GUI:NumericVector','Vector entry must be numeric text.');
end
if any(~isfinite(values))
    error('lmz:GUI:NumericVector','Vector values must be finite.');
end
end

function value=stridePreferenceStruct(state)
value=struct('RequestedStrideCount',state.RequestedStrideCount, ...
    'CompletionPolicy',state.CompletionPolicy, ...
    'FailurePolicy',state.FailurePolicy, ...
    'EnergyNeutralOnly',state.EnergyNeutralOnly);
end
