classdef LeggedModelZooApp < handle
    %LEGGEDMODELZOOAPP Lifecycle and composition root for the workbench.
    properties (SetAccess=private)
        Controller
        Figure
        ModelDropDown
        ProblemDropDown
        WorkflowDropDown
        ExampleDropDown
        SimulateButton
        PaletteDropDown
        LayoutDropDown
        CapabilityLabel
        StatusArea
        TabGroup
        TabComponents = struct()
        WorkbenchShell
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
        RootGrid
        IsDisposed = false
        HeaderBusy = false
        HasExplicitLayoutPreference = false
        LayoutSynchronizationActive = false
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
            obj.HasExplicitLayoutPreference=obj.hasStoredLayoutPreference();
            if isempty(parser.Results.Controller)
                obj.selectDefaultRegisteredWorkflow();
            end
            if parser.Results.CreateFigure
                obj.buildFigure(char(parser.Results.Visible));
                obj.EventSubscription=obj.Controller.Events.subscribe({ ...
                    lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.LayoutChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.ExampleChanged, ...
                    lmz.gui.PresentationEvents.DatasetsChanged, ...
                    lmz.gui.PresentationEvents.SelectionChanged, ...
                    lmz.gui.PresentationEvents.SimulationChanged, ...
                    lmz.gui.PresentationEvents.SolveProgressChanged, ...
                    lmz.gui.PresentationEvents.SolveResultChanged, ...
                    lmz.gui.PresentationEvents.ContinuationChanged, ...
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
            obj.HasExplicitLayoutPreference=false;
            obj.PaletteDropDown.Value='default';obj.applyPalette('default');
            obj.LayoutSynchronizationActive=true;
            cleanup=onCleanup(@()obj.finishLayoutSynchronization());
            profile=obj.registeredDefaultLayoutProfile();
            obj.LayoutDropDown.Value=profile;
            obj.Controller.setLayoutProfile(profile);
            if ~strcmp(obj.WorkbenchShell.Profile.Id,profile)
                obj.rebuildLayout(profile);
            end
            obj.clearImplicitLayoutPreference();
            clear cleanup
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
            obj.Figure.AutoResizeChildren='on';
            obj.Figure.CloseRequestFcn=@(~,~)obj.closeRequested();
            lmz.gui.Accessibility.enforceMinimumWindow(obj.Figure);
            root=uigridlayout(obj.Figure,[2 1]);obj.RootGrid=root;
            root.RowHeight={82,'1x'};
            root.Padding=[8 8 8 8];root.RowSpacing=8;
            header=uigridlayout(root,[2 10]);
            header.RowHeight={32,32};
            header.ColumnWidth={145,65,'1x',65,'1x',72,'1.3x',100,110,115};
            header.Padding=[0 0 0 0];header.RowSpacing=6;header.ColumnSpacing=6;
            titleLabel=uilabel(header,'Text','Legged Model Zoo', ...
                'FontWeight','bold','FontSize',16);place(titleLabel,1,1);
            label=uilabel(header,'Text','Model');place(label,1,2);
            obj.ModelDropDown=uidropdown(header,'Items',obj.Controller.modelIds(), ...
                'Tag','lmz-model-selector','Tooltip','Select a registered legged model.', ...
                'ValueChangedFcn',@(~,~)obj.modelChanged());
            place(obj.ModelDropDown,1,3);
            label=uilabel(header,'Text','Problem');place(label,1,4);
            obj.ProblemDropDown=uidropdown(header,'Tag','lmz-problem-selector', ...
                'Tooltip','Select a problem and its scientific capability contract.', ...
                'ValueChangedFcn',@(~,~)obj.problemChanged());
            place(obj.ProblemDropDown,1,5);
            label=uilabel(header,'Text','Workflow');place(label,1,6);
            obj.WorkflowDropDown=uidropdown(header, ...
                'Tag','lmz-workflow-selector', ...
                'Tooltip','Load a declaratively registered scientific workflow.', ...
                'ValueChangedFcn',@(~,~)obj.workflowChanged());
            place(obj.WorkflowDropDown,1,[7 10]);
            label=uilabel(header,'Text','Example');place(label,2,2);
            obj.ExampleDropDown=uidropdown(header,'Tag','lmz-example-selector', ...
                'Tooltip','Select a built-in demonstration input.', ...
                'ValueChangedFcn',@(~,~)obj.exampleChanged());
            place(obj.ExampleDropDown,2,3);
            label=uilabel(header,'Text','Palette');place(label,2,4);
            obj.PaletteDropDown=uidropdown(header,'Items',{'default','high-contrast'}, ...
                'Tag','lmz-palette-selector','Tooltip','Choose the default or high-contrast palette.', ...
                'ValueChangedFcn',@(~,~)obj.paletteChanged());
            place(obj.PaletteDropDown,2,5);
            obj.PaletteDropDown.Value=obj.Preferences.palette();
            label=uilabel(header,'Text','Layout');place(label,2,6);
            profiles=lmz.gui.layout.LayoutProfileRegistry.all();
            obj.LayoutDropDown=uidropdown(header, ...
                'Items',arrayfun(@(item)item.Label,profiles,'UniformOutput',false), ...
                'ItemsData',arrayfun(@(item)item.Id,profiles,'UniformOutput',false), ...
                'Tag','lmz-layout-selector', ...
                'Tooltip','Choose the scientific workbench or classic tabs.', ...
                'ValueChangedFcn',@(~,~)obj.layoutChanged());
            place(obj.LayoutDropDown,2,7);
            obj.CapabilityLabel=uilabel(header,'Text','', ...
                'Tag','lmz-capability-label','WordWrap','on');
            place(obj.CapabilityLabel,2,1);
            obj.SimulateButton=uibutton(header,'Text','Run demo','Tag','lmz-run-demo', ...
                'Tooltip','Run the selected built-in demonstration.', ...
                'ButtonPushedFcn',@(~,~)obj.simulateDemo());
            place(obj.SimulateButton,2,8);
            resetButton=uibutton(header,'Text','Reset preferences','Tag','lmz-reset-preferences', ...
                'Tooltip','Reset window, palette, and recent-folder preferences.', ...
                'ButtonPushedFcn',@(~,~)obj.resetPreferences());
            place(resetButton,2,[9 10]);
            handlers={'ErrorHandler',@(exception)obj.showError(exception), ...
                'StatusHandler',@(message)obj.appendStatus(message)};
            profile=obj.initialLayoutProfile();obj.LayoutDropDown.Value=profile;
            obj.Controller.setLayoutProfile(profile);
            obj.WorkbenchShell=lmz.gui.layout.WorkbenchShell(root, ...
                obj.Controller,obj.Controller.Events,obj.Preferences, ...
                'ProfileId',profile,handlers{:});
            obj.clearImplicitLayoutPreference();
            obj.adoptShellComponents();
            obj.StatusArea=obj.StatusPanel.Area;
            obj.assignCompatibilityAliases();
            % Flush the requested geometry before sizing nested scroll hosts.
            obj.figureResized();
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
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.ExampleChanged}))
                obj.refreshHeader();
            end
            if any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.LayoutChanged}))
                obj.synchronizeLayoutContribution();
            end
            runIndex=find(strcmp(names,lmz.gui.PresentationEvents.RunStateChanged),1,'last');
            if ~isempty(runIndex)
                payload=batch(runIndex).Payload;
                busy=~isempty(obj.Controller.State.CurrentRun)|| ...
                    recordingIsActive(obj.Controller.State);
                if isstruct(payload)&&isfield(payload,'Busy'),busy=payload.Busy;end
                obj.setBusy(busy);
            end
            if any(ismember(names,{ ...
                    lmz.gui.PresentationEvents.SolveProgressChanged, ...
                    lmz.gui.PresentationEvents.SolveResultChanged, ...
                    lmz.gui.PresentationEvents.ContinuationChanged}))
                obj.refreshProgressDock(names);
            end
            if any(ismember(names,{ ...
                    lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.DatasetsChanged, ...
                    lmz.gui.PresentationEvents.SelectionChanged, ...
                    lmz.gui.PresentationEvents.SimulationChanged, ...
                    lmz.gui.PresentationEvents.SolveProgressChanged, ...
                    lmz.gui.PresentationEvents.SolveResultChanged, ...
                    lmz.gui.PresentationEvents.ContinuationChanged}))
                layout=obj.WorkbenchShell.Layout;
                if ismethod(layout,'refreshAnalysisViews')
                    layout.refreshAnalysisViews();
                end
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
            obj.refreshWorkflowSelector();
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
            if ~isempty(obj.WorkbenchShell)&&isvalid(obj.WorkbenchShell)
                obj.WorkbenchShell.setCapabilities(capabilities);
            end
        end

        function modelChanged(obj)
            try
                obj.Controller.selectModel(obj.ModelDropDown.Value);
            catch exception
                obj.showError(exception);
            end
        end
        function problemChanged(obj)
            try
                obj.Controller.selectProblem(obj.ProblemDropDown.Value);
            catch exception
                obj.showError(exception);
            end
        end
        function workflowChanged(obj)
            id=obj.WorkflowDropDown.Value;if isempty(id),return,end
            try
                if ~ismethod(obj.Controller,'selectWorkflow')
                    error('lmz:GUI:WorkflowController', ...
                        'This controller does not expose registered workflows.');
                end
                obj.Controller.selectWorkflow(id);
            catch exception
                obj.showError(exception);obj.refreshHeader();
            end
        end
        function exampleChanged(obj),obj.Controller.setExample(obj.ExampleDropDown.Value);end
        function simulateDemo(obj)
            try
                obj.Controller.simulate(struct());
            catch exception
                obj.showError(exception);
            end
        end
        function paletteChanged(obj)
            value=obj.PaletteDropDown.Value;obj.Preferences.setPalette(value);obj.applyPalette(value);
        end
        function layoutChanged(obj)
            try
                profile=obj.LayoutDropDown.Value;
                obj.Preferences.setLayoutProfile(profile);
                obj.HasExplicitLayoutPreference=true;
                obj.LayoutSynchronizationActive=true;
                cleanup=onCleanup(@()obj.finishLayoutSynchronization());
                obj.Controller.setLayoutProfile(profile);
                if ~strcmp(obj.WorkbenchShell.Profile.Id,profile)
                    obj.rebuildLayout(profile);
                end
                clear cleanup
            catch exception
                obj.showError(exception);
            end
        end
        function applyPalette(obj,value)
            palette=lmz.gui.Palette.named(value);
            axesHandles=[obj.Axes obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes ...
                obj.GRFAxes obj.OscillatorAxes obj.BranchAxes obj.SeedAxes ...
                obj.ContinuationAxes obj.OptimizationAxes ...
                obj.OptimizationSensitivityAxes obj.OptimizationR2Axes];
            layout=obj.WorkbenchShell.Layout;
            if isprop(layout,'FootfallAxes')
                axesHandles=[axesHandles layout.FootfallAxes ...
                    layout.RunOverlayAxes];
            end
            lmz.gui.Accessibility.applyPalette(obj.Figure,axesHandles,palette);
            obj.TabComponents.branches.setPalette(palette);
        end
        function setBusy(obj,value)
            obj.HeaderBusy=logical(value);state=~obj.HeaderBusy;
            setEnable(obj.ModelDropDown,state);setEnable(obj.ProblemDropDown,state);
            setEnable(obj.ExampleDropDown,state);setEnable(obj.PaletteDropDown,state);
            setEnable(obj.WorkflowDropDown,state&& ...
                ~isempty(obj.WorkflowDropDown.ItemsData)&& ...
                ~isempty(obj.WorkflowDropDown.Value));
            setEnable(obj.LayoutDropDown,state);
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

        function figureResized(obj)
            lmz.gui.Accessibility.enforceMinimumWindow(obj.Figure);
            % The figure-owned grid is automatically resized.  Flush that
            % layout before recomputing nested scroll content extents.
            drawnow nocallbacks
            if ~isempty(obj.WorkbenchShell)&&isvalid(obj.WorkbenchShell)
                obj.WorkbenchShell.refreshGeometry();
            end
        end

        function refreshWorkflowSelector(obj)
            ids={};descriptors=[];
            if ismethod(obj.Controller,'workflowIds')
                try
                    ids=obj.Controller.workflowIds();
                catch
                    ids={};
                end
            end
            if ismethod(obj.Controller,'workflowDescriptors')
                try
                    descriptors=obj.Controller.workflowDescriptors();
                catch
                    descriptors=[];
                end
            end
            labels=cell(size(ids));
            for index=1:numel(ids)
                labels{index}=workflowLabel(descriptors,ids{index});
            end
            if isempty(ids)
                obj.WorkflowDropDown.Items={'No registered workflow'};
                obj.WorkflowDropDown.ItemsData={''};obj.WorkflowDropDown.Value='';
                obj.WorkflowDropDown.Enable='off';return
            end
            obj.WorkflowDropDown.Items=labels;obj.WorkflowDropDown.ItemsData=ids;
            selected='';
            if isprop(obj.Controller.State,'WorkflowId')
                selected=obj.Controller.State.WorkflowId;
            end
            if ~any(strcmp(selected,ids))
                current=obj.WorkflowDropDown.Value;
                if any(strcmp(current,ids)),selected=current;else,selected=ids{1};end
            end
            obj.WorkflowDropDown.Value=selected;
            obj.WorkflowDropDown.Enable=onOff(~obj.HeaderBusy);
        end

        function refreshProgressDock(obj,eventNames)
            if isempty(obj.StatusPanel)||~isvalid(obj.StatusPanel),return,end
            solveEvent=any(strcmp(eventNames, ...
                    lmz.gui.PresentationEvents.SolveProgressChanged))|| ...
                any(strcmp(eventNames, ...
                    lmz.gui.PresentationEvents.SolveResultChanged));
            continuationEvent=any(strcmp(eventNames, ...
                lmz.gui.PresentationEvents.ContinuationChanged));
            solvePresented=false;
            if solveEvent
                progress=obj.Controller.State.SolveProgress;
                result=obj.Controller.State.SolveResult;
                if isempty(progress)&&~isempty(result)&& ...
                        isprop(result,'Progress')
                    progress=result.Progress;
                end
                if isa(progress,'lmz.data.SolveProgress')&& ...
                        ~isempty(progress.Snapshots)
                    snapshot=progress.Snapshots(end);
                    fraction=NaN;if progress.Completed,fraction=1;end
                    details=sprintf([ ...
                        'iteration=%g; functions=%g; residual=%.6g; ' ...
                        'step=%.6g; optimality=%.6g; accepted=%s'], ...
                        snapshot.Iteration,snapshot.FunctionCount, ...
                        snapshot.ScaledResidual,snapshot.StepNorm, ...
                        snapshot.FirstOrderOptimality, ...
                        logicalText(snapshot.Accepted));
                    obj.StatusPanel.setProgress(plainStage(snapshot.Stage), ...
                        fraction,details);
                    solvePresented=true;
                elseif ~isempty(result)&&isprop(result,'Evaluation')
                    details=sprintf('residual=%.6g; exit=%g', ...
                        result.Evaluation.ScaledResidualNorm,result.ExitFlag);
                    obj.StatusPanel.setProgress('Solve complete',1,details);
                    solvePresented=true;
                end
            end
            if continuationEvent
                result=obj.Controller.State.ContinuationResult;
                if ~isempty(result)
                    details=sprintf('%d accepted points; termination=%s', ...
                        result.Branch.pointCount(),result.TerminationReason);
                    obj.StatusPanel.setProgress( ...
                        'Continuation complete',1,details);
                    return
                end
                preview=obj.Controller.State.ContinuationPreview;
                if isstruct(preview)&&isfield(preview,'Phase')&& ...
                        isfield(preview,'State')
                    state=preview.State;point=structField(state, ...
                        'PointIndex',NaN);
                    fraction=NaN;
                    if isfinite(point)&&isfield(obj.TabComponents,'continuation')
                        maximum=obj.TabComponents.continuation.PointsSpinner.Value;
                        fraction=min(0.99,max(0,point/max(1,maximum)));
                    end
                    details=sprintf( ...
                        'point=%g; residual=%.6g; step=%.6g; reason=%s', ...
                        point,structField(state,'ResidualNorm',NaN), ...
                        structField(state,'StepSize',NaN), ...
                        displayText(structField(state,'Reason','')));
                    obj.StatusPanel.setProgress( ...
                        ['Continuation ' strrep(preview.Phase,'_',' ')], ...
                        fraction,details);
                    return
                end
            end
            if (solveEvent||continuationEvent)&&~solvePresented
                % Clearing transient run state resets only the current dock;
                % timestamped status history remains intact.
                obj.StatusPanel.clearProgress();
            end
        end

        function profile=registeredDefaultLayoutProfile(obj)
            capabilities=obj.Controller.capabilities();
            hasBranchData=~isempty(obj.Controller.State.Datasets);
            profile=lmz.gui.layout.LayoutProfileRegistry.defaultFor( ...
                capabilities,hasBranchData);
            try
                session=obj.Controller.State.WorkflowSession;
                if isa(session,'lmz.workflow.WorkflowSession')
                    candidate=session.Descriptor.LayoutProfileId;
                elseif ~isempty(obj.Controller.State.WorkbenchContribution)
                    candidate=obj.Controller.State. ...
                        WorkbenchContribution.LayoutProfileId;
                else
                    contribution=obj.Controller.workbenchContribution();
                    candidate=contribution.LayoutProfileId;
                end
                if any(strcmp(candidate, ...
                        lmz.gui.layout.LayoutProfileRegistry.list()))
                    profile=candidate;
                end
            catch
            end
        end

        function profile=initialLayoutProfile(obj)
            fallback=obj.registeredDefaultLayoutProfile();
            profile=fallback;
            if obj.HasExplicitLayoutPreference
                profile=obj.Preferences.layoutProfile(fallback);
            end
            if ~any(strcmp(profile,lmz.gui.layout.LayoutProfileRegistry.list()))
                profile=fallback;
            end
        end

        function rebuildLayout(obj,profile,force)
            if nargin<3,force=false;end
            obj.WorkbenchShell.select(profile,force);obj.adoptShellComponents();
            obj.assignCompatibilityAliases();obj.applyPalette(obj.Preferences.palette());
            capabilities=obj.Controller.capabilities();
            obj.WorkbenchShell.setCapabilities(capabilities);
            obj.setBusy(obj.HeaderBusy);obj.appendStatus( ...
                ['Layout changed to ' strrep(profile,'_',' ') '.']);
        end

        function synchronizeLayoutContribution(obj)
            if obj.LayoutSynchronizationActive||isempty(obj.WorkbenchShell)|| ...
                    ~isvalid(obj.WorkbenchShell)
                return
            end
            obj.LayoutSynchronizationActive=true;
            cleanup=onCleanup(@()obj.finishLayoutSynchronization());
            profile=obj.initialLayoutProfile();
            if ~strcmp(obj.Controller.layoutProfileId(),profile)
                obj.Controller.setLayoutProfile(profile);
            end
            force=~strcmp(obj.WorkbenchShell.Profile.Id,profile);
            if ~force&&strcmp(profile,'scientific_workbench')&& ...
                    isprop(obj.WorkbenchShell.Layout,'Contribution')
                current=obj.WorkbenchShell.Layout.Contribution;
                target=obj.Controller.workbenchContribution();
                force=~sameContribution(current,target);
            end
            obj.LayoutDropDown.Value=profile;
            if force
                obj.rebuildLayout(profile,true);
            end
            obj.clearImplicitLayoutPreference();
            clear cleanup
        end

        function value=hasStoredLayoutPreference(obj)
            value=false;
            try
                namespace=obj.Preferences.Namespace;
                if ~ispref(namespace,'LayoutProfile'),return,end
                candidate=getpref(namespace,'LayoutProfile');
                if isstring(candidate)&&isscalar(candidate)
                    candidate=char(candidate);
                end
                value=ischar(candidate)&&any(strcmp(candidate, ...
                    lmz.gui.layout.LayoutProfileRegistry.list()));
            catch
                value=false;
            end
        end

        function clearImplicitLayoutPreference(obj)
            if obj.HasExplicitLayoutPreference,return,end
            try
                namespace=obj.Preferences.Namespace;
                if ispref(namespace,'LayoutProfile')
                    rmpref(namespace,'LayoutProfile');
                end
            catch
            end
        end

        function finishLayoutSynchronization(obj)
            obj.LayoutSynchronizationActive=false;
        end

        function adoptShellComponents(obj)
            obj.TabComponents=obj.WorkbenchShell.ComponentMap;
            obj.StatusPanel=obj.WorkbenchShell.StatusPanel;
            obj.StatusArea=obj.StatusPanel.Area;
            obj.TabGroup=obj.WorkbenchShell.TabGroup;
        end

        function selectDefaultRegisteredWorkflow(obj)
            try
                registry=lmz.workflow.WorkflowRegistry.fromModelRegistry( ...
                    obj.Controller.Registry);
                values=registry.Workflows;selected=[];
                for index=1:numel(values)
                    value=values(index);
                    if strcmp(value.LayoutProfileId,'scientific_workbench')&& ...
                            workflowAllows(value,'solve')&& ...
                            (workflowAllows(value,'continuation')|| ...
                            workflowAllows(value,'continue'))
                        selected=value;break
                    end
                end
                if isempty(selected),return,end
                obj.Controller.selectModel(selected.ModelId);
                if ismethod(obj.Controller,'selectWorkflow')
                    obj.Controller.selectWorkflow(selected.Id);
                end
            catch
                % The controller's ordinary registered-model default remains valid.
            end
        end

        function dispose(obj)
            if obj.IsDisposed,return,end
            obj.IsDisposed=true;
            if ~isempty(obj.Figure)&&isvalid(obj.Figure)
                try
                    obj.Preferences.setWindowPosition(obj.Figure.Position);
                catch
                end
            end
            obj.Controller.stopCurrentRun();obj.Controller.stopRecording();
            if ~isempty(obj.EventSubscription)&&isvalid(obj.EventSubscription)
                delete(obj.EventSubscription);
            end
            obj.EventSubscription=[];
            obj.TabComponents=struct();
            if ~isempty(obj.WorkbenchShell)&&isvalid(obj.WorkbenchShell)
                delete(obj.WorkbenchShell);
            end
            obj.WorkbenchShell=[];
            obj.StatusPanel=[];
            if ~isempty(obj.Figure)&&isvalid(obj.Figure)
                obj.Figure.CloseRequestFcn=[];obj.Figure.SizeChangedFcn=[];
                obj.Figure.WindowButtonMotionFcn=[];obj.Figure.KeyPressFcn=[];
                delete(obj.Figure);
            end
            obj.Figure=[];
            obj.RootGrid=[];
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
function place(control,row,column)
control.Layout.Row=row;control.Layout.Column=column;
end
function value=onOff(condition)
if condition,value='on';else,value='off';end
end
function label=workflowLabel(descriptors,id)
label=strrep(id,'_',' ');
if isempty(descriptors),return,end
if iscell(descriptors),values=descriptors;else,values=num2cell(descriptors(:));end
for index=1:numel(values)
    value=values{index};candidate=recordField(value,'Id', ...
        recordField(value,'id',''));
    if strcmp(candidate,id)
        label=recordField(value,'Label',recordField(value,'label',label));
        return
    end
end
end
function value=workflowAllows(descriptor,id)
if ismethod(descriptor,'allows'),value=descriptor.allows(id);return,end
steps=recordField(descriptor,'AllowedSteps', ...
    recordField(descriptor,'allowedSteps',{}));
value=any(strcmp(id,steps));
end
function value=recordField(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name),value=source.(name);return,end
if isobject(source)&&isprop(source,name),value=source.(name);end
end
function value=sameContribution(first,second)
value=false;
if ~isa(first,'lmz.workflow.WorkbenchContribution')|| ...
        ~isa(second,'lmz.workflow.WorkbenchContribution')
    return
end
value=isequaln(first.toStruct(),second.toStruct());
end
function value=plainStage(source)
value=strrep(char(source),'_',' ');
if ~isempty(value),value(1)=upper(value(1));end
end
function value=logicalText(source)
if source,value='true';else,value='false';end
end
function value=structField(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name),value=source.(name);end
end
function value=displayText(source)
if ischar(source)
    value=source;
elseif isstring(source)&&isscalar(source)
    value=char(source);
elseif isnumeric(source)&&isscalar(source)
    value=sprintf('%.6g',source);
else
    value=class(source);
end
end
