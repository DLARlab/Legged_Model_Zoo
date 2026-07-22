classdef ContinuationTab < lmz.gui.tabs.BaseTab
    %CONTINUATIONTAB Branch tracing, live progress, and checkpoints.
    properties (SetAccess=private)
        Axes
        StatusLabel
        PointsSpinner
        CheckpointField
        ParameterDropDown
        TargetsField
        RunButton
        PauseButton
        ResumeButton
        StopButton
        HomotopyButton
        FamilyScanButton
        DirectionModeDropDown
        InitialStepField
        MinimumStepField
        MaximumStepField
        GrowthFactorField
        ShrinkFactorField
        CorrectorToleranceField
        CurvatureThresholdField
        MaximumBacktracksSpinner
        DuplicateToleranceField
        LoopToleranceField
        StagnationWindowSpinner
        FeasibilityCheckBox
        ResultNameField
        NestedTabGroup
        HomotopyPanel
        HomotopyStepPolicyDropDown
        HomotopyStepCountSpinner
        HomotopyStatusLabel
        HomotopyResultNameField
        HomotopyAddButton
        HomotopySaveButton
        FamilyPanel
        FamilyParameterDropDown
        FamilyTargetsField
        FamilyStepPolicyDropDown
        FamilySecondSeedRadiusField
        FamilyStatusLabel
        FamilyResultNameField
        FamilyAddButton
        FamilySaveButton
        LiveDiagnosticsTable
        OverlayController = []
    end
    properties (Access=private)
        LastPreviewPhase = ''
        LastPreviewIndex = NaN
        LiveAcceptedSolutions = []
        LiveRejectedDecisions = []
        RegisteredDefaultsKey = ''
    end

    methods
        function obj=ContinuationTab(parent,controller,eventBus,preferences,varargin)
            [root,hostOptions,baseArguments]= ...
                lmz.gui.layout.ComponentHost.create(parent, ...
                'Continuation','lmz-tab-continuation',varargin{:});
            obj@lmz.gui.tabs.BaseTab(root,controller,eventBus,preferences, ...
                baseArguments{:});
            obj.HostMode=hostOptions.HostMode;
            obj.OverlayController=hostOptions.OverlayController;
            obj.Id='continuation';obj.CapabilityName='continue';obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.DatasetsChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.SeedPairChanged, ...
                lmz.gui.PresentationEvents.ContinuationChanged, ...
                lmz.gui.PresentationEvents.BranchViewChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            if strcmp(obj.HostMode,'workspace')
                grid=uigridlayout(obj.Root,[3 1]);
                grid.RowHeight={84,330,38};
                controlsRow=1;tasksRow=2;statusRow=3;
                obj.Axes=[];
            else
                grid=uigridlayout(obj.Root,[4 1]);
                grid.RowHeight={'1x',84,230,38};
                controlsRow=2;tasksRow=3;statusRow=4;
                obj.Axes=uiaxes(grid,'Tag','lmz-continuation-axes');
                obj.Axes.XGrid='on';obj.Axes.YGrid='on';
                title(obj.Axes,'Live branch continuation overlay');
            end
            controls=uigridlayout(grid,[2 11]);
            place(controls,controlsRow,1);
            controls.ColumnWidth={62,64,72,92,105,65,65,65,115,'1x',105};
            label=uilabel(controls,'Text','Points');place(label,1,1);
            obj.PointsSpinner=uispinner(controls,'Limits',[3 1000],'Value',20, ...
                'Step',1,'RoundFractionalValues','on','Tag','lmz-continuation-points', ...
                'Tooltip','Maximum number of accepted continuation points.');place(obj.PointsSpinner,1,2);
            label=uilabel(controls,'Text','Direction');place(label,1,3);
            obj.DirectionModeDropDown=uidropdown(controls, ...
                'Items',{'Forward','Backward','Both'}, ...
                'ItemsData',{'forward','backward','both'}, ...
                'Value',directionDefault(obj.HostMode), ...
                'Tag','lmz-continuation-direction-mode', ...
                'Tooltip','Trace forward, backward, or in both directions.');
            place(obj.DirectionModeDropDown,1,4);
            obj.RunButton=uibutton(controls,'Text','Run continuation', ...
                'Tag','lmz-continuation-run','Tooltip','Trace from the current seed pair.', ...
                'ButtonPushedFcn',@(~,~)obj.run());place(obj.RunButton,1,5);
            obj.PauseButton=uibutton(controls,'Text','Pause','Tag','lmz-continuation-pause', ...
                'Tooltip','Pause after the current cooperative checkpoint.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.pauseCurrentRun());place(obj.PauseButton,1,6);
            obj.ResumeButton=uibutton(controls,'Text','Resume','Tag','lmz-continuation-resume', ...
                'Tooltip','Resume a paused continuation run.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.resumeCurrentRun());place(obj.ResumeButton,1,7);
            obj.StopButton=uibutton(controls,'Text','Stop','Tag','lmz-continuation-stop', ...
                'Tooltip','Request a controlled stop and retain accepted points.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.stopCurrentRun());place(obj.StopButton,1,8);
            addButton=uibutton(controls,'Text','Add result dataset', ...
                'Tag','lmz-continuation-add','ButtonPushedFcn',@(~,~)obj.addDataset());place(addButton,1,9);
            saveButton=uibutton(controls,'Text','Save result…', ...
                'Tag','lmz-continuation-save','ButtonPushedFcn',@(~,~)obj.saveResult());place(saveButton,1,11);
            label=uilabel(controls,'Text','Checkpoint');place(label,2,1);
            obj.CheckpointField=uieditfield(controls,'text','Value','', ...
                'Tag','lmz-continuation-checkpoint','Tooltip','Checkpoint path for save or resume.');place(obj.CheckpointField,2,[2 5]);
            chooseButton=uibutton(controls,'Text','Choose…','Tag','lmz-continuation-choose', ...
                'ButtonPushedFcn',@(~,~)obj.chooseCheckpoint());place(chooseButton,2,6);
            resumeFileButton=uibutton(controls,'Text','Resume file', ...
                'Tag','lmz-continuation-resume-file','ButtonPushedFcn',@(~,~)obj.resumeFile());place(resumeFileButton,2,7);
            label=uilabel(controls,'Text','Result');place(label,2,8);
            obj.ResultNameField=uieditfield(controls,'text', ...
                'Value','continuation_result','Tag','lmz-continuation-result-name', ...
                'Tooltip','Dataset name used by Add result dataset.');
            place(obj.ResultNameField,2,[9 11]);

            obj.NestedTabGroup=uitabgroup(grid, ...
                'Tag','lmz-continuation-task-tabs');
            place(obj.NestedTabGroup,tasksRow,1);
            advancedTab=uitab(obj.NestedTabGroup,'Title','1-D branch', ...
                'Tag','lmz-continuation-1d-tab');
            advanced=uigridlayout(advancedTab,[5 6]);
            advanced.RowHeight={28,28,28,28,'1x'};
            advanced.ColumnWidth={105,'1x',105,'1x',105,'1x'};
            [obj.InitialStepField,obj.MinimumStepField,obj.MaximumStepField]= ...
                tripleFields(advanced,1, ...
                {'Initial step','Minimum step','Maximum step'}, ...
                [0.05 1e-4 0.2],{'initial','minimum','maximum'});
            [obj.GrowthFactorField,obj.ShrinkFactorField, ...
                obj.CorrectorToleranceField]=tripleFields(advanced,2, ...
                {'Growth factor','Shrink factor','Corrector tolerance'}, ...
                [1.2 0.5 1e-9],{'growth','shrink','corrector-tolerance'});
            [obj.CurvatureThresholdField,obj.DuplicateToleranceField, ...
                obj.LoopToleranceField]=tripleFields(advanced,3, ...
                {'Curvature threshold','Duplicate tolerance','Loop tolerance'}, ...
                [0.35 1e-6 5e-4],{'curvature','duplicate','loop'});
            label=uilabel(advanced,'Text','Max backtracks');place(label,4,1);
            obj.MaximumBacktracksSpinner=uispinner(advanced,'Limits',[1 100], ...
                'Value',8,'Step',1,'RoundFractionalValues','on', ...
                'Tag','lmz-continuation-max-backtracks');place(obj.MaximumBacktracksSpinner,4,2);
            label=uilabel(advanced,'Text','Stagnation window');place(label,4,3);
            obj.StagnationWindowSpinner=uispinner(advanced,'Limits',[2 100], ...
                'Value',4,'Step',1,'RoundFractionalValues','on', ...
                'Tag','lmz-continuation-stagnation-window');place(obj.StagnationWindowSpinner,4,4);
            obj.FeasibilityCheckBox=uicheckbox(advanced, ...
                'Text','Require feasible points','Value',true, ...
                'Tag','lmz-continuation-require-feasible');place(obj.FeasibilityCheckBox,4,[5 6]);
            obj.LiveDiagnosticsTable=uitable(advanced, ...
                'ColumnName',{'Direction','Point','Prediction','Corrected', ...
                'Residual','Step','Curvature','Iterations','Backtracks', ...
                'Gait','Feasible','Termination','Checkpoint'}, ...
                'ColumnEditable',false(1,13), ...
                'Tag','lmz-continuation-live-diagnostics');
            place(obj.LiveDiagnosticsTable,5,[1 6]);

            homotopyTab=uitab(obj.NestedTabGroup,'Title','Parameter homotopy', ...
                'Tag','lmz-continuation-homotopy-tab');
            obj.HomotopyPanel=uigridlayout(homotopyTab,[6 4]);
            obj.HomotopyPanel.RowHeight={28,28,28,28,28,'1x'};
            obj.HomotopyPanel.ColumnWidth={125,'1x',115,'1x'};
            label=uilabel(obj.HomotopyPanel,'Text','Seed source');
            place(label,1,1);
            seedLabel=uilabel(obj.HomotopyPanel, ...
                'Text','Current solved or working point', ...
                'Tag','lmz-continuation-homotopy-seed-source');
            place(seedLabel,1,[2 4]);
            label=uilabel(obj.HomotopyPanel,'Text','Active parameter');
            place(label,2,1);
            obj.ParameterDropDown=uidropdown(obj.HomotopyPanel, ...
                'Tag','lmz-continuation-parameter', ...
                'Tooltip','Only active transport parameters are shown.');
            place(obj.ParameterDropDown,2,2);
            label=uilabel(obj.HomotopyPanel,'Text','Targets');place(label,2,3);
            obj.TargetsField=uieditfield(obj.HomotopyPanel,'text', ...
                'Value','0 0.05','Tag','lmz-continuation-targets');
            place(obj.TargetsField,2,4);
            label=uilabel(obj.HomotopyPanel,'Text','Step policy');place(label,3,1);
            obj.HomotopyStepPolicyDropDown=uidropdown(obj.HomotopyPanel, ...
                'Items',{'Explicit targets','Uniform substeps'}, ...
                'ItemsData',{'explicit_targets','uniform_substeps'}, ...
                'Value','explicit_targets', ...
                'Tag','lmz-continuation-homotopy-step-policy');
            place(obj.HomotopyStepPolicyDropDown,3,2);
            label=uilabel(obj.HomotopyPanel,'Text','Steps / segment');
            place(label,3,3);
            obj.HomotopyStepCountSpinner=uispinner(obj.HomotopyPanel, ...
                'Limits',[1 100],'Value',6,'Step',1, ...
                'RoundFractionalValues','on', ...
                'Tag','lmz-continuation-homotopy-step-count');
            place(obj.HomotopyStepCountSpinner,3,4);
            label=uilabel(obj.HomotopyPanel,'Text','Result name');place(label,4,1);
            obj.HomotopyResultNameField=uieditfield(obj.HomotopyPanel,'text', ...
                'Value','homotopy_result', ...
                'Tag','lmz-continuation-homotopy-result-name');
            place(obj.HomotopyResultNameField,4,2);
            obj.HomotopyButton=uibutton(obj.HomotopyPanel,'Text','Run homotopy', ...
                'Tag','lmz-continuation-homotopy', ...
                'ButtonPushedFcn',@(~,~)obj.runHomotopy());
            place(obj.HomotopyButton,4,[3 4]);
            obj.HomotopyAddButton=uibutton(obj.HomotopyPanel, ...
                'Text','Add to workspace', ...
                'Tag','lmz-continuation-homotopy-add', ...
                'ButtonPushedFcn',@(~,~)obj.addHomotopyDataset());
            place(obj.HomotopyAddButton,5,1);
            obj.HomotopySaveButton=uibutton(obj.HomotopyPanel, ...
                'Text','Save result…', ...
                'Tag','lmz-continuation-homotopy-save', ...
                'ButtonPushedFcn',@(~,~)obj.saveHomotopyResult());
            place(obj.HomotopySaveButton,5,2);
            obj.HomotopyStatusLabel=uilabel(obj.HomotopyPanel, ...
                'Text','Status: not run','WordWrap','on', ...
                'Tag','lmz-continuation-homotopy-status');
            place(obj.HomotopyStatusLabel,5,[3 4]);
            note=uilabel(obj.HomotopyPanel,'Text', ...
                'Seed source: current solved/working point. Results retain provenance.', ...
                'WordWrap','on');place(note,6,[1 4]);

            familyTab=uitab(obj.NestedTabGroup,'Title','Branch family', ...
                'Tag','lmz-continuation-family-tab');
            obj.FamilyPanel=uigridlayout(familyTab,[6 4]);
            obj.FamilyPanel.RowHeight={28,28,28,28,28,'1x'};
            obj.FamilyPanel.ColumnWidth={125,'1x',115,'1x'};
            label=uilabel(obj.FamilyPanel,'Text','Seed source');place(label,1,1);
            seedLabel=uilabel(obj.FamilyPanel, ...
                'Text','Current solved or working point', ...
                'Tag','lmz-continuation-family-seed-source');
            place(seedLabel,1,[2 4]);
            label=uilabel(obj.FamilyPanel,'Text','Active parameter');
            place(label,2,1);
            obj.FamilyParameterDropDown=uidropdown(obj.FamilyPanel, ...
                'Tag','lmz-continuation-family-parameter');
            place(obj.FamilyParameterDropDown,2,2);
            label=uilabel(obj.FamilyPanel,'Text','Targets');place(label,2,3);
            obj.FamilyTargetsField=uieditfield(obj.FamilyPanel,'text', ...
                'Value','0 0.05','Tag','lmz-continuation-family-targets');
            place(obj.FamilyTargetsField,2,4);
            label=uilabel(obj.FamilyPanel,'Text','Step policy');place(label,3,1);
            obj.FamilyStepPolicyDropDown=uidropdown(obj.FamilyPanel, ...
                'Items',{'Independent adaptive branches', ...
                'Registered preset targets'}, ...
                'ItemsData',{'adaptive_branches','registered_preset'}, ...
                'Value','adaptive_branches', ...
                'Tag','lmz-continuation-family-step-policy');
            place(obj.FamilyStepPolicyDropDown,3,2);
            label=uilabel(obj.FamilyPanel,'Text','Second-seed radius');
            place(label,3,3);
            obj.FamilySecondSeedRadiusField=uieditfield(obj.FamilyPanel, ...
                'numeric','Limits',[eps Inf],'Value',0.01, ...
                'Tag','lmz-continuation-family-seed-radius');
            place(obj.FamilySecondSeedRadiusField,3,4);
            label=uilabel(obj.FamilyPanel,'Text','Result name');place(label,4,1);
            obj.FamilyResultNameField=uieditfield(obj.FamilyPanel,'text', ...
                'Value','branch_family', ...
                'Tag','lmz-continuation-family-result-name');
            place(obj.FamilyResultNameField,4,2);
            obj.FamilyScanButton=uibutton(obj.FamilyPanel, ...
                'Text','Run branch-family scan', ...
                'Tag','lmz-continuation-family', ...
                'ButtonPushedFcn',@(~,~)obj.runFamily());
            place(obj.FamilyScanButton,4,[3 4]);
            obj.FamilyAddButton=uibutton(obj.FamilyPanel, ...
                'Text','Add to workspace', ...
                'Tag','lmz-continuation-family-add', ...
                'ButtonPushedFcn',@(~,~)obj.addFamilyDatasets());
            place(obj.FamilyAddButton,5,1);
            obj.FamilySaveButton=uibutton(obj.FamilyPanel, ...
                'Text','Save family…', ...
                'Tag','lmz-continuation-family-save', ...
                'ButtonPushedFcn',@(~,~)obj.saveFamilyResults());
            place(obj.FamilySaveButton,5,2);
            obj.FamilyStatusLabel=uilabel(obj.FamilyPanel, ...
                'Text','Status: not run','WordWrap','on', ...
                'Tag','lmz-continuation-family-status');
            place(obj.FamilyStatusLabel,5,[3 4]);
            note=uilabel(obj.FamilyPanel,'Text', ...
                ['A family scan repeats one-dimensional continuation at ' ...
                'registered parameter targets; it is not 2-D continuation.'], ...
                'WordWrap','on');place(note,6,[1 4]);
            obj.StatusLabel=uilabel(grid,'Text','Ready','WordWrap','on', ...
                'Tag','lmz-continuation-status');
            place(obj.StatusLabel,statusRow,1);
            obj.ActionControls={obj.RunButton addButton saveButton chooseButton ...
                resumeFileButton obj.PointsSpinner obj.CheckpointField ...
                obj.DirectionModeDropDown obj.ResultNameField ...
                obj.ParameterDropDown obj.TargetsField obj.HomotopyButton ...
                obj.HomotopyStepPolicyDropDown ...
                obj.HomotopyStepCountSpinner obj.HomotopyResultNameField ...
                obj.HomotopyAddButton obj.HomotopySaveButton ...
                obj.FamilyParameterDropDown obj.FamilyTargetsField ...
                obj.FamilyStepPolicyDropDown ...
                obj.FamilySecondSeedRadiusField obj.FamilyResultNameField ...
                obj.FamilyScanButton obj.FamilyAddButton ...
                obj.FamilySaveButton obj.InitialStepField obj.MinimumStepField ...
                obj.MaximumStepField obj.GrowthFactorField ...
                obj.ShrinkFactorField obj.CorrectorToleranceField ...
                obj.CurvatureThresholdField obj.MaximumBacktracksSpinner ...
                obj.DuplicateToleranceField obj.LoopToleranceField ...
                obj.StagnationWindowSpinner obj.FeasibilityCheckBox};
            obj.CancelControls={obj.PauseButton obj.ResumeButton obj.StopButton};
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            names=obj.Controller.homotopyParameterNames();
            if isempty(names),names={'No active transport parameter'};end
            obj.ParameterDropDown.Items=names;
            obj.FamilyParameterDropDown.Items=names;
            obj.applyRegisteredDefaults();
            if ~any(strcmp(obj.ParameterDropDown.Value,names))
                obj.ParameterDropDown.Value=names{1};
            end
            if ~any(strcmp(obj.FamilyParameterDropDown.Value,names))
                obj.FamilyParameterDropDown.Value= ...
                    obj.ParameterDropDown.Value;
            end
            obj.refreshDirectionLabels();
            obj.refreshDiagnosticColumns();
            mode=obj.Controller.State.ContinuationDirectionMode;
            if any(strcmp(mode,obj.DirectionModeDropDown.ItemsData))
                obj.DirectionModeDropDown.Value=mode;
            end
            result=obj.Controller.State.ContinuationResult;
            if isa(result,'lmz.data.ContinuationResult')
                obj.initializePlot();obj.renderResult(result);
                obj.StatusLabel.Text=sprintf('%s • %d accepted • %d rejected', ...
                    result.TerminationReason,result.Branch.pointCount(), ...
                    diagnosticField(result.Diagnostics,'rejectedAttempts',0));
            elseif isempty(obj.Controller.State.SeedPair)
                if obj.hasLocalAxes(),cla(obj.Axes);end
                obj.StatusLabel.Text='Create a seed pair in Solve / Seeds.';
            end
            obj.refreshTaskResults();
            obj.applyControlState();
        end

        function hooks=testHooks(obj)
            hooks=testHooks@lmz.gui.tabs.BaseTab(obj);hooks.Controls=obj.controlMap();
        end
    end

    methods (Static)
        function value=descriptor()
            value=struct('Id','continuation','Title','Continuation', ...
                'Purpose','Trace, pause, resume, diagnose, and save branches.');
        end
    end

    methods (Access=protected)
        function onPresentationEvents(obj,batch)
            names={batch.Name};
            continuationIndices=find(strcmp(names,lmz.gui.PresentationEvents.ContinuationChanged));
            handled=false;
            for index=continuationIndices
                payload=batch(index).Payload;
                if isstruct(payload)&&isfield(payload,'Property')&& ...
                        strcmp(payload.Property,'ContinuationPreview')
                    obj.renderPreview();handled=true;
                elseif isstruct(payload)&&isfield(payload,'Property')&& ...
                        strcmp(payload.Property,'ContinuationResult')
                    obj.refresh(batch);handled=true;
                elseif isstruct(payload)&&isfield(payload,'Property')&& ...
                        strcmp(payload.Property,'ContinuationDirectionMode')
                    obj.refreshDirectionLabels();
                    mode=obj.Controller.State.ContinuationDirectionMode;
                    if any(strcmp(mode,obj.DirectionModeDropDown.ItemsData))
                        obj.DirectionModeDropDown.Value=mode;
                    end
                    handled=true;
                elseif isstruct(payload)&&isfield(payload,'Property')&& ...
                        any(strcmp(payload.Property,{ ...
                        'HomotopyResult','FamilyScanResult'}))
                    obj.refreshTaskResults();handled=true;
                end
            end
            if ~handled&&any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.DatasetsChanged, ...
                    lmz.gui.PresentationEvents.SelectionChanged, ...
                    lmz.gui.PresentationEvents.SeedPairChanged, ...
                    lmz.gui.PresentationEvents.BranchViewChanged}))
                obj.refresh(batch);
            end
        end

        function applyControlState(obj)
            supported=false;homotopy=false;family=false;
            if isfield(obj.Capabilities,'continue'),supported=obj.Capabilities.('continue');end
            if isfield(obj.Capabilities,'parameterHomotopy'),homotopy=obj.Capabilities.parameterHomotopy;end
            if isfield(obj.Capabilities,'branchFamilyScan'),family=obj.Capabilities.branchFamilyScan;end
            enableControls(obj.ActionControls,supported&&~obj.IsBusy);
            enableControls(obj.CancelControls,obj.cancelControlsEnabled());
            setEnable(obj.HomotopyButton,homotopy&&~obj.IsBusy);
            setEnable(obj.FamilyScanButton,family&&~obj.IsBusy);
            setEnable(obj.ParameterDropDown,(homotopy||family)&&~obj.IsBusy);
            setEnable(obj.TargetsField,(homotopy||family)&&~obj.IsBusy);
            setEnable(obj.HomotopyStepPolicyDropDown,homotopy&&~obj.IsBusy);
            setEnable(obj.HomotopyStepCountSpinner,homotopy&&~obj.IsBusy);
            setEnable(obj.HomotopyResultNameField,homotopy&&~obj.IsBusy);
            setEnable(obj.HomotopyAddButton,homotopy&&~obj.IsBusy&& ...
                obj.hasHomotopyResult());
            setEnable(obj.HomotopySaveButton,homotopy&&~obj.IsBusy&& ...
                obj.hasHomotopyResult());
            setEnable(obj.FamilyParameterDropDown,family&&~obj.IsBusy);
            setEnable(obj.FamilyTargetsField,family&&~obj.IsBusy);
            setEnable(obj.FamilyStepPolicyDropDown,family&&~obj.IsBusy);
            setEnable(obj.FamilySecondSeedRadiusField,family&&~obj.IsBusy);
            setEnable(obj.FamilyResultNameField,family&&~obj.IsBusy);
            setEnable(obj.FamilyAddButton,family&&~obj.IsBusy&& ...
                obj.hasFamilyResult());
            setEnable(obj.FamilySaveButton,family&&~obj.IsBusy&& ...
                obj.hasFamilyResult());
        end

        function controls=controlMap(obj)
            controls=struct('Axes',obj.Axes,'StatusLabel',obj.StatusLabel, ...
                'PointsSpinner',obj.PointsSpinner,'CheckpointField',obj.CheckpointField, ...
                'ParameterDropDown',obj.ParameterDropDown,'TargetsField',obj.TargetsField, ...
                'RunButton',obj.RunButton,'PauseButton',obj.PauseButton, ...
                'ResumeButton',obj.ResumeButton,'StopButton',obj.StopButton, ...
                'HomotopyButton',obj.HomotopyButton,'FamilyScanButton',obj.FamilyScanButton, ...
                'HomotopyStatusLabel',obj.HomotopyStatusLabel, ...
                'HomotopyStepPolicyDropDown', ...
                obj.HomotopyStepPolicyDropDown, ...
                'HomotopyResultNameField',obj.HomotopyResultNameField, ...
                'FamilyStatusLabel',obj.FamilyStatusLabel, ...
                'FamilyStepPolicyDropDown',obj.FamilyStepPolicyDropDown, ...
                'FamilyResultNameField',obj.FamilyResultNameField, ...
                'DirectionModeDropDown',obj.DirectionModeDropDown, ...
                'NestedTabGroup',obj.NestedTabGroup, ...
                'LiveDiagnosticsTable',obj.LiveDiagnosticsTable);
        end
    end

    methods (Access=private)
        function run(obj)
            try
                if isempty(obj.Controller.State.SeedPair)
                    obj.Controller.makeAdjacentSeedPair(1,struct());
                end
                obj.initializePlot();
                options=obj.continuationOptions();
                if ~isempty(strtrim(obj.CheckpointField.Value))
                    options.CheckpointPath=obj.CheckpointField.Value;
                end
                obj.runDirection(options);
            catch exception
                obj.reportError(exception);
            end
        end

        function initializePlot(obj)
            if obj.hasLocalAxes(),cla(obj.Axes);end
            obj.LastPreviewPhase='';obj.LastPreviewIndex=NaN;
            obj.LiveAcceptedSolutions=[];obj.LiveRejectedDecisions=[];
            if isempty(obj.Controller.State.Datasets)||isempty(obj.Controller.State.SeedPair),return,end
            if ~isempty(obj.OverlayController)
                obj.OverlayController.setPair(obj.Controller.State.SeedPair);
                obj.OverlayController.clearLayer('accepted_continuation');
                obj.OverlayController.clearLayer('rejected_continuation');
            end
            if ~obj.hasLocalAxes(),return,end
            hold(obj.Axes,'on');names=obj.Controller.State.AxisVariables(1:2);
            dataset=obj.Controller.activeDataset();
            plot(obj.Axes,dataset.Branch.coordinate(names{1}), ...
                dataset.Branch.coordinate(names{2}),'Color',[.78 .78 .78], ...
                'DisplayName','source branch');
            pair=obj.Controller.State.SeedPair;
            first=[solutionCoordinate(pair.First,names{1}) solutionCoordinate(pair.First,names{2})];
            second=[solutionCoordinate(pair.Second,names{1}) solutionCoordinate(pair.Second,names{2})];
            plot(obj.Axes,[first(1) second(1)],[first(2) second(2)],'bo-', ...
                'LineWidth',1.5,'Tag','ContinuationAccepted','DisplayName','accepted');
            hold(obj.Axes,'off');grid(obj.Axes,'on');
            xlabel(obj.Axes,names{1},'Interpreter','none');ylabel(obj.Axes,names{2},'Interpreter','none');
            legend(obj.Axes,'show','Location','best');
        end

        function renderPreview(obj)
            preview=obj.Controller.State.ContinuationPreview;
            if ~isstruct(preview)||~isfield(preview,'Phase')||~isfield(preview,'State'),return,end
            phase=preview.Phase;state=preview.State;
            if isequal(obj.LastPreviewIndex,state.PointIndex)&&strcmp(obj.LastPreviewPhase,phase),return,end
            obj.LastPreviewIndex=state.PointIndex;obj.LastPreviewPhase=phase;
            names=obj.Controller.State.AxisVariables(1:2);
            switch phase
                case 'prediction'
                    if obj.hasLocalAxes()
                        delete(findobj(obj.Axes, ...
                            'Tag','ContinuationPrediction'));
                        try
                            x=predictedCoordinate(state.DecisionValues, ...
                                obj.Controller.State.SeedPair.Second,names{1});
                            y=predictedCoordinate(state.DecisionValues, ...
                                obj.Controller.State.SeedPair.Second,names{2});
                            holdState=ishold(obj.Axes);hold(obj.Axes,'on');
                            plot(obj.Axes,x,y,'kx','MarkerSize',10, ...
                                'LineWidth',2, ...
                                'Tag','ContinuationPrediction', ...
                                'DisplayName','prediction');
                            if ~holdState,hold(obj.Axes,'off');end
                        catch
                        end
                    end
                    if ~isempty(obj.OverlayController)
                        obj.OverlayController.setDecisions( ...
                            'continuation_predictor',state.DecisionValues, ...
                            obj.Controller.State.SeedPair.Second);
                    end
                    obj.StatusLabel.Text=sprintf('Predicting point %d • step %.4g', ...
                        state.PointIndex,state.StepSize);
                case 'accepted'
                    if obj.hasLocalAxes()
                        line=findobj(obj.Axes,'Tag','ContinuationAccepted');
                        if isempty(line)
                            obj.initializePlot();
                            line=findobj(obj.Axes, ...
                                'Tag','ContinuationAccepted');
                        end
                        x=solutionCoordinate(state.Solution,names{1});
                        y=solutionCoordinate(state.Solution,names{2});
                        if ~isempty(line)
                            set(line,'XData',[line.XData x], ...
                                'YData',[line.YData y]);
                        end
                    end
                    obj.LiveAcceptedSolutions=appendSolution( ...
                        obj.LiveAcceptedSolutions,state.Solution);
                    if ~isempty(obj.OverlayController)
                        obj.OverlayController.setSolutions( ...
                            'accepted_continuation',obj.LiveAcceptedSolutions);
                        obj.OverlayController.clearLayer('continuation_predictor');
                    end
                    if obj.hasLocalAxes()
                        delete(findobj(obj.Axes, ...
                            'Tag','ContinuationPrediction'));
                    end
                    obj.StatusLabel.Text=sprintf('Accepted point %d • residual %.3g • step %.4g', ...
                        state.PointIndex,state.ResidualNorm,state.StepSize);
                case 'rejected'
                    obj.StatusLabel.Text=sprintf('Rejected point %d • residual %.3g • %s', ...
                        state.PointIndex,state.ResidualNorm,state.Reason);
                    if isfield(state,'CorrectedDecision')&& ...
                            ~isempty(state.CorrectedDecision)
                        rejected=state.CorrectedDecision;
                    else
                        rejected=state.Prediction;
                    end
                    obj.LiveRejectedDecisions(:,end+1)=rejected(:);
                    if ~isempty(obj.OverlayController)
                        obj.OverlayController.setDecisions( ...
                            'rejected_continuation', ...
                            obj.LiveRejectedDecisions, ...
                            obj.Controller.State.SeedPair.Second);
                    end
            end
            obj.LiveDiagnosticsTable.Data=previewRow(phase,state, ...
                obj.CheckpointField.Value,names{1}, ...
                obj.Controller.State.SeedPair.Second);
            drawnow limitrate
        end

        function renderResult(obj,result)
            if isempty(result)||isempty(obj.Controller.State.AxisVariables),return,end
            if ~isempty(obj.OverlayController)
                obj.OverlayController.setBranch('accepted_continuation', ...
                    result.Branch);
            end
            if ~obj.hasLocalAxes(),return,end
            names=obj.Controller.State.AxisVariables(1:2);hold(obj.Axes,'on');
            plot(obj.Axes,result.Branch.coordinate(names{1}), ...
                result.Branch.coordinate(names{2}),'mo-','LineWidth',1.5, ...
                'DisplayName','result');hold(obj.Axes,'off');
        end

        function value=hasLocalAxes(obj)
            value=~strcmp(obj.HostMode,'workspace')&& ...
                ~isempty(obj.Axes)&&isgraphics(obj.Axes);
        end

        function refreshDiagnosticColumns(obj)
            names=obj.Controller.State.AxisVariables;
            if isempty(names)
                coordinateName='coordinate';
            else
                coordinateName=names{1};
            end
            columns=obj.LiveDiagnosticsTable.ColumnName;
            columns{3}=sprintf('Prediction (%s)',coordinateName);
            columns{4}=sprintf('Corrected (%s)',coordinateName);
            obj.LiveDiagnosticsTable.ColumnName=columns;
        end

        function chooseCheckpoint(obj)
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'),'Choose continuation checkpoint');
            if ~isequal(file,0),obj.CheckpointField.Value=fullfile(path,file); ...
                obj.Preferences.rememberOutputFolder(path);end
        end
        function resumeFile(obj)
            path=obj.CheckpointField.Value;
            if isempty(path)
                start=obj.Preferences.recentDataFolder(pwd);
                [file,folder]=uigetfile(fullfile(start,'*.lmz.mat'),'Resume continuation checkpoint');
                if isequal(file,0),return,end
                path=fullfile(folder,file);obj.CheckpointField.Value=path;
                obj.Preferences.rememberDataFolder(folder);
            end
            try
                obj.Controller.resumeCheckpoint(path, ...
                    struct('MaximumPoints',obj.PointsSpinner.Value));
            catch exception
                obj.reportError(exception);
            end
        end
        function addDataset(obj)
            result=obj.Controller.State.ContinuationResult;
            if isempty(result),obj.reportError(MException('lmz:GUI:ContinuationResult', ...
                    'No continuation result is available.'));return,end
            name=strtrim(obj.ResultNameField.Value);
            if isempty(name)
                stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
                name=['continuation_' stamp];
            end
            try
                obj.Controller.addBranchDataset(name,result.Branch);
            catch exception
                obj.reportError(exception);
            end
        end
        function saveResult(obj)
            result=obj.Controller.State.ContinuationResult;
            if isempty(result),obj.reportError(MException('lmz:GUI:ContinuationResult', ...
                    'No continuation result is available.'));return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'),'Save continuation branch');
            if isequal(file,0),return,end
            try
                obj.Controller.saveBranch(fullfile(path,file),result.Branch);
                obj.Preferences.rememberOutputFolder(path);
            catch exception
                obj.reportError(exception);
            end
        end
        function runHomotopy(obj)
            try
                parameter=obj.ParameterDropDown.Value;
                targets=parseNumericList(obj.TargetsField.Value);
                targets=obj.homotopyTargets(parameter,targets);
                obj.HomotopyStatusLabel.Text='Status: running';drawnow limitrate
                result=obj.Controller.runParameterHomotopy( ...
                    parameter,targets,struct('StepPolicy', ...
                    obj.HomotopyStepPolicyDropDown.Value));
                obj.renderHomotopyResult(result);
            catch exception
                obj.HomotopyStatusLabel.Text=['Status: failed — ' ...
                    exception.message];
                obj.reportError(exception);
            end
        end
        function runFamily(obj)
            try
                [parameter,targets]=obj.familyInputs();
                options=struct('SecondSeedRadius', ...
                    obj.FamilySecondSeedRadiusField.Value, ...
                    'StepPolicy',obj.FamilyStepPolicyDropDown.Value, ...
                    'ContinuationOptions', ...
                    obj.continuationOptions());
                obj.FamilyStatusLabel.Text='Status: running';drawnow limitrate
                report=obj.Controller.runBranchFamilyScan( ...
                    parameter,targets,options);
                obj.renderFamilyResult(report);
            catch exception
                obj.FamilyStatusLabel.Text=['Status: failed — ' ...
                    exception.message];
                obj.reportError(exception);
            end
        end

        function addHomotopyDataset(obj)
            result=obj.homotopyResult();
            if isempty(result),obj.reportMissingTaskResult('homotopy');return,end
            try
                obj.Controller.addBranchDataset( ...
                    resultName(obj.HomotopyResultNameField.Value, ...
                    'homotopy_result'),result.Branch);
            catch exception
                obj.reportError(exception);
            end
        end

        function saveHomotopyResult(obj)
            result=obj.homotopyResult();
            if isempty(result),obj.reportMissingTaskResult('homotopy');return,end
            name=resultName(obj.HomotopyResultNameField.Value, ...
                'homotopy_result');
            obj.saveTaskBranch(result.Branch,name,'Save homotopy branch');
        end

        function addFamilyDatasets(obj)
            report=obj.familyResult();
            if isempty(report),obj.reportMissingTaskResult('family scan');return,end
            base=resultName(obj.FamilyResultNameField.Value,'branch_family');
            try
                branches=fieldValue(report,'Branches',{});
                targets=fieldValue(report,'Targets',nan(size(branches)));
                for index=1:numel(branches)
                    if isempty(branches{index}),continue,end
                    obj.Controller.addBranchDataset( ...
                        indexedResultName(base,index,targets),branches{index});
                end
            catch exception
                obj.reportError(exception);
            end
        end

        function saveFamilyResults(obj)
            report=obj.familyResult();
            if isempty(report),obj.reportMissingTaskResult('family scan');return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            folder=uigetdir(start,'Save branch-family results');
            if isequal(folder,0),return,end
            base=resultName(obj.FamilyResultNameField.Value,'branch_family');
            try
                branches=fieldValue(report,'Branches',{});
                targets=fieldValue(report,'Targets',nan(size(branches)));
                for index=1:numel(branches)
                    if isempty(branches{index}),continue,end
                    name=indexedResultName(base,index,targets);
                    obj.Controller.saveBranch(fullfile(folder, ...
                        [name '.lmz.mat']),branches{index});
                end
                obj.Preferences.rememberOutputFolder(folder);
            catch exception
                obj.reportError(exception);
            end
        end

        function saveTaskBranch(obj,branch,name,titleText)
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,[name '.lmz.mat']),titleText);
            if isequal(file,0),return,end
            try
                obj.Controller.saveBranch(fullfile(path,file),branch);
                obj.Preferences.rememberOutputFolder(path);
            catch exception
                obj.reportError(exception);
            end
        end

        function applyRegisteredDefaults(obj)
            key=[obj.Controller.State.ModelId '|' ...
                obj.Controller.State.WorkflowId];
            if strcmp(key,obj.RegisteredDefaultsKey),return,end
            obj.RegisteredDefaultsKey=key;
            defaults=struct();
            if ismethod(obj.Controller,'continuationDefaultOptions')
                try
                    defaults=obj.Controller.continuationDefaultOptions();
                catch
                end
            end
            setNumericDefault(obj.PointsSpinner,defaults,'MaximumPoints');
            setNumericDefault(obj.InitialStepField,defaults,'InitialStep');
            setNumericDefault(obj.MinimumStepField,defaults,'MinimumStep');
            setNumericDefault(obj.MaximumStepField,defaults,'MaximumStep');
            setNumericDefault(obj.GrowthFactorField,defaults,'GrowthFactor');
            setNumericDefault(obj.ShrinkFactorField,defaults,'ShrinkFactor');
            setNumericDefault(obj.CorrectorToleranceField,defaults, ...
                'CorrectorTolerance');
            setNumericDefault(obj.CurvatureThresholdField,defaults, ...
                'CurvatureThreshold');
            setNumericDefault(obj.MaximumBacktracksSpinner,defaults, ...
                'MaxBacktracks');
            setNumericDefault(obj.DuplicateToleranceField,defaults, ...
                'DuplicateTolerance');
            setNumericDefault(obj.LoopToleranceField,defaults, ...
                'LoopClosureTolerance');
            setNumericDefault(obj.StagnationWindowSpinner,defaults, ...
                'StagnationWindow');
            if isfield(defaults,'RequireFeasible')&& ...
                    islogical(defaults.RequireFeasible)&& ...
                    isscalar(defaults.RequireFeasible)
                obj.FeasibilityCheckBox.Value=defaults.RequireFeasible;
            end
            obj.applyHomotopyPreset();obj.applyFamilyPreset();
        end

        function applyHomotopyPreset(obj)
            if ~ismethod(obj.Controller,'homotopyPreset'),return,end
            try
                preset=obj.Controller.homotopyPreset();
            catch
                return
            end
            parameter=fieldValue(preset,'parameterName','');
            if any(strcmp(parameter,obj.ParameterDropDown.Items))
                obj.ParameterDropDown.Value=parameter;
            end
            targets=fieldValue(preset,'targetValues', ...
                fieldValue(preset,'targetValue',[]));
            if ~isempty(targets),obj.TargetsField.Value=numericListText(targets);end
            setNumericDefault(obj.HomotopyStepCountSpinner,preset, ...
                'maximumPoints');
        end

        function applyFamilyPreset(obj)
            if ~ismethod(obj.Controller,'familyScanPreset'),return,end
            try
                preset=obj.Controller.familyScanPreset();
            catch
                return
            end
            parameter=fieldValue(preset,'parameterName','');
            if any(strcmp(parameter,obj.FamilyParameterDropDown.Items))
                obj.FamilyParameterDropDown.Value=parameter;
            end
            targets=fieldValue(preset,'targetValues', ...
                fieldValue(preset,'targetValue',[]));
            if ~isempty(targets)
                obj.FamilyTargetsField.Value=numericListText(targets);
            end
            radius=fieldValue(preset,'secondSeedRadius',[]);
            if isnumeric(radius)&&isscalar(radius)&&isfinite(radius)&&radius>0
                obj.FamilySecondSeedRadiusField.Value=radius;
            end
        end

        function refreshTaskResults(obj)
            homotopy=obj.homotopyResult();
            if isempty(homotopy)
                obj.HomotopyStatusLabel.Text='Status: not run';
                if ~isempty(obj.OverlayController)
                    obj.OverlayController.clearLayer('homotopy_result');
                end
            else
                obj.renderHomotopyResult(homotopy);
            end
            family=obj.familyResult();
            if isempty(family)
                obj.FamilyStatusLabel.Text='Status: not run';
                if ~isempty(obj.OverlayController)
                    obj.OverlayController.clearLayer('family_branches');
                end
            else
                obj.renderFamilyResult(family);
            end
            obj.applyControlState();
        end

        function renderHomotopyResult(obj,result)
            if ~isstruct(result)||~isfield(result,'Branch'),return,end
            completed=fieldValue(result,'Completed', ...
                result.Branch.pointCount());
            obj.HomotopyStatusLabel.Text=sprintf( ...
                'Status: complete — %d targets accepted',completed);
            if ~isempty(obj.OverlayController)
                obj.OverlayController.setBranch('homotopy_result', ...
                    result.Branch);
            end
            obj.applyControlState();
        end

        function renderFamilyResult(obj,report)
            if ~isstruct(report),return,end
            completed=fieldValue(report,'Completed',0);
            failed=fieldValue(report,'Failed',0);
            blocked=fieldValue(report,'Blocked',0);
            obj.FamilyStatusLabel.Text=sprintf( ...
                'Status: complete — %d branches, %d failed, %d blocked', ...
                completed,failed,blocked);
            if ~isempty(obj.OverlayController)
                coordinates=familyCoordinates(report, ...
                    obj.Controller.State.AxisVariables);
                if isempty(coordinates)
                    obj.OverlayController.clearLayer('family_branches');
                else
                    obj.OverlayController.setCoordinates( ...
                        'family_branches',coordinates);
                end
            end
            obj.applyControlState();
        end

        function targets=homotopyTargets(obj,parameter,targets)
            if ~strcmp(obj.HomotopyStepPolicyDropDown.Value, ...
                    'uniform_substeps')
                return
            end
            current=obj.Controller.State.WorkingSolution.parameter(parameter);
            count=obj.HomotopyStepCountSpinner.Value;expanded=[];
            for index=1:numel(targets)
                segment=linspace(current,targets(index),count+1);
                expanded=[expanded segment(2:end)]; %#ok<AGROW>
                current=targets(index);
            end
            targets=expanded;
        end

        function [parameter,targets]=familyInputs(obj)
            parameter=obj.FamilyParameterDropDown.Value;
            targets=parseNumericList(obj.FamilyTargetsField.Value);
            if ~strcmp(obj.FamilyStepPolicyDropDown.Value, ...
                    'registered_preset')|| ...
                    ~ismethod(obj.Controller,'familyScanPreset')
                return
            end
            preset=obj.Controller.familyScanPreset();
            registeredParameter=fieldValue(preset,'parameterName','');
            if any(strcmp(registeredParameter, ...
                    obj.FamilyParameterDropDown.Items))
                parameter=registeredParameter;
            end
            registeredTargets=fieldValue(preset,'targetValues',[]);
            if ~isempty(registeredTargets),targets=registeredTargets;end
        end

        function value=homotopyResult(obj)
            value=[];
            if isprop(obj.Controller.State,'HomotopyResult')
                value=obj.Controller.State.HomotopyResult;
            end
        end

        function value=familyResult(obj)
            value=[];
            if isprop(obj.Controller.State,'FamilyScanResult')
                value=obj.Controller.State.FamilyScanResult;
            end
        end

        function value=hasHomotopyResult(obj)
            value=~isempty(obj.homotopyResult());
        end

        function value=hasFamilyResult(obj)
            value=~isempty(obj.familyResult());
        end

        function reportMissingTaskResult(obj,label)
            obj.reportError(MException('lmz:GUI:ContinuationTaskResult', ...
                'No %s result is available.',label));
        end

        function options=continuationOptions(obj)
            mode=obj.DirectionModeDropDown.Value;
            options=struct('MaximumPoints',obj.PointsSpinner.Value, ...
                'BothDirections',strcmp(mode,'both'), ...
                'InitialStep',obj.InitialStepField.Value, ...
                'MinimumStep',obj.MinimumStepField.Value, ...
                'MaximumStep',obj.MaximumStepField.Value, ...
                'GrowthFactor',obj.GrowthFactorField.Value, ...
                'ShrinkFactor',obj.ShrinkFactorField.Value, ...
                'CorrectorTolerance',obj.CorrectorToleranceField.Value, ...
                'CurvatureThreshold',obj.CurvatureThresholdField.Value, ...
                'MaxBacktracks',obj.MaximumBacktracksSpinner.Value, ...
                'DuplicateTolerance',obj.DuplicateToleranceField.Value, ...
                'LoopClosureTolerance',obj.LoopToleranceField.Value, ...
                'StagnationWindow',obj.StagnationWindowSpinner.Value, ...
                'RequireFeasible',logical(obj.FeasibilityCheckBox.Value));
        end

        function result=runDirection(obj,options)
            mode=obj.DirectionModeDropDown.Value;
            if ismethod(obj.Controller,'runContinuationDirection')
                result=obj.Controller.runContinuationDirection(mode,options);return
            end
            if ~strcmp(mode,'backward')
                result=obj.Controller.runContinuation(options);return
            end
            original=obj.Controller.State.SeedPair;
            reversed=lmz.data.SolutionPair(original.Second,original.First, ...
                original.RequestedRadius,original.AchievedRadius, ...
                original.Diagnostics);
            obj.Controller.State.SeedPair=reversed;
            cleanup=onCleanup(@()restoreSeedPair(obj.Controller,original));
            result=obj.Controller.runContinuation(options);
            clear cleanup
        end

        function refreshDirectionLabels(obj)
            labels=struct('forward','Forward','backward','Backward', ...
                'both','Both');
            if ismethod(obj.Controller,'continuationDirectionLabels')
                try
                    supplied=obj.Controller.continuationDirectionLabels();
                    fields=fieldnames(labels);
                    for index=1:numel(fields)
                        if isfield(supplied,fields{index})
                            labels.(fields{index})=supplied.(fields{index});
                        end
                    end
                catch
                end
            end
            value=obj.DirectionModeDropDown.Value;
            stateValue=obj.Controller.State.ContinuationDirectionMode;
            if any(strcmp(stateValue,{'forward','backward','both'}))
                value=stateValue;
            end
            obj.DirectionModeDropDown.Items={labels.forward, ...
                labels.backward,labels.both};
            obj.DirectionModeDropDown.ItemsData= ...
                {'forward','backward','both'};
            obj.DirectionModeDropDown.Value=value;
        end
    end
end

function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end
function setEnable(control,value),state='off';if value,state='on';end;if ~isempty(control)&&all(isvalid(control)),control.Enable=state;end,end
function enableControls(controls,value),for index=1:numel(controls),setEnable(controls{index},value);end,end
function value=diagnosticField(source,name,fallback),if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end,end
function value=solutionCoordinate(solution,name)
if any(strcmp(name,solution.DecisionSchema.names())),value=solution.decision(name);elseif any(strcmp(name,solution.ParameterSchema.names())),value=solution.parameter(name);elseif isfield(solution.Observables,name),value=solution.Observables.(name);else,value=NaN;end
end
function value=predictedCoordinate(decision,reference,name)
if any(strcmp(name,reference.DecisionSchema.names())),value=decision(reference.DecisionSchema.indexOf(name));elseif any(strcmp(name,reference.ParameterSchema.names())),value=reference.parameter(name);elseif isfield(reference.Observables,name),value=reference.Observables.(name);else,value=NaN;end
end
function values=parseNumericList(text)
values=sscanf(strrep(text,',',' '),'%f').';
if isempty(values)||any(~isfinite(values)),error('lmz:GUI:Targets','Enter one or more finite numeric targets.');end
end
function value=directionDefault(hostMode)
if strcmp(hostMode,'workspace'),value='both';else,value='forward';end
end
function [first,second,third]=tripleFields(parent,row,labels,values,tags)
controls=cell(1,3);
for index=1:3
    label=uilabel(parent,'Text',labels{index});place(label,row,2*index-1);
    controls{index}=uieditfield(parent,'numeric','Limits',[eps Inf], ...
        'Value',values(index), ...
        'Tag',['lmz-continuation-' tags{index}]);
    place(controls{index},row,2*index);
end
first=controls{1};second=controls{2};third=controls{3};
end
function value=appendSolution(source,solution)
if isempty(source),value=solution;else,value=source;value(end+1)=solution;end
end
function row=previewRow(phase,state,checkpoint,coordinateName,reference)
direction=fieldText(state,'Direction',0);
point=fieldText(state,'PointIndex',NaN);
prediction=diagnosticCoordinate(state,'Predicted', ...
    {'Prediction','DecisionValues'},coordinateName,reference);
corrected=diagnosticCoordinate(state,'Corrected', ...
    {'CorrectedDecision'},coordinateName,reference);
residual=fieldText(state,'ResidualNorm',NaN);
step=fieldText(state,'StepSize',NaN);
curvature=fieldText(state,'Curvature',NaN);
iterations=fieldText(state,'CorrectorIterations',NaN);
backtracks=fieldText(state,'BacktrackingCount',0);
gait=fieldValue(state,'Gait','');
if isstruct(gait),gait=fieldValue(gait,'Abbreviation','');end
feasible=fieldValue(state,'Feasibility','');
if isstruct(feasible),feasible=fieldValue(feasible,'Valid','');end
termination=fieldValue(state,'TerminationCandidate','');
if isempty(termination)&&strcmp(phase,'rejected')
    termination=fieldValue(state,'Reason','');
end
row={direction,point,prediction,corrected,residual,step,curvature, ...
    iterations,backtracks,displayText(gait),displayText(feasible), ...
    displayText(termination),checkpoint};
end
function value=fieldValue(source,name,fallback)
value=fallback;if isstruct(source)&&isfield(source,name),value=source.(name);end
end
function value=fieldText(source,name,fallback)
value=displayText(fieldValue(source,name,fallback));
end
function value=diagnosticCoordinate(state,diagnosticName,legacyNames, ...
        coordinateName,reference)
value='';coordinates=[];
diagnostics=fieldValue(state,'CoordinateDiagnostics',struct());
if isstruct(diagnostics)&&isfield(diagnostics,'Names')&& ...
        isfield(diagnostics,diagnosticName)
    names=diagnostics.Names;
    if ischar(names),names={names};elseif isstring(names),names=cellstr(names);end
    index=find(strcmp(coordinateName,names),1);
    source=diagnostics.(diagnosticName);
    if ~isempty(index)&&isnumeric(source)&&numel(source)>=index
        coordinates=source(index);
    end
end
if isempty(coordinates)
    source=[];
    for index=1:numel(legacyNames)
        source=fieldValue(state,legacyNames{index},[]);
        if ~isempty(source),break,end
    end
    if isempty(source),return,end
    try
        coordinates=lmz.gui.branch.BranchCoordinateMapper.decisions( ...
            source,reference,{coordinateName});
    catch
        return
    end
end
if ~isempty(coordinates),value=displayText(coordinates(1));end
end
function value=displayText(source)
if ischar(source)
    value=source;
elseif isstring(source)&&isscalar(source)
    value=char(source);
elseif isnumeric(source)&&isscalar(source)
    value=sprintf('%.6g',source);
elseif islogical(source)&&isscalar(source)
    value=char(string(source));
else
    value=class(source);
end
end
function setNumericDefault(control,source,name)
if ~isstruct(source)||~isfield(source,name),return,end
value=source.(name);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value),return,end
try
    control.Value=value;
catch
end
end
function value=numericListText(values)
values=values(:).';
value=strjoin(arrayfun(@(item)sprintf('%.9g',item),values, ...
    'UniformOutput',false),' ');
end
function values=familyCoordinates(report,names)
values=[];branches=fieldValue(report,'Branches',{});
for index=1:numel(branches)
    if isempty(branches{index}),continue,end
    item=lmz.gui.branch.BranchCoordinateMapper.branch( ...
        branches{index},names);
    values=[values item nan(numel(names),1)]; %#ok<AGROW>
end
if ~isempty(values),values(:,end)=[];end
end
function value=resultName(source,fallback)
value=strtrim(char(source));if isempty(value),value=fallback;end
value=regexprep(value,'[^A-Za-z0-9_.-]+','_');
value=regexprep(value,'^_+|_+$','');
if isempty(value),value=fallback;end
end
function value=indexedResultName(base,index,targets)
suffix=sprintf('%02d',index);
if isnumeric(targets)&&numel(targets)>=index&&isfinite(targets(index))
    suffix=[suffix '_' regexprep(sprintf('%.7g',targets(index)), ...
        '[^A-Za-z0-9.-]+','_')];
end
value=resultName([base '_' suffix],'branch_family');
end
function restoreSeedPair(controller,pair)
controller.State.SeedPair=pair;
end
