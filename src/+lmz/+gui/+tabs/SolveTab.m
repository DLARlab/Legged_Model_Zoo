classdef SolveTab < lmz.gui.tabs.BaseTab
    %SOLVETAB Root-solve controls and reproducible seed construction.
    properties (SetAccess=private)
        StatusLabel
        SeedAxes
        DirectionDropDown
        FirstIndexSpinner
        SecondIndexSpinner
        SecondSeedRadiusField
        NoiseMagnitudeField
        NoiseSeedSpinner
        SolveButton
        AdjacentButton
        ManualButton
        GeneratedButton
        NoiseButton
        SimulateButton
        SolveModeDropDown
        StartSectionDropDown
        StopSectionDropDown
        StartSideDropDown
        StopSideDropDown
        CrossingDirectionDropDown
        MinimumReturnTimeField
        RequiredSequenceLabel
        TransferButton
        TransversalityLabel
        EventMaskTable
        FixedDataLabel
        LastSectionPreferenceKey = ''
    end

    methods
        function obj=SolveTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Solve / Seeds','Tag','lmz-tab-solve');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
            obj.Id='solve';obj.CapabilityName='solve';obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.ProblemConfigurationChanged, ...
                lmz.gui.PresentationEvents.DatasetsChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.SolveResultChanged, ...
                lmz.gui.PresentationEvents.SeedPairChanged, ...
                lmz.gui.PresentationEvents.BranchViewChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            grid=uigridlayout(obj.Root,[5 1]);
            grid.RowHeight={68,108,80,42,'1x'};
            sectionControls=uigridlayout(grid,[2 12]);
            sectionControls.ColumnWidth={72,145,42,130,42,130,52,72, ...
                58,78,105,'1x'};
            label=uilabel(sectionControls,'Text','Solve mode');place(label,1,1);
            obj.SolveModeDropDown=uidropdown(sectionControls, ...
                'Items',{'Periodic orbit','Contact timings only', ...
                'N-stride periodic orbit','Timing sequence'}, ...
                'Tag','lmz-solve-mode', ...
                'Tooltip','Choose the explicit numerical formulation.', ...
                'ValueChangedFcn',@(~,~)obj.solveModeChanged());
            place(obj.SolveModeDropDown,1,2);
            label=uilabel(sectionControls,'Text','Start');place(label,1,3);
            obj.StartSectionDropDown=uidropdown(sectionControls, ...
                'Items',{'apex'},'Tag','lmz-solve-start-section', ...
                'ValueChangedFcn',@(~,~)obj.sectionChanged());
            place(obj.StartSectionDropDown,1,4);
            label=uilabel(sectionControls,'Text','Stop');place(label,1,5);
            obj.StopSectionDropDown=uidropdown(sectionControls, ...
                'Items',{'apex'},'Tag','lmz-solve-stop-section', ...
                'ValueChangedFcn',@(~,~)obj.sectionChanged());
            place(obj.StopSectionDropDown,1,6);
            label=uilabel(sectionControls,'Text','Start side');place(label,1,7);
            obj.StartSideDropDown=uidropdown(sectionControls, ...
                'Items',{'pre','post'},'Value','post', ...
                'Tag','lmz-solve-start-side', ...
                'ValueChangedFcn',@(~,~)obj.sectionChanged());
            place(obj.StartSideDropDown,1,8);
            label=uilabel(sectionControls,'Text','Stop side');place(label,1,9);
            obj.StopSideDropDown=uidropdown(sectionControls, ...
                'Items',{'pre','post'},'Value','post', ...
                'Tag','lmz-solve-stop-side', ...
                'ValueChangedFcn',@(~,~)obj.sectionChanged());
            place(obj.StopSideDropDown,1,10);
            obj.TransferButton=uibutton(sectionControls, ...
                'Text','Transfer/rephase','Tag','lmz-solve-section-transfer', ...
                'Tooltip','Rephase the selected orbit to the stop section.', ...
                'ButtonPushedFcn',@(~,~)obj.transferSection());
            place(obj.TransferButton,1,11);
            obj.TransversalityLabel=uilabel(sectionControls, ...
                'Text','Transversality: not evaluated', ...
                'Tag','lmz-solve-transversality');
            place(obj.TransversalityLabel,1,12);
            label=uilabel(sectionControls,'Text','Direction');place(label,2,1);
            obj.CrossingDirectionDropDown=uidropdown(sectionControls, ...
                'Items',{'decreasing','either','increasing'}, ...
                'ItemsData',{'-1','0','1'},'Value','0', ...
                'Tag','lmz-solve-crossing-direction', ...
                'ValueChangedFcn',@(~,~)obj.sectionChanged());
            place(obj.CrossingDirectionDropDown,2,2);
            label=uilabel(sectionControls,'Text','Min time');place(label,2,3);
            obj.MinimumReturnTimeField=uieditfield(sectionControls,'numeric', ...
                'Limits',[0 Inf],'Value',0,'Tag','lmz-solve-minimum-return', ...
                'ValueChangedFcn',@(~,~)obj.sectionChanged());
            place(obj.MinimumReturnTimeField,2,4);
            obj.RequiredSequenceLabel=uilabel(sectionControls, ...
                'Text','Required events: none','WordWrap','on', ...
                'Tag','lmz-solve-required-sequence');
            place(obj.RequiredSequenceLabel,2,[5 12]);

            timingGrid=uigridlayout(grid,[1 2]);
            timingGrid.ColumnWidth={'1x','1x'};
            obj.EventMaskTable=uitable(timingGrid, ...
                'ColumnName',{'Event / return','Free'}, ...
                'ColumnEditable',[false true], ...
                'Tag','lmz-solve-event-free-mask', ...
                'CellEditCallback',@(~,~)obj.eventMaskChanged());
            obj.FixedDataLabel=uilabel(timingGrid, ...
                'Text','Periodic mode: state and parameters are decision data.', ...
                'WordWrap','on','Tag','lmz-solve-fixed-data');

            controls=uigridlayout(grid,[2 10]);place(controls,3,1);
            controls.ColumnWidth={72,88,105,54,70,54,70,90,72,'1x'};
            label=uilabel(controls,'Text','Direction');place(label,1,1);
            obj.DirectionDropDown=uidropdown(controls,'Items',{'next','previous'}, ...
                'Value','next','Tag','lmz-solve-direction', ...
                'Tooltip','Choose the adjacent branch direction.');place(obj.DirectionDropDown,1,2);
            obj.AdjacentButton=uibutton(controls,'Text','Adjacent pair', ...
                'Tag','lmz-solve-adjacent','Tooltip','Use adjacent branch points as a seed pair.', ...
                'ButtonPushedFcn',@(~,~)obj.makeAdjacentSeed());place(obj.AdjacentButton,1,3);
            label=uilabel(controls,'Text','First');place(label,1,4);
            obj.FirstIndexSpinner=uispinner(controls,'Limits',[1 Inf],'Value',1, ...
                'Step',1,'RoundFractionalValues','on','Tag','lmz-solve-first-index');place(obj.FirstIndexSpinner,1,5);
            label=uilabel(controls,'Text','Second');place(label,1,6);
            obj.SecondIndexSpinner=uispinner(controls,'Limits',[1 Inf],'Value',2, ...
                'Step',1,'RoundFractionalValues','on','Tag','lmz-solve-second-index');place(obj.SecondIndexSpinner,1,7);
            obj.ManualButton=uibutton(controls,'Text','Manual pair', ...
                'Tag','lmz-solve-manual','Tooltip','Build a pair from the two selected indices.', ...
                'ButtonPushedFcn',@(~,~)obj.makeManualSeed());place(obj.ManualButton,1,8);
            label=uilabel(controls,'Text','Radius');place(label,1,9);
            obj.SecondSeedRadiusField=uieditfield(controls,'numeric','Limits',[1e-6 Inf], ...
                'Value',0.01,'Tag','lmz-solve-radius', ...
                'Tooltip','Requested scaled radius for a generated second seed.');place(obj.SecondSeedRadiusField,1,10);
            evaluateButton=uibutton(controls,'Text','Evaluate', ...
                'Tag','lmz-solve-evaluate','ButtonPushedFcn',@(~,~)obj.evaluate());place(evaluateButton,2,1);
            obj.SolveButton=uibutton(controls,'Text','Solve/refine','Tag','lmz-solve-run', ...
                'Tooltip','Refine the current equation solution.', ...
                'ButtonPushedFcn',@(~,~)obj.solve());place(obj.SolveButton,2,2);
            obj.GeneratedButton=uibutton(controls,'Text','Generated second seed', ...
                'Tag','lmz-solve-generate-seed','Tooltip','Generate a nearby corrected second seed.', ...
                'ButtonPushedFcn',@(~,~)obj.makeSecondSeed());place(obj.GeneratedButton,2,3);
            label=uilabel(controls,'Text','Noise');place(label,2,4);
            obj.NoiseMagnitudeField=uieditfield(controls,'numeric','Limits',[0 Inf], ...
                'Value',0.001,'Tag','lmz-solve-noise');place(obj.NoiseMagnitudeField,2,5);
            label=uilabel(controls,'Text','Seed');place(label,2,6);
            obj.NoiseSeedSpinner=uispinner(controls,'Limits',[0 Inf],'Value',123, ...
                'Step',1,'RoundFractionalValues','on','Tag','lmz-solve-random-seed');place(obj.NoiseSeedSpinner,2,7);
            obj.NoiseButton=uibutton(controls,'Text','Apply noise','Tag','lmz-solve-apply-noise', ...
                'Tooltip','Apply reproducible schema-scaled perturbations.', ...
                'ButtonPushedFcn',@(~,~)obj.applyNoise());place(obj.NoiseButton,2,8);
            obj.SimulateButton=uibutton(controls,'Text','Simulate solved', ...
                'Tag','lmz-solve-simulate','ButtonPushedFcn',@(~,~)obj.simulate());place(obj.SimulateButton,2,9);
            obj.ActionControls={evaluateButton obj.SolveButton obj.AdjacentButton ...
                obj.ManualButton obj.GeneratedButton obj.NoiseButton obj.SimulateButton ...
                obj.DirectionDropDown obj.FirstIndexSpinner obj.SecondIndexSpinner ...
                obj.SecondSeedRadiusField obj.NoiseMagnitudeField obj.NoiseSeedSpinner};
            obj.StatusLabel=uilabel(grid,'Text','Ready','WordWrap','on', ...
                'Tag','lmz-solve-status');place(obj.StatusLabel,4,1);
            obj.SeedAxes=uiaxes(grid,'Tag','lmz-solve-seed-axes');
            place(obj.SeedAxes,5,1);
            title(obj.SeedAxes,'Branch seed-pair overlay');
            obj.SeedAxes.XGrid='on';obj.SeedAxes.YGrid='on';
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            obj.refreshSectionControls();
            if isempty(obj.Controller.State.Datasets)
                obj.FirstIndexSpinner.Limits=[1 Inf];obj.SecondIndexSpinner.Limits=[1 Inf];
            else
                dataset=obj.Controller.activeDataset();n=dataset.Branch.pointCount();
                obj.FirstIndexSpinner.Limits=[1 n];obj.SecondIndexSpinner.Limits=[1 n];
                selected=1;
                if ~isempty(obj.Controller.State.LockedSelection)
                    selected=min(n,obj.Controller.State.LockedSelection.PointIndex);
                end
                obj.FirstIndexSpinner.Value=selected;
                obj.SecondIndexSpinner.Value=min(n,selected+1);
            end
            pair=obj.Controller.State.SeedPair;
            if isempty(pair),cla(obj.SeedAxes);else,obj.describeSeedPair(pair);end
            result=obj.Controller.State.SolveResult;
            if ~isempty(result)
                obj.StatusLabel.Text=sprintf('%s • exit %d • residual %.3g', ...
                    outputField(result.Output,'algorithm','solver'),result.ExitFlag, ...
                    result.Evaluation.ScaledResidualNorm);
            end
            timing=obj.Controller.State.TimingResult;
            if ~isempty(timing)
                obj.StatusLabel.Text=sprintf( ...
                    'Timing only • residual %.3g • fixed state/physics: %s/%s', ...
                    norm([timing.ContactResiduals;timing.SectionResidual]), ...
                    yesNo(timing.SolverDiagnostics. ...
                    InitialStateBitwiseUnchanged), ...
                    yesNo(timing.SolverDiagnostics. ...
                    PhysicalParametersBitwiseUnchanged));
            end
            obj.applyControlState();
        end

        function hooks=testHooks(obj)
            hooks=testHooks@lmz.gui.tabs.BaseTab(obj);hooks.Controls=obj.controlMap();
        end
    end

    methods (Static)
        function value=descriptor()
            value=struct('Id','solve','Title','Solve / Seeds', ...
                'Purpose','Build reproducible seeds and refine equation solutions.');
        end
    end

    methods (Access=protected)
        function applyControlState(obj)
            solve=false;continueCapability=false;simulate=false;
            if isfield(obj.Capabilities,'solve'),solve=obj.Capabilities.solve;end
            if isfield(obj.Capabilities,'continue'),continueCapability=obj.Capabilities.('continue');end
            if isfield(obj.Capabilities,'simulate'),simulate=obj.Capabilities.simulate;end
            enableControls(obj.ActionControls,false);
            setEnable(obj.SolveButton,solve&&~obj.IsBusy);
            setEnable(obj.NoiseButton,solve&&~obj.IsBusy);
            setEnable(obj.NoiseMagnitudeField,solve&&~obj.IsBusy);
            setEnable(obj.NoiseSeedSpinner,solve&&~obj.IsBusy);
            continuationControls={obj.AdjacentButton,obj.ManualButton,obj.GeneratedButton, ...
                obj.DirectionDropDown,obj.FirstIndexSpinner,obj.SecondIndexSpinner, ...
                obj.SecondSeedRadiusField};
            timingOnly=strcmp(obj.Controller.State.SolveMode, ...
                'Contact timings only');
            enableControls(continuationControls, ...
                continueCapability&&~timingOnly&&~obj.IsBusy);
            setEnable(obj.SimulateButton,simulate&&~obj.IsBusy);
            evaluate=findobj(obj.Root,'Tag','lmz-solve-evaluate');
            setEnable(evaluate,~obj.IsBusy&&~isempty(obj.Controller.State.WorkingSolution));
            sectionControls={obj.StartSectionDropDown,obj.StopSectionDropDown, ...
                obj.StartSideDropDown,obj.StopSideDropDown, ...
                obj.CrossingDirectionDropDown,obj.MinimumReturnTimeField};
            enableControls(sectionControls,~obj.IsBusy&& ...
                ~isempty(obj.Controller.sectionIds()));
            setEnable(obj.TransferButton,~obj.IsBusy&& ...
                ~isempty(obj.Controller.State.WorkingSolution));
            setEnable(obj.EventMaskTable,~obj.IsBusy&&timingOnly);
        end

        function controls=controlMap(obj)
            controls=struct('StatusLabel',obj.StatusLabel,'SeedAxes',obj.SeedAxes, ...
                'DirectionDropDown',obj.DirectionDropDown, ...
                'FirstIndexSpinner',obj.FirstIndexSpinner, ...
                'SecondIndexSpinner',obj.SecondIndexSpinner, ...
                'SecondSeedRadiusField',obj.SecondSeedRadiusField, ...
                'NoiseMagnitudeField',obj.NoiseMagnitudeField, ...
                'NoiseSeedSpinner',obj.NoiseSeedSpinner,'SolveButton',obj.SolveButton);
            controls.SolveModeDropDown=obj.SolveModeDropDown;
            controls.StartSectionDropDown=obj.StartSectionDropDown;
            controls.StopSectionDropDown=obj.StopSectionDropDown;
            controls.StartSideDropDown=obj.StartSideDropDown;
            controls.StopSideDropDown=obj.StopSideDropDown;
            controls.CrossingDirectionDropDown=obj.CrossingDirectionDropDown;
            controls.MinimumReturnTimeField=obj.MinimumReturnTimeField;
            controls.RequiredSequenceLabel=obj.RequiredSequenceLabel;
            controls.TransferButton=obj.TransferButton;
            controls.TransversalityLabel=obj.TransversalityLabel;
            controls.EventMaskTable=obj.EventMaskTable;
            controls.FixedDataLabel=obj.FixedDataLabel;
        end
    end

    methods (Access=private)
        function refreshSectionControls(obj)
            ids=obj.Controller.sectionIds();
            if isempty(ids),ids={'unavailable'};end
            obj.StartSectionDropDown.Items=ids;
            obj.StopSectionDropDown.Items=ids;
            configuration=obj.Controller.State.ProblemConfiguration;
            key=[obj.Controller.State.ModelId '/' obj.Controller.State.ProblemId];
            if ~strcmp(key,obj.LastSectionPreferenceKey)
                obj.LastSectionPreferenceKey=key;
                preferred=obj.Preferences.sectionPreference( ...
                    obj.Controller.State.ModelId,obj.Controller.State.ProblemId, ...
                    configuration);
                if ~isequaln(preferred,configuration)
                    try
                        configuration=obj.Controller.configureSections(preferred);
                    catch
                        configuration=obj.Controller.State.ProblemConfiguration;
                    end
                end
            end
            start=fieldOr(configuration,'StartSectionId',ids{1});
            stop=fieldOr(configuration,'StopSectionId',start);
            if ~any(strcmp(start,ids)),start=ids{1};end
            if ~any(strcmp(stop,ids)),stop=ids{1};end
            obj.StartSectionDropDown.Value=start;
            obj.StopSectionDropDown.Value=stop;
            obj.StartSideDropDown.Value=fieldOr( ...
                configuration,'StartStateSide','post');
            obj.StopSideDropDown.Value=fieldOr( ...
                configuration,'StopStateSide','post');
            direction=fieldOr(configuration,'CrossingDirection',0);
            obj.CrossingDirectionDropDown.Value=num2str(direction);
            obj.MinimumReturnTimeField.Value=fieldOr( ...
                configuration,'MinimumReturnTime',0);
            obj.SolveModeDropDown.Value=obj.Controller.State.SolveMode;
            sequence=fieldOr(configuration,'RequiredEventSequence',{});
            if isempty(sequence),summary='none';else,summary=strjoin(sequence,' → ');end
            obj.RequiredSequenceLabel.Text=['Required events: ' summary];
            timing=obj.Controller.timingEditorData();
            if timing.Available
                rows=[timing.EventNames(:),num2cell(timing.FreeMask(:)); ...
                    {'return_time',timing.ReturnTimeFree}];
                obj.EventMaskTable.Data=rows;
                obj.FixedDataLabel.Text=sprintf([ ...
                    'Timing-only mode: %d initial-state values and %d ' ...
                    'physical parameters are fixed/locked. No periodicity ' ...
                    'residual is displayed.'],numel(timing.FixedInitialState), ...
                    numel(timing.FixedPhysicalParameters));
            else
                obj.EventMaskTable.Data=cell(0,2);
                obj.FixedDataLabel.Text= ...
                    'Periodic mode: state and parameters are decision data.';
            end
            crossing=[];
            if ~isempty(obj.Controller.State.TimingResult)
                crossing=obj.Controller.State.TimingResult.SectionCrossing;
            elseif ~isempty(obj.Controller.State.SectionTransferResult)
                crossing=obj.Controller.State.SectionTransferResult.Crossing;
            end
            obj.TransversalityLabel.Text=transversalityText(crossing);
        end

        function solveModeChanged(obj)
            try
                obj.Controller.setSolveMode(obj.SolveModeDropDown.Value);
            catch exception
                obj.refresh();obj.reportError(exception);
            end
        end

        function sectionChanged(obj)
            try
                changes=struct( ...
                    'StartSectionId',obj.StartSectionDropDown.Value, ...
                    'StopSectionId',obj.StopSectionDropDown.Value, ...
                    'StartStateSide',obj.StartSideDropDown.Value, ...
                    'StopStateSide',obj.StopSideDropDown.Value, ...
                    'CrossingDirection',str2double( ...
                    obj.CrossingDirectionDropDown.Value), ...
                    'MinimumReturnTime',obj.MinimumReturnTimeField.Value);
                obj.Controller.configureSections(changes);
                obj.Preferences.setSectionPreference( ...
                    obj.Controller.State.ModelId,obj.Controller.State.ProblemId, ...
                    sectionPreferenceValue( ...
                    obj.Controller.State.ProblemConfiguration));
            catch exception
                obj.refresh();obj.reportError(exception);
            end
        end

        function eventMaskChanged(obj)
            try
                data=obj.EventMaskTable.Data;
                if isempty(data),return,end
                mask=logical(cell2mat(data(1:end-1,2)));
                returnFree=logical(data{end,2});
                obj.Controller.setEventFreeMask(mask,returnFree);
            catch exception
                obj.refresh();obj.reportError(exception);
            end
        end

        function transferSection(obj)
            try
                obj.Controller.transferWorkingSolution( ...
                    obj.StopSectionDropDown.Value);
            catch exception
                obj.reportError(exception);
            end
        end

        function evaluate(obj)
            try,obj.Controller.evaluateWorkingSolution(true);catch exception,obj.reportError(exception);end
        end
        function solve(obj)
            try,obj.Controller.solveWorkingSolution(struct());catch exception,obj.reportError(exception);end
        end
        function simulate(obj)
            try,obj.Controller.simulateWorkingSolution();catch exception,obj.reportError(exception);end
        end
        function applyNoise(obj)
            try
                obj.Controller.perturbWorkingSolution(obj.NoiseMagnitudeField.Value, ...
                    'schema-scaled',obj.NoiseSeedSpinner.Value);
            catch exception,obj.reportError(exception);end
        end
        function makeAdjacentSeed(obj)
            try
                direction=1;if strcmp(obj.DirectionDropDown.Value,'previous'),direction=-1;end
                obj.Controller.makeAdjacentSeedPair(direction,struct());
            catch exception,obj.reportError(exception);end
        end
        function makeManualSeed(obj)
            try
                obj.Controller.makeManualSeedPair(obj.FirstIndexSpinner.Value, ...
                    obj.SecondIndexSpinner.Value,struct());
            catch exception,obj.reportError(exception);end
        end
        function makeSecondSeed(obj)
            try,obj.Controller.makeSecondSeed(obj.SecondSeedRadiusField.Value); ...
            catch exception,obj.reportError(exception);end
        end
        function describeSeedPair(obj,pair)
            indices=diagnosticField(pair.Diagnostics,'SourceIndices',[NaN NaN]);
            residual=diagnosticField(pair.Diagnostics,'ResidualNorm',NaN);
            obj.StatusLabel.Text=sprintf( ...
                'Seed pair %g → %g • radius %.5g • generated residual %.3g', ...
                indices(1),indices(2),pair.AchievedRadius,residual);
            obj.plotSeedPair(pair);
        end
        function plotSeedPair(obj,pair)
            cla(obj.SeedAxes);
            if isempty(obj.Controller.State.Datasets),return,end
            hold(obj.SeedAxes,'on');names=obj.Controller.State.AxisVariables(1:2);
            dataset=obj.Controller.activeDataset();
            plot(obj.SeedAxes,dataset.Branch.coordinate(names{1}), ...
                dataset.Branch.coordinate(names{2}),'Color',[.75 .75 .75]);
            first=[solutionCoordinate(pair.First,names{1}) solutionCoordinate(pair.First,names{2})];
            second=[solutionCoordinate(pair.Second,names{1}) solutionCoordinate(pair.Second,names{2})];
            plot(obj.SeedAxes,first(1),first(2),'bo','MarkerFaceColor','b','DisplayName','first seed');
            plot(obj.SeedAxes,second(1),second(2),'ro','MarkerFaceColor','r','DisplayName','second seed');
            quiver(obj.SeedAxes,first(1),first(2),second(1)-first(1), ...
                second(2)-first(2),0,'k','LineWidth',1.5,'DisplayName','predictor');
            hold(obj.SeedAxes,'off');grid(obj.SeedAxes,'on');
            xlabel(obj.SeedAxes,names{1},'Interpreter','none');
            ylabel(obj.SeedAxes,names{2},'Interpreter','none');
            legend(obj.SeedAxes,'show','Location','best');
        end
    end
end

function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end
function setEnable(control,value)
state='off';if value,state='on';end
if ~isempty(control)&&all(isvalid(control)),control.Enable=state;end
end
function enableControls(controls,value)
for index=1:numel(controls),setEnable(controls{index},value);end
end
function value=diagnosticField(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=outputField(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=sectionPreferenceValue(configuration)
names={'StartSectionId','StopSectionId','StartStateSide', ...
    'StopStateSide','CrossingDirection','MinimumReturnTime', ...
    'RequiredEventSequence','ReturnOccurrence','SymmetryId'};
value=struct();
for index=1:numel(names)
    if isfield(configuration,names{index})
        value.(names{index})=configuration.(names{index});
    end
end
end
function value=yesNo(condition)
if condition,value='yes';else,value='no';end
end
function value=transversalityText(crossing)
value='Transversality: not evaluated';
if isempty(crossing),return,end
if isa(crossing,'lmz.poincare.SectionCrossing')
    derivative=crossing.DirectionalDerivative;grazing=crossing.Grazing;
elseif isstruct(crossing)
    derivative=fieldOr(crossing,'DirectionalDerivative', ...
        fieldOr(crossing,'directionalDerivative',NaN));
    grazing=fieldOr(crossing,'Grazing',fieldOr(crossing,'grazing',false));
else
    return
end
if grazing,status='grazing';else,status='transverse';end
value=sprintf('Transversality: %s (D h f = %.4g)',status,derivative);
end
function value=solutionCoordinate(solution,name)
if any(strcmp(name,solution.DecisionSchema.names())),value=solution.decision(name); ...
elseif any(strcmp(name,solution.ParameterSchema.names())),value=solution.parameter(name); ...
elseif isfield(solution.Observables,name),value=solution.Observables.(name); ...
else,value=NaN;end
end
