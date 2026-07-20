classdef LeggedModelZooApp < handle
    %LEGGEDMODELZOOAPP Lifecycle and composition root for the workbench.
    properties (SetAccess=private)
        Controller
        Figure
        ModelDropDown
        ProblemDropDown
        ExampleDropDown
        SimulateButton
        PaletteDropDown
        CapabilityLabel
        StatusArea
        TabGroup
        TabComponents = struct()
        Preferences
    end

    % Read-only compatibility aliases. Complete ownership remains in each tab.
    properties (SetAccess=private, Hidden)
        SendToSolveButton
        SendToContinuationButton
        SolveButton
        ContinuationButton
        HomotopyButton
        FamilyScanButton
        OptimizationButton
        OptimizationCancelButton
        Axes
        TorsoAxes
        BackLegAxes
        FrontLegAxes
        GRFAxes
        OscillatorAxes
        TimeSlider
        NormalizedTimeField
        AnimationFPSSpinner
        AnimationSpeedSpinner
        AnimationLoopCheckBox
        AnimationForceCheckBox
        TrajectoryModeDropDown
        BranchAxes
        RoadMapBranchDropDown
        BranchDatasetList
        BranchVisibilityCheckBox
        BranchMetadataArea
        BranchXDropDown
        BranchYDropDown
        BranchZDropDown
        BranchDimensionDropDown
        BranchAzimuthSpinner
        BranchElevationSpinner
        BranchAspectDropDown
        BranchXLimitsField
        BranchYLimitsField
        BranchZLimitsField
        BranchIndexSpinner
        BranchPercentSlider
        SolutionTable
        EventTable
        ParameterTable
        ObservableTable
        ResidualTable
        DiagnosticsTable
        ProvenanceTable
        ProjectionModeDropDown
        SolveStatus
        SeedAxes
        SeedDirectionDropDown
        SeedFirstIndexSpinner
        SeedSecondIndexSpinner
        SecondSeedRadiusField
        NoiseMagnitudeField
        NoiseSeedSpinner
        ContinuationAxes
        ContinuationStatus
        ContinuationPointsSpinner
        ContinuationCheckpointField
        ContinuationParameterDropDown
        ContinuationTargetsField
        OptimizationAxes
        OptimizationSensitivityAxes
        OptimizationR2Axes
    end
    properties (Access=private)
        StatusPanel
        EventSubscription
        IsDisposed = false
        HeaderBusy = false
    end

    methods
        function obj=LeggedModelZooApp(varargin)
            parser=inputParser;
            addParameter(parser,'CreateFigure',true,@islogical);
            addParameter(parser,'Controller',[], ...
                @(value)isempty(value)||isa(value,'lmz.gui.AppController'));
            addParameter(parser,'Preferences',[], ...
                @(value)isempty(value)||isa(value,'lmz.gui.PreferencesStore'));
            addParameter(parser,'Visible','on', ...
                @(value)ischar(value)||(isstring(value)&&isscalar(value)));
            parse(parser,varargin{:});
            obj.Controller=parser.Results.Controller;
            if isempty(obj.Controller),obj.Controller=lmz.gui.AppController();end
            obj.Preferences=parser.Results.Preferences;
            if isempty(obj.Preferences),obj.Preferences=lmz.gui.PreferencesStore();end
            if any(strcmp('slip_quadruped',obj.Controller.modelIds()))&& ...
                    isempty(parser.Results.Controller)
                obj.Controller.selectModel('slip_quadruped');
            end
            if parser.Results.CreateFigure
                obj.buildFigure(char(parser.Results.Visible));
                obj.EventSubscription=obj.Controller.Events.subscribe({ ...
                    lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.ExampleChanged, ...
                    lmz.gui.PresentationEvents.RunStateChanged, ...
                    lmz.gui.PresentationEvents.StatusChanged}, ...
                    @(batch)obj.presentationChanged(batch));
                obj.refreshHeader();obj.applyPalette(obj.Preferences.palette());
                obj.appendStatus(obj.Controller.State.Status);
            end
        end

        function component=tab(obj,id)
            id=char(id);
            if ~isfield(obj.TabComponents,id)
                error('lmz:GUI:Tab','Unknown tab %s.',id);
            end
            component=obj.TabComponents.(id);
        end

        function resetPreferences(obj)
            obj.Preferences.reset();
            obj.PaletteDropDown.Value='default';obj.applyPalette('default');
            obj.appendStatus('Preferences reset to defaults.');
        end

        function delete(obj)
            obj.dispose();
        end
    end

    methods (Access=private)
        function buildFigure(obj,visible)
            position=obj.Preferences.windowPosition([40 40 1460 900]);
            obj.Figure=uifigure('Name','Legged Model Zoo — Scientific Workbench', ...
                'Position',position,'Visible',visible,'Tag','lmz-main-window');
            obj.Figure.AutoResizeChildren='off';
            obj.Figure.CloseRequestFcn=@(~,~)obj.closeRequested();
            obj.Figure.SizeChangedFcn=@(~,~)lmz.gui.Accessibility.enforceMinimumWindow(obj.Figure);
            lmz.gui.Accessibility.enforceMinimumWindow(obj.Figure);
            root=uigridlayout(obj.Figure,[3 1]);root.RowHeight={52,'1x',88};
            header=uigridlayout(root,[1 10]);
            header.ColumnWidth={145,155,68,155,62,145,100,'1x',105,105};
            uilabel(header,'Text','Legged Model Zoo','FontWeight','bold','FontSize',16);
            obj.ModelDropDown=uidropdown(header,'Items',obj.Controller.modelIds(), ...
                'Tag','lmz-model-selector','Tooltip','Select a registered legged model.', ...
                'ValueChangedFcn',@(~,~)obj.modelChanged());
            uilabel(header,'Text','Problem');
            obj.ProblemDropDown=uidropdown(header,'Tag','lmz-problem-selector', ...
                'Tooltip','Select a problem and its scientific capability contract.', ...
                'ValueChangedFcn',@(~,~)obj.problemChanged());
            uilabel(header,'Text','Example');
            obj.ExampleDropDown=uidropdown(header,'Tag','lmz-example-selector', ...
                'Tooltip','Select a built-in demonstration input.', ...
                'ValueChangedFcn',@(~,~)obj.exampleChanged());
            obj.PaletteDropDown=uidropdown(header,'Items',{'default','high-contrast'}, ...
                'Tag','lmz-palette-selector','Tooltip','Choose the default or high-contrast palette.', ...
                'ValueChangedFcn',@(~,~)obj.paletteChanged());
            obj.PaletteDropDown.Value=obj.Preferences.palette();
            obj.CapabilityLabel=uilabel(header,'Text','','Tag','lmz-capability-label');
            obj.SimulateButton=uibutton(header,'Text','Run demo','Tag','lmz-run-demo', ...
                'Tooltip','Run the selected built-in demonstration.', ...
                'ButtonPushedFcn',@(~,~)obj.simulateDemo());
            uibutton(header,'Text','Reset preferences','Tag','lmz-reset-preferences', ...
                'Tooltip','Reset window, palette, and recent-folder preferences.', ...
                'ButtonPushedFcn',@(~,~)obj.resetPreferences());
            obj.TabGroup=uitabgroup(root,'Tag','lmz-main-tabs');
            handlers={'ErrorHandler',@(exception)obj.showError(exception), ...
                'StatusHandler',@(message)obj.appendStatus(message)};
            bus=obj.Controller.Events;
            obj.TabComponents.simulation=lmz.gui.tabs.SimulationTab(obj.TabGroup, ...
                obj.Controller,bus,obj.Preferences,handlers{:});
            obj.TabComponents.branches=lmz.gui.tabs.BranchTab(obj.TabGroup, ...
                obj.Controller,bus,obj.Preferences,handlers{:});
            obj.TabComponents.solution=lmz.gui.tabs.SolutionTab(obj.TabGroup, ...
                obj.Controller,bus,obj.Preferences,handlers{:});
            obj.TabComponents.solve=lmz.gui.tabs.SolveTab(obj.TabGroup, ...
                obj.Controller,bus,obj.Preferences,handlers{:});
            obj.TabComponents.continuation=lmz.gui.tabs.ContinuationTab(obj.TabGroup, ...
                obj.Controller,bus,obj.Preferences,handlers{:});
            obj.TabComponents.optimization=lmz.gui.tabs.OptimizationTab(obj.TabGroup, ...
                obj.Controller,bus,obj.Preferences,handlers{:});
            obj.StatusPanel=lmz.gui.components.StatusPanel(root);
            obj.StatusArea=obj.StatusPanel.Area;
            obj.assignCompatibilityAliases();
        end

        function assignCompatibilityAliases(obj)
            simulation=obj.TabComponents.simulation;branches=obj.TabComponents.branches;
            solution=obj.TabComponents.solution;solveTab=obj.TabComponents.solve;
            continuation=obj.TabComponents.continuation;optimization=obj.TabComponents.optimization;
            obj.Axes=simulation.Axes;obj.TorsoAxes=simulation.TorsoAxes;
            obj.BackLegAxes=simulation.BackLegAxes;obj.FrontLegAxes=simulation.FrontLegAxes;
            obj.GRFAxes=simulation.GRFAxes;obj.OscillatorAxes=simulation.OscillatorAxes;
            obj.TimeSlider=simulation.TimeSlider;obj.NormalizedTimeField=simulation.NormalizedTimeField;
            obj.AnimationFPSSpinner=simulation.FPSSpinner;obj.AnimationSpeedSpinner=simulation.SpeedSpinner;
            obj.AnimationLoopCheckBox=simulation.LoopCheckBox;obj.AnimationForceCheckBox=simulation.ForceCheckBox;
            obj.TrajectoryModeDropDown=simulation.TrajectoryModeDropDown;
            obj.BranchAxes=branches.Axes;obj.RoadMapBranchDropDown=branches.CatalogDropDown;
            obj.BranchDatasetList=branches.DatasetList;obj.BranchVisibilityCheckBox=branches.VisibilityCheckBox;
            obj.BranchMetadataArea=branches.MetadataArea;obj.BranchXDropDown=branches.XDropDown;
            obj.BranchYDropDown=branches.YDropDown;obj.BranchZDropDown=branches.ZDropDown;
            obj.BranchDimensionDropDown=branches.DimensionDropDown;
            obj.BranchAzimuthSpinner=branches.AzimuthSpinner;obj.BranchElevationSpinner=branches.ElevationSpinner;
            obj.BranchAspectDropDown=branches.AspectDropDown;obj.BranchXLimitsField=branches.XLimitsField;
            obj.BranchYLimitsField=branches.YLimitsField;obj.BranchZLimitsField=branches.ZLimitsField;
            obj.BranchIndexSpinner=branches.IndexSpinner;obj.BranchPercentSlider=branches.PercentSlider;
            obj.SolutionTable=solution.SolutionTable;obj.EventTable=solution.EventTable;
            obj.ParameterTable=solution.ParameterTable;obj.ObservableTable=solution.ObservableTable;
            obj.ResidualTable=solution.ResidualTable;obj.DiagnosticsTable=solution.DiagnosticsTable;
            obj.ProvenanceTable=solution.ProvenanceTable;obj.ProjectionModeDropDown=solution.ProjectionModeDropDown;
            obj.SendToSolveButton=solution.SendToSolveButton;
            obj.SendToContinuationButton=solution.SendToContinuationButton;
            obj.SolveButton=solveTab.SolveButton;obj.SolveStatus=solveTab.StatusLabel;
            obj.SeedAxes=solveTab.SeedAxes;obj.SeedDirectionDropDown=solveTab.DirectionDropDown;
            obj.SeedFirstIndexSpinner=solveTab.FirstIndexSpinner;
            obj.SeedSecondIndexSpinner=solveTab.SecondIndexSpinner;
            obj.SecondSeedRadiusField=solveTab.SecondSeedRadiusField;
            obj.NoiseMagnitudeField=solveTab.NoiseMagnitudeField;obj.NoiseSeedSpinner=solveTab.NoiseSeedSpinner;
            obj.ContinuationButton=continuation.RunButton;obj.HomotopyButton=continuation.HomotopyButton;
            obj.FamilyScanButton=continuation.FamilyScanButton;obj.ContinuationAxes=continuation.Axes;
            obj.ContinuationStatus=continuation.StatusLabel;obj.ContinuationPointsSpinner=continuation.PointsSpinner;
            obj.ContinuationCheckpointField=continuation.CheckpointField;
            obj.ContinuationParameterDropDown=continuation.ParameterDropDown;
            obj.ContinuationTargetsField=continuation.TargetsField;
            obj.OptimizationButton=optimization.RunButton;
            obj.OptimizationCancelButton=optimization.CancelButton;
            obj.OptimizationAxes=optimization.ObjectiveAxes;
            obj.OptimizationSensitivityAxes=optimization.SensitivityAxes;
            obj.OptimizationR2Axes=optimization.R2Axes;
        end

        function presentationChanged(obj,batch)
            if obj.IsDisposed,return,end
            names={batch.Name};
            if any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.ExampleChanged}))
                obj.refreshHeader();
            end
            runIndex=find(strcmp(names,lmz.gui.PresentationEvents.RunStateChanged),1,'last');
            if ~isempty(runIndex)
                payload=batch(runIndex).Payload;
                busy=~isempty(obj.Controller.State.CurrentRun)|| ...
                    recordingIsActive(obj.Controller.State);
                if isstruct(payload)&&isfield(payload,'Busy'),busy=payload.Busy;end
                obj.setBusy(busy);
            end
            statusIndex=find(strcmp(names,lmz.gui.PresentationEvents.StatusChanged),1,'last');
            if ~isempty(statusIndex)
                obj.appendStatus(obj.Controller.State.Status,batch(statusIndex).Timestamp);
            end
        end

        function refreshHeader(obj)
            if isempty(obj.Figure)||~isvalid(obj.Figure),return,end
            modelId=obj.Controller.State.ModelId;obj.ModelDropDown.Value=modelId;
            problems=obj.Controller.problemIds();manifest=obj.Controller.Registry.getManifest(modelId);
            labels=cell(size(problems));
            for index=1:numel(problems)
                descriptor=problemDescriptor(manifest,problems{index});
                labels{index}=lmz.gui.components.ProblemBadge.selectorLabel(descriptor);
            end
            obj.ProblemDropDown.Items=labels;obj.ProblemDropDown.ItemsData=problems;
            problemId=obj.Controller.State.ProblemId;
            if any(strcmp(problemId,problems)),obj.ProblemDropDown.Value=problemId;end
            examples=obj.Controller.builtInExamples();
            if isempty(examples),examples={'default_stride'};end
            obj.ExampleDropDown.Items=examples;
            if any(strcmp(obj.Controller.State.ExampleId,examples))
                obj.ExampleDropDown.Value=obj.Controller.State.ExampleId;
            else
                obj.ExampleDropDown.Value=examples{1};obj.Controller.setExample(examples{1});
            end
            descriptor=problemDescriptor(manifest,problemId);capabilities=obj.Controller.capabilities();
            obj.CapabilityLabel.Text=sprintf('%s  |  %s', ...
                lmz.gui.components.ProblemBadge.label(descriptor),capabilityText(capabilities));
            setEnable(obj.SimulateButton,capabilities.simulate&& ...
                obj.Controller.canSimulateDemo()&&~obj.HeaderBusy);
            components=struct2cell(obj.TabComponents);
            for index=1:numel(components),components{index}.setCapabilities(capabilities);end
        end

        function modelChanged(obj)
            try,obj.Controller.selectModel(obj.ModelDropDown.Value);catch exception,obj.showError(exception);end
        end
        function problemChanged(obj)
            try,obj.Controller.selectProblem(obj.ProblemDropDown.Value);catch exception,obj.showError(exception);end
        end
        function exampleChanged(obj),obj.Controller.setExample(obj.ExampleDropDown.Value);end
        function simulateDemo(obj)
            try,obj.Controller.simulate(struct());catch exception,obj.showError(exception);end
        end
        function paletteChanged(obj)
            value=obj.PaletteDropDown.Value;obj.Preferences.setPalette(value);obj.applyPalette(value);
        end
        function applyPalette(obj,value)
            palette=lmz.gui.Palette.named(value);
            axesHandles=[obj.Axes obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes ...
                obj.GRFAxes obj.OscillatorAxes obj.BranchAxes obj.SeedAxes ...
                obj.ContinuationAxes obj.OptimizationAxes ...
                obj.OptimizationSensitivityAxes obj.OptimizationR2Axes];
            lmz.gui.Accessibility.applyPalette(obj.Figure,axesHandles,palette);
            obj.TabComponents.branches.setPalette(palette);
        end
        function setBusy(obj,value)
            obj.HeaderBusy=logical(value);state=~obj.HeaderBusy;
            setEnable(obj.ModelDropDown,state);setEnable(obj.ProblemDropDown,state);
            setEnable(obj.ExampleDropDown,state);setEnable(obj.PaletteDropDown,state);
            capabilities=obj.Controller.capabilities();setEnable(obj.SimulateButton, ...
                state&&capabilities.simulate&&obj.Controller.canSimulateDemo());
        end
        function appendStatus(obj,message,timestamp)
            if nargin<3,timestamp=[];end
            if isempty(obj.StatusPanel),return,end
            obj.StatusPanel.append(message,'info','',timestamp);
        end
        function showError(obj,exception)
            details=lmz.gui.components.ErrorDetailsDialog.technicalDetails(exception);
            if ~isempty(obj.StatusPanel)
                obj.StatusPanel.append(exception.message,'error',details);
            end
            lmz.gui.components.ErrorDetailsDialog.show(obj.Figure,exception);
        end
        function closeRequested(obj)
            obj.dispose();
        end
        function dispose(obj)
            if obj.IsDisposed,return,end
            obj.IsDisposed=true;
            if ~isempty(obj.Figure)&&isvalid(obj.Figure)
                try,obj.Preferences.setWindowPosition(obj.Figure.Position);catch,end
            end
            obj.Controller.stopCurrentRun();obj.Controller.stopRecording();
            if ~isempty(obj.EventSubscription)&&isvalid(obj.EventSubscription)
                delete(obj.EventSubscription);
            end
            obj.EventSubscription=[];
            names=fieldnames(obj.TabComponents);
            for index=1:numel(names)
                component=obj.TabComponents.(names{index});
                if ~isempty(component)&&isvalid(component),component.dispose();end
            end
            obj.TabComponents=struct();
            if ~isempty(obj.StatusPanel)&&isvalid(obj.StatusPanel),delete(obj.StatusPanel);end
            obj.StatusPanel=[];
            if ~isempty(obj.Figure)&&isvalid(obj.Figure)
                obj.Figure.CloseRequestFcn=[];obj.Figure.SizeChangedFcn=[];
                obj.Figure.WindowButtonMotionFcn=[];obj.Figure.KeyPressFcn=[];
                delete(obj.Figure);
            end
            obj.Figure=[];
        end
    end
end

function descriptor=problemDescriptor(manifest,problemId)
descriptor=struct('id',problemId,'maturity','experimental', ...
    'validationStatus','untested','capabilities',struct());
if ~isfield(manifest,'problemDescriptors'),return,end
values=manifest.problemDescriptors;if ~iscell(values),values=num2cell(values);end
for index=1:numel(values)
    if isstruct(values{index})&&isfield(values{index},'id')&& ...
            strcmp(values{index}.id,problemId)
        descriptor=values{index};return
    end
end
end
function textValue=capabilityText(capabilities)
names={'simulate','solve','continue','optimize'};shown={'Simulate','Solve','Continue','Optimize'};
selected=false(size(names));
for index=1:numel(names),selected(index)=isfield(capabilities,names{index})&&capabilities.(names{index});end
labels=shown(selected);
if isempty(labels),textValue='Inspect only';else,textValue=strjoin(labels,' · ');end
end
function setEnable(control,value)
state='off';if value,state='on';end
if ~isempty(control)&&isvalid(control)&&isprop(control,'Enable'),control.Enable=state;end
end
function value=recordingIsActive(state)
recording=state.RecordingState;
value=isstruct(recording)&&isscalar(recording)&& ...
    isfield(recording,'Active')&&islogical(recording.Active)&& ...
    isscalar(recording.Active)&&recording.Active;
end
