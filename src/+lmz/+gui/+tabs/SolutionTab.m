classdef SolutionTab < lmz.gui.tabs.BaseTab
    %SOLUTIONTAB Schema-aware working-solution inspector and editor.
    properties (SetAccess=private)
        SolutionTable
        EventTable
        ParameterTable
        ObservableTable
        ResidualTable
        DiagnosticsTable
        ProvenanceTable
        ProjectionModeDropDown
        EvaluateButton
        RestoreButton
        ProjectButton
        SimulateButton
        SaveButton
        AddDatasetButton
        SendToSolveButton
        SendToContinuationButton
    end

    methods
        function obj=SolutionTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Solution Inspector','Tag','lmz-tab-solution');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
            obj.Id='solution';obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.SolveResultChanged, ...
                lmz.gui.PresentationEvents.OptimizationChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            root=uigridlayout(obj.Root,[2 1]);root.RowHeight={'1x',80};
            groups=uitabgroup(root);
            obj.SolutionTable=obj.makeTableTab(groups,'Initial State',true,'initial');
            obj.EventTable=obj.makeTableTab(groups,'Event Timing',true,'events');
            obj.ParameterTable=obj.makeTableTab(groups,'Parameters',true,'parameters');
            obj.ObservableTable=obj.makeTableTab(groups,'Observables',false,'observables');
            obj.ResidualTable=obj.makeTableTab(groups,'Residual Blocks',false,'residuals');
            obj.DiagnosticsTable=obj.makeTableTab(groups,'Diagnostics',false,'diagnostics');
            obj.ProvenanceTable=obj.makeTableTab(groups,'Provenance',false,'provenance');
            controls=uigridlayout(root,[2 5]);
            obj.EvaluateButton=uibutton(controls,'Text','Validate/evaluate', ...
                'Tag','lmz-solution-evaluate','Tooltip','Evaluate residuals or objective terms.', ...
                'ButtonPushedFcn',@(~,~)obj.evaluateSelected());
            obj.RestoreButton=uibutton(controls,'Text','Restore locked point', ...
                'Tag','lmz-solution-restore','Tooltip','Discard edits and restore the selected branch point.', ...
                'ButtonPushedFcn',@(~,~)obj.restoreSolution());
            obj.ProjectionModeDropDown=uidropdown(controls, ...
                'Items',{'Wrap cyclic times','Project ground contact'}, ...
                'Value','Wrap cyclic times','Tag','lmz-solution-projection-mode', ...
                'Tooltip','Choose how event times are projected to a valid schedule.');
            obj.ProjectButton=uibutton(controls,'Text','Project event schedule', ...
                'Tag','lmz-solution-project','Tooltip','Project the edited event schedule without solving.', ...
                'ButtonPushedFcn',@(~,~)obj.projectSolution());
            obj.SimulateButton=uibutton(controls,'Text','Simulate candidate', ...
                'Tag','lmz-solution-simulate','Tooltip','Simulate the current working copy.', ...
                'ButtonPushedFcn',@(~,~)obj.simulateSelected());
            obj.SaveButton=uibutton(controls,'Text','Save solution…', ...
                'Tag','lmz-solution-save','Tooltip','Save the working solution as an LMZ artifact.', ...
                'ButtonPushedFcn',@(~,~)obj.saveWorkingSolution());
            obj.AddDatasetButton=uibutton(controls,'Text','Add candidate dataset', ...
                'Tag','lmz-solution-add-dataset','Tooltip','Add the working copy as a writable one-point dataset.', ...
                'ButtonPushedFcn',@(~,~)obj.addWorkingDataset());
            obj.SendToSolveButton=uibutton(controls,'Text','Send to Solve', ...
                'Tag','lmz-solution-send-solve','Tooltip','Refine the working copy in the Solve tab.', ...
                'ButtonPushedFcn',@(~,~)obj.solve());
            obj.SendToContinuationButton=uibutton(controls,'Text','Send to Continuation', ...
                'Tag','lmz-solution-send-continuation', ...
                'Tooltip','Create a nearby second seed for continuation.', ...
                'ButtonPushedFcn',@(~,~)obj.makeSecondSeed());
            obj.ActionControls={obj.EvaluateButton obj.RestoreButton obj.ProjectButton ...
                obj.SimulateButton obj.SaveButton obj.AddDatasetButton ...
                obj.SendToSolveButton obj.SendToContinuationButton ...
                obj.ProjectionModeDropDown};
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            if isempty(obj.SolutionTable)||isempty(obj.Controller.State.WorkingSolution)
                obj.clearTables();return
            end
            solution=obj.Controller.State.WorkingSolution;
            locked=[];try,locked=obj.Controller.lockedSolution();catch,end
            timing=obj.Controller.timingEditorData();
            if timing.Available
                obj.SolutionTable.Data=fixedRows( ...
                    'initial_state',timing.FixedInitialState);
                obj.ParameterTable.Data=fixedRows( ...
                    'physical_parameter',timing.FixedPhysicalParameters);
                obj.SolutionTable.ColumnEditable=false(1,7);
                obj.ParameterTable.ColumnEditable=false(1,7);
            else
                obj.SolutionTable.Data=obj.schemaRows(solution.DecisionSchema, ...
                    solution.DecisionValues,'initial_state',locked);
                obj.ParameterTable.Data=obj.schemaRows(solution.ParameterSchema, ...
                    solution.ParameterValues,'parameter',locked);
                obj.SolutionTable.ColumnEditable= ...
                    [false false true false false false false];
                obj.ParameterTable.ColumnEditable= ...
                    [false false true false false false false];
            end
            obj.EventTable.Data=obj.schemaRows(solution.DecisionSchema, ...
                solution.DecisionValues,'event_timing',locked);
            fields=fieldnames(solution.Observables);data=cell(numel(fields),2);
            for index=1:numel(fields)
                data(index,:)={fields{index},displayValue(solution.Observables.(fields{index}))};
            end
            obj.ObservableTable.Data=data;obj.ObservableTable.ColumnName={'Observable','Value'};
            rows=cell(numel(solution.ResidualBlocks),3);
            for index=1:numel(solution.ResidualBlocks)
                rows(index,:)={solution.ResidualBlocks(index).Name, ...
                    displayValue(solution.ResidualBlocks(index).Values), ...
                    norm(solution.ResidualBlocks(index).Values)};
            end
            obj.ResidualTable.Data=rows;
            obj.ResidualTable.ColumnName={'Residual block','Values','Norm'};
            diagnostics=solution.Diagnostics;diagnostics.Feasibility=solution.Feasibility;
            diagnostics.Classification=solution.Classification;
            obj.DiagnosticsTable.Data=structRows(diagnostics);
            obj.DiagnosticsTable.ColumnName={'Field','Value'};
            obj.ProvenanceTable.Data=structRows(solution.Provenance);
            obj.ProvenanceTable.ColumnName={'Field','Value'};
            obj.applyControlState();
        end

        function hooks=testHooks(obj)
            hooks=testHooks@lmz.gui.tabs.BaseTab(obj);hooks.Controls=obj.controlMap();
        end
    end

    methods (Static)
        function value=descriptor()
            value=struct('Id','solution','Title','Solution Inspector', ...
                'Purpose','Edit, validate, simulate, and persist a working solution.');
        end
    end

    methods (Access=protected)
        function applyControlState(obj)
            hasSolution=~isempty(obj.Controller.State.WorkingSolution);
            enableControls(obj.ActionControls,hasSolution&&~obj.IsBusy);
            solve=false;continueCapability=false;simulate=false;
            if isfield(obj.Capabilities,'solve'),solve=obj.Capabilities.solve;end
            if isfield(obj.Capabilities,'continue'),continueCapability=obj.Capabilities.('continue');end
            if isfield(obj.Capabilities,'simulate'),simulate=obj.Capabilities.simulate;end
            setEnable(obj.SendToSolveButton,hasSolution&&solve&&~obj.IsBusy);
            setEnable(obj.SendToContinuationButton,hasSolution&&continueCapability&&~obj.IsBusy);
            setEnable(obj.SimulateButton,hasSolution&&simulate&&~obj.IsBusy);
        end

        function controls=controlMap(obj)
            controls=struct('SolutionTable',obj.SolutionTable,'EventTable',obj.EventTable, ...
                'ParameterTable',obj.ParameterTable,'ObservableTable',obj.ObservableTable, ...
                'ResidualTable',obj.ResidualTable,'DiagnosticsTable',obj.DiagnosticsTable, ...
                'ProvenanceTable',obj.ProvenanceTable, ...
                'ProjectionModeDropDown',obj.ProjectionModeDropDown, ...
                'SendToSolveButton',obj.SendToSolveButton, ...
                'SendToContinuationButton',obj.SendToContinuationButton, ...
                'SimulateButton',obj.SimulateButton);
        end
    end

    methods (Access=private)
        function tableHandle=makeTableTab(obj,group,titleText,editable,tag)
            tab=uitab(group,'Title',titleText);
            tableHandle=lmz.gui.components.InspectorTable.create(tab,editable,[]);
            tableHandle.Tag=['lmz-solution-' tag];
            if editable
                tableHandle.CellEditCallback=@(~,event)obj.valueEdited(tableHandle,event);
            end
        end

        function valueEdited(obj,tableHandle,event)
            try
                if event.Indices(2)~=3,return,end
                name=tableHandle.Data{event.Indices(1),1};value=event.NewData;
                if ischar(value)||isstring(value),value=str2double(value);end
                if ~isscalar(value)||~isfinite(value)
                    error('lmz:GUI:EditValue','Edited values must be finite numeric scalars.');
                end
                obj.Controller.editWorkingValue(name,value);
            catch exception
                obj.refresh();obj.reportError(exception);
            end
        end

        function evaluateSelected(obj)
            try,obj.Controller.evaluateWorkingSolution(true);catch exception,obj.reportError(exception);end
        end

        function restoreSolution(obj)
            try,obj.Controller.restoreWorkingSolution();catch exception,obj.reportError(exception);end
        end

        function projectSolution(obj)
            try
                options=struct('EnforceGroundContact',strcmp( ...
                    obj.ProjectionModeDropDown.Value,'Project ground contact'));
                obj.Controller.projectWorkingSolution(options);
            catch exception,obj.reportError(exception);end
        end

        function simulateSelected(obj)
            try,obj.Controller.simulateWorkingSolution();catch exception,obj.reportError(exception);end
        end

        function saveWorkingSolution(obj)
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'),'Save working solution');
            if isequal(file,0),return,end
            try
                obj.Controller.saveWorkingSolution(fullfile(path,file));
                obj.Preferences.rememberOutputFolder(path);
            catch exception,obj.reportError(exception);end
        end

        function addWorkingDataset(obj)
            try
                obj.Controller.addWorkingSolutionToDataset( ...
                    ['candidate_' datestr(now,'yyyymmdd_HHMMSS')]);
            catch exception,obj.reportError(exception);end
        end

        function solve(obj)
            try,obj.Controller.solveWorkingSolution(struct());catch exception,obj.reportError(exception);end
        end

        function makeSecondSeed(obj)
            try,obj.Controller.makeSecondSeed(.01);catch exception,obj.reportError(exception);end
        end

        function rows=schemaRows(~,schema,values,group,locked)
            selected=arrayfun(@(spec)strcmp(spec.Group,group),schema.Specs);
            if ~any(selected)
                groups=arrayfun(@(spec)spec.Group,schema.Specs,'UniformOutput',false);
                switch group
                    case 'initial_state',selected=~contains(groups,'event');
                    case 'event_timing',selected=contains(groups,'event');
                    case 'parameter',selected=true(size(groups));
                end
            end
            specs=schema.Specs(selected);indices=find(selected);rows=cell(numel(specs),7);
            lockedValues=[];
            if ~isempty(locked)
                if isequal(schema.names(),locked.ParameterSchema.names())
                    lockedValues=locked.ParameterValues;
                else
                    lockedValues=locked.DecisionValues;
                end
            end
            for index=1:numel(specs)
                spec=specs(index);edited=false;
                if ~isempty(lockedValues)
                    edited=abs(values(indices(index))-lockedValues(indices(index)))> ...
                        1e-12*max(1,abs(lockedValues(indices(index))));
                end
                rows(index,:)={spec.Name,spec.Label,values(indices(index)),spec.Unit, ...
                    sprintf('[%g, %g] • %s • %s • %s', ...
                    spec.LowerBound,spec.UpperBound,spec.Activity, ...
                    spec.Role,spec.EnergyEffect), ...
                    spec.Scale,edited};
            end
        end

        function clearTables(obj)
            tables={obj.SolutionTable,obj.EventTable,obj.ParameterTable, ...
                obj.ObservableTable,obj.ResidualTable,obj.DiagnosticsTable,obj.ProvenanceTable};
            for index=1:numel(tables),if ~isempty(tables{index}),tables{index}.Data={};end,end
        end
    end
end

function setEnable(control,value)
state='off';if value,state='on';end
if ~isempty(control)&&isvalid(control),control.Enable=state;end
end
function enableControls(controls,value)
for index=1:numel(controls),setEnable(controls{index},value);end
end
function value=displayValue(source)
if isnumeric(source),value=mat2str(source,5);elseif ischar(source),value=source; ...
elseif isstring(source),value=char(source);elseif islogical(source),value=mat2str(source); ...
else,value=class(source);end
end
function rows=structRows(value)
names=fieldnames(value);rows=cell(numel(names),2);
for index=1:numel(names),rows(index,:)={names{index},displayValue(value.(names{index}))};end
end
function rows=fixedRows(prefix,values)
values=values(:);rows=cell(numel(values),7);
for index=1:numel(values)
    name=sprintf('%s_%d',prefix,index);
    rows(index,:)={name,strrep(name,'_',' '),values(index),'', ...
        'fixed / locked / physical / invariant',1,false};
end
end
