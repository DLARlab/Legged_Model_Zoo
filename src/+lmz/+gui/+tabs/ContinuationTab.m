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
    end
    properties (Access=private)
        LastPreviewPhase = ''
        LastPreviewIndex = NaN
    end

    methods
        function obj=ContinuationTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Continuation','Tag','lmz-tab-continuation');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
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
            grid=uigridlayout(obj.Root,[3 1]);grid.RowHeight={'1x',84,38};
            obj.Axes=uiaxes(grid,'Tag','lmz-continuation-axes');
            obj.Axes.XGrid='on';obj.Axes.YGrid='on';
            title(obj.Axes,'Live branch continuation overlay');
            controls=uigridlayout(grid,[2 9]);
            controls.ColumnWidth={62,64,105,65,65,65,115,'1x',105};
            label=uilabel(controls,'Text','Points');place(label,1,1);
            obj.PointsSpinner=uispinner(controls,'Limits',[3 1000],'Value',20, ...
                'Step',1,'RoundFractionalValues','on','Tag','lmz-continuation-points', ...
                'Tooltip','Maximum number of accepted continuation points.');place(obj.PointsSpinner,1,2);
            obj.RunButton=uibutton(controls,'Text','Run continuation', ...
                'Tag','lmz-continuation-run','Tooltip','Trace from the current seed pair.', ...
                'ButtonPushedFcn',@(~,~)obj.run());place(obj.RunButton,1,3);
            obj.PauseButton=uibutton(controls,'Text','Pause','Tag','lmz-continuation-pause', ...
                'Tooltip','Pause after the current cooperative checkpoint.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.pauseCurrentRun());place(obj.PauseButton,1,4);
            obj.ResumeButton=uibutton(controls,'Text','Resume','Tag','lmz-continuation-resume', ...
                'Tooltip','Resume a paused continuation run.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.resumeCurrentRun());place(obj.ResumeButton,1,5);
            obj.StopButton=uibutton(controls,'Text','Stop','Tag','lmz-continuation-stop', ...
                'Tooltip','Request a controlled stop and retain accepted points.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.stopCurrentRun());place(obj.StopButton,1,6);
            addButton=uibutton(controls,'Text','Add result dataset', ...
                'Tag','lmz-continuation-add','ButtonPushedFcn',@(~,~)obj.addDataset());place(addButton,1,7);
            saveButton=uibutton(controls,'Text','Save result…', ...
                'Tag','lmz-continuation-save','ButtonPushedFcn',@(~,~)obj.saveResult());place(saveButton,1,9);
            label=uilabel(controls,'Text','Checkpoint');place(label,2,1);
            obj.CheckpointField=uieditfield(controls,'text','Value','', ...
                'Tag','lmz-continuation-checkpoint','Tooltip','Checkpoint path for save or resume.');place(obj.CheckpointField,2,[2 4]);
            chooseButton=uibutton(controls,'Text','Choose…','Tag','lmz-continuation-choose', ...
                'ButtonPushedFcn',@(~,~)obj.chooseCheckpoint());place(chooseButton,2,5);
            resumeFileButton=uibutton(controls,'Text','Resume file', ...
                'Tag','lmz-continuation-resume-file','ButtonPushedFcn',@(~,~)obj.resumeFile());place(resumeFileButton,2,6);
            obj.ParameterDropDown=uidropdown(controls,'Tag','lmz-continuation-parameter', ...
                'Tooltip','Only active parameters are shown; inactive and derived parameters cannot be transported.');place(obj.ParameterDropDown,2,7);
            obj.TargetsField=uieditfield(controls,'text','Value','0 0.05', ...
                'Tag','lmz-continuation-targets','Tooltip','Space- or comma-separated homotopy targets.');place(obj.TargetsField,2,8);
            familyGrid=uigridlayout(controls,[1 2]);place(familyGrid,2,9);
            obj.HomotopyButton=uibutton(familyGrid,'Text','Homotopy', ...
                'Tag','lmz-continuation-homotopy','ButtonPushedFcn',@(~,~)obj.runHomotopy());
            obj.FamilyScanButton=uibutton(familyGrid,'Text','Family', ...
                'Tag','lmz-continuation-family','ButtonPushedFcn',@(~,~)obj.runFamily());
            obj.StatusLabel=uilabel(grid,'Text','Ready','WordWrap','on', ...
                'Tag','lmz-continuation-status');
            obj.ActionControls={obj.RunButton addButton saveButton chooseButton ...
                resumeFileButton obj.PointsSpinner obj.CheckpointField ...
                obj.ParameterDropDown obj.TargetsField obj.HomotopyButton obj.FamilyScanButton};
            obj.CancelControls={obj.PauseButton obj.ResumeButton obj.StopButton};
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            names=obj.Controller.homotopyParameterNames();
            if isempty(names),names={'No active transport parameter'};end
            obj.ParameterDropDown.Items=names;
            if any(strcmp('k_leg',names)),obj.ParameterDropDown.Value='k_leg'; ...
            else,obj.ParameterDropDown.Value=names{1};end
            result=obj.Controller.State.ContinuationResult;
            if ~isempty(result)
                obj.initializePlot();obj.renderResult(result);
                obj.StatusLabel.Text=sprintf('%s • %d accepted • %d rejected', ...
                    result.TerminationReason,result.Branch.pointCount(), ...
                    diagnosticField(result.Diagnostics,'rejectedAttempts',0));
            elseif isempty(obj.Controller.State.SeedPair)
                cla(obj.Axes);obj.StatusLabel.Text='Create a seed pair in Solve / Seeds.';
            end
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
                end
            end
            if ~handled&&any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
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
            enableControls(obj.CancelControls,obj.IsBusy);
            setEnable(obj.HomotopyButton,homotopy&&~obj.IsBusy);
            setEnable(obj.FamilyScanButton,family&&~obj.IsBusy);
            setEnable(obj.ParameterDropDown,(homotopy||family)&&~obj.IsBusy);
            setEnable(obj.TargetsField,(homotopy||family)&&~obj.IsBusy);
        end

        function controls=controlMap(obj)
            controls=struct('Axes',obj.Axes,'StatusLabel',obj.StatusLabel, ...
                'PointsSpinner',obj.PointsSpinner,'CheckpointField',obj.CheckpointField, ...
                'ParameterDropDown',obj.ParameterDropDown,'TargetsField',obj.TargetsField, ...
                'RunButton',obj.RunButton,'PauseButton',obj.PauseButton, ...
                'ResumeButton',obj.ResumeButton,'StopButton',obj.StopButton, ...
                'HomotopyButton',obj.HomotopyButton,'FamilyScanButton',obj.FamilyScanButton);
        end
    end

    methods (Access=private)
        function run(obj)
            try
                if isempty(obj.Controller.State.SeedPair)
                    obj.Controller.makeAdjacentSeedPair(1,struct());
                end
                obj.initializePlot();
                options=struct('MaximumPoints',obj.PointsSpinner.Value, ...
                    'BothDirections',false,'InitialStep',obj.Controller.State.SeedPair.AchievedRadius);
                if ~isempty(strtrim(obj.CheckpointField.Value))
                    options.CheckpointPath=obj.CheckpointField.Value;
                end
                obj.Controller.runContinuation(options);
            catch exception,obj.reportError(exception);end
        end

        function initializePlot(obj)
            cla(obj.Axes);obj.LastPreviewPhase='';obj.LastPreviewIndex=NaN;
            if isempty(obj.Controller.State.Datasets)||isempty(obj.Controller.State.SeedPair),return,end
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
                    delete(findobj(obj.Axes,'Tag','ContinuationPrediction'));
                    try
                        x=predictedCoordinate(state.DecisionValues,obj.Controller.State.SeedPair.Second,names{1});
                        y=predictedCoordinate(state.DecisionValues,obj.Controller.State.SeedPair.Second,names{2});
                        holdState=ishold(obj.Axes);hold(obj.Axes,'on');
                        plot(obj.Axes,x,y,'kx','MarkerSize',10,'LineWidth',2, ...
                            'Tag','ContinuationPrediction','DisplayName','prediction');
                        if ~holdState,hold(obj.Axes,'off');end
                    catch
                    end
                    obj.StatusLabel.Text=sprintf('Predicting point %d • step %.4g', ...
                        state.PointIndex,state.StepSize);
                case 'accepted'
                    line=findobj(obj.Axes,'Tag','ContinuationAccepted');
                    if isempty(line),obj.initializePlot();line=findobj(obj.Axes,'Tag','ContinuationAccepted');end
                    x=solutionCoordinate(state.Solution,names{1});y=solutionCoordinate(state.Solution,names{2});
                    if ~isempty(line),set(line,'XData',[line.XData x],'YData',[line.YData y]);end
                    delete(findobj(obj.Axes,'Tag','ContinuationPrediction'));
                    obj.StatusLabel.Text=sprintf('Accepted point %d • residual %.3g • step %.4g', ...
                        state.PointIndex,state.ResidualNorm,state.StepSize);
                case 'rejected'
                    obj.StatusLabel.Text=sprintf('Rejected point %d • residual %.3g • %s', ...
                        state.PointIndex,state.ResidualNorm,state.Reason);
            end
            drawnow limitrate
        end

        function renderResult(obj,result)
            if isempty(result)||isempty(obj.Controller.State.AxisVariables),return,end
            names=obj.Controller.State.AxisVariables(1:2);hold(obj.Axes,'on');
            plot(obj.Axes,result.Branch.coordinate(names{1}), ...
                result.Branch.coordinate(names{2}),'mo-','LineWidth',1.5, ...
                'DisplayName','result');hold(obj.Axes,'off');
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
            try,obj.Controller.resumeCheckpoint(path,struct('MaximumPoints',obj.PointsSpinner.Value)); ...
            catch exception,obj.reportError(exception);end
        end
        function addDataset(obj)
            result=obj.Controller.State.ContinuationResult;
            if isempty(result),obj.reportError(MException('lmz:GUI:ContinuationResult', ...
                    'No continuation result is available.'));return,end
            try,obj.Controller.addBranchDataset(['continuation_' datestr(now,'yyyymmdd_HHMMSS')], ...
                    result.Branch);catch exception,obj.reportError(exception);end
        end
        function saveResult(obj)
            result=obj.Controller.State.ContinuationResult;
            if isempty(result),obj.reportError(MException('lmz:GUI:ContinuationResult', ...
                    'No continuation result is available.'));return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'),'Save continuation branch');
            if isequal(file,0),return,end
            try,obj.Controller.saveBranch(fullfile(path,file),result.Branch); ...
                obj.Preferences.rememberOutputFolder(path);catch exception,obj.reportError(exception);end
        end
        function runHomotopy(obj)
            try,obj.Controller.runParameterHomotopy(obj.ParameterDropDown.Value, ...
                    parseNumericList(obj.TargetsField.Value),struct()); ...
            catch exception,obj.reportError(exception);end
        end
        function runFamily(obj)
            try
                options=struct('SecondSeedRadius',.01,'ContinuationOptions', ...
                    struct('MaximumPoints',obj.PointsSpinner.Value,'BothDirections',false));
                obj.Controller.runBranchFamilyScan(obj.ParameterDropDown.Value, ...
                    parseNumericList(obj.TargetsField.Value),options);
            catch exception,obj.reportError(exception);end
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
