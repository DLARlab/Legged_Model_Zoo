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
        SectionSupportLabel
        EventMaskTable
        FixedDataLabel
        FormulationDropDown
        SolverDropDown
        HorizonLengthSpinner
        InterfaceMaskField
        ControlMaskField
        EnergyModeDropDown
        ResidualToleranceField
        TemplateInitializerDropDown
        ResidualClassificationLabel
        ShootingDiagnosticsTable
        IterationTable
        LastSectionPreferenceKey = ''
        RegisteredSolveDefaultsKey = ''
        OverlayController = []
    end

    methods
        function obj=SolveTab(parent,controller,eventBus,preferences,varargin)
            [root,hostOptions,baseArguments]= ...
                lmz.gui.layout.ComponentHost.create(parent, ...
                'Solve / Seeds','lmz-tab-solve',varargin{:});
            obj@lmz.gui.tabs.BaseTab(root,controller,eventBus,preferences, ...
                baseArguments{:});
            obj.HostMode=hostOptions.HostMode;
            obj.OverlayController=hostOptions.OverlayController;
            obj.Id='solve';obj.CapabilityName='solve';obj.build();
            topics={lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.ProblemConfigurationChanged, ...
                lmz.gui.PresentationEvents.DatasetsChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.SolveResultChanged, ...
                lmz.gui.PresentationEvents.SeedPairChanged, ...
                lmz.gui.PresentationEvents.BranchViewChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged};
            if any(strcmp('SolveProgressChanged', ...
                    lmz.gui.PresentationEvents.all()))
                topics{end+1}='SolveProgressChanged';
            end
            obj.subscribe(topics);
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            grid=uigridlayout(obj.Root,[6 1]);
            grid.RowHeight={68,108,116,80,42,'1x'};
            sectionControls=uigridlayout(grid,[2 12]);
            sectionControls.ColumnWidth={72,145,42,130,42,130,52,72, ...
                58,78,105,'1x'};
            label=uilabel(sectionControls,'Text','Solve mode');place(label,1,1);
            obj.SolveModeDropDown=uidropdown(sectionControls, ...
                'Items',{'Periodic orbit','Contact timings only', ...
                'N-stride periodic orbit','Timing sequence', ...
                'Multiple shooting','Horizon feasibility'}, ...
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
            place(obj.RequiredSequenceLabel,2,[5 8]);
            obj.SectionSupportLabel=uilabel(sectionControls, ...
                'Text','Section combination: not classified', ...
                'WordWrap','on','Tag','lmz-solve-section-support');
            place(obj.SectionSupportLabel,2,[9 12]);

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

            shootingGrid=uigridlayout(grid,[3 12]);
            shootingGrid.ColumnWidth={72,120,52,112,58,72,62,105, ...
                62,105,'1x','1x'};
            label=uilabel(shootingGrid,'Text','Formulation');place(label,1,1);
            obj.FormulationDropDown=uidropdown(shootingGrid, ...
                'Items',{'Single shooting','Multiple shooting', ...
                'Timing only','Horizon feasibility'}, ...
                'ItemsData',{'single_shooting','multiple_shooting', ...
                'timing_only','horizon_feasibility'}, ...
                'Value','multiple_shooting','Tag','lmz-shooting-formulation', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.FormulationDropDown,1,2);
            label=uilabel(shootingGrid,'Text','Solver');place(label,1,3);
            obj.SolverDropDown=uidropdown(shootingGrid, ...
                'Items',{'Auto','fsolve','lsqnonlin', ...
                'Constrained feasibility'}, ...
                'ItemsData',{'auto','fsolve','lsqnonlin', ...
                'fmincon_feasibility'},'Value','auto', ...
                'Tag','lmz-shooting-solver', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.SolverDropDown,1,4);
            label=uilabel(shootingGrid,'Text','Horizon');place(label,1,5);
            obj.HorizonLengthSpinner=uispinner(shootingGrid, ...
                'Limits',[1 100],'Value',2,'Step',1, ...
                'RoundFractionalValues','on','Tag','lmz-shooting-horizon', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.HorizonLengthSpinner,1,6);
            label=uilabel(shootingGrid,'Text','Energy');place(label,1,7);
            obj.EnergyModeDropDown=uidropdown(shootingGrid, ...
                'Items',{'Diagnostic only','Energy neutral', ...
                'Bounded work','Prescribed work'}, ...
                'ItemsData',{'diagnostic_only','energy_neutral', ...
                'bounded_work','prescribed_work'}, ...
                'Value','diagnostic_only','Tag','lmz-shooting-energy-mode', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.EnergyModeDropDown,1,8);
            label=uilabel(shootingGrid,'Text','Tolerance');place(label,1,9);
            obj.ResidualToleranceField=uieditfield(shootingGrid,'numeric', ...
                'Limits',[eps Inf],'Value',1e-7, ...
                'Tag','lmz-shooting-residual-tolerance', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.ResidualToleranceField,1,10);
            obj.ResidualClassificationLabel=uilabel(shootingGrid, ...
                'Text','Residual: not run','WordWrap','on', ...
                'Tag','lmz-shooting-residual-classification');
            place(obj.ResidualClassificationLabel,1,[11 12]);
            label=uilabel(shootingGrid,'Text','Interfaces');place(label,2,1);
            obj.InterfaceMaskField=uieditfield(shootingGrid,'text', ...
                'Value','all','Tag','lmz-shooting-interface-mask', ...
                'Tooltip','all, none, or a comma-separated 0/1 mask', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.InterfaceMaskField,2,2);
            label=uilabel(shootingGrid,'Text','Controls');place(label,2,3);
            obj.ControlMaskField=uieditfield(shootingGrid,'text', ...
                'Value','none','Tag','lmz-shooting-control-mask', ...
                'Tooltip','all, none, or a comma-separated 0/1 mask', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.ControlMaskField,2,4);
            label=uilabel(shootingGrid,'Text','Initializer');place(label,2,5);
            obj.TemplateInitializerDropDown=uidropdown(shootingGrid, ...
                'Items',{'Schema defaults','Exact source horizon', ...
                'Nearest compatible','Phase-compatible repeat'}, ...
                'ItemsData',{'schema_defaults','exact_source_horizon', ...
                'nearest_compatible_template','phase_compatible_repeat'}, ...
                'Value','schema_defaults','Tag','lmz-shooting-initializer', ...
                'ValueChangedFcn',@(~,~)obj.shootingChanged());
            place(obj.TemplateInitializerDropDown,2,[6 8]);
            obj.ShootingDiagnosticsTable=uitable(shootingGrid, ...
                'ColumnName',{'Horizon diagnostic','Value'}, ...
                'ColumnEditable',[false false], ...
                'Tag','lmz-shooting-diagnostics');
            place(obj.ShootingDiagnosticsTable,[2 3],[9 12]);
            note=uilabel(shootingGrid,'Text', ...
                ['Event free/fixed rows are edited above. Partial or ' ...
                'physically invalid horizons remain diagnostic-only.'], ...
                'WordWrap','on','Tag','lmz-shooting-partial-warning');
            place(note,3,[1 8]);

            controls=uigridlayout(grid,[2 10]);place(controls,4,1);
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
                'Tag','lmz-solve-status');place(obj.StatusLabel,5,1);
            diagnosticsHost=uigridlayout(grid,[1 2]);
            diagnosticsHost.ColumnWidth={'1.15x','0.85x'};place(diagnosticsHost,6,1);
            obj.SeedAxes=uiaxes(diagnosticsHost,'Tag','lmz-solve-seed-axes');
            title(obj.SeedAxes,'Branch seed-pair overlay');
            obj.SeedAxes.XGrid='on';obj.SeedAxes.YGrid='on';
            obj.IterationTable=uitable(diagnosticsHost, ...
                'ColumnName',{'Stage','Iteration','Functions','Residual', ...
                'Step','Optimality'},'ColumnEditable',false(1,6), ...
                'Tag','lmz-solve-iteration-table');
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            obj.refreshSectionControls();
            obj.refreshShootingControls();
            obj.refreshRegisteredSolveDefaults();
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
            obj.refreshCandidateOverlay();
            shootingResult=obj.Controller.State.ShootingResult;
            if ~isempty(shootingResult)
                plotHorizonDiagnostics(obj.SeedAxes,shootingResult);
            elseif isempty(pair)
                cla(obj.SeedAxes);title(obj.SeedAxes, ...
                    'Branch seed-pair overlay');
            else
                obj.describeSeedPair(pair);
            end
            result=obj.Controller.State.SolveResult;
            if ~isempty(result)
                obj.StatusLabel.Text=sprintf('%s • exit %d • residual %.3g', ...
                    outputField(result.Output,'algorithm','solver'),result.ExitFlag, ...
                    result.Evaluation.ScaledResidualNorm);
                if ~isempty(obj.OverlayController)
                    obj.OverlayController.clearLayer('current_solver_iterate');
                    obj.OverlayController.setSolution('solved_point',result.Solution);
                end
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
            obj.refreshSolveProgress();
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
        function onPresentationEvents(obj,batch)
            names={batch.Name};
            progressEvent=lmz.gui.PresentationEvents.SolveProgressChanged;
            if ~isempty(names)&&all(strcmp(names,progressEvent))
                % Iteration callbacks can arrive at solver frequency.  Keep
                % this path incremental: rebuilding section/shooting editors
                % here makes live diagnostics scale with the full workbench.
                obj.refreshSolveProgress();
                obj.applyControlState();
                return
            end
            obj.refresh(batch);
        end

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
            shooting=any(strcmp(obj.Controller.State.SolveMode, ...
                {'Multiple shooting','Horizon feasibility'}));
            enableControls(continuationControls, ...
                continueCapability&&~timingOnly&&~obj.IsBusy);
            setEnable(obj.SimulateButton,simulate&&~shooting&&~obj.IsBusy);
            evaluate=findobj(obj.Root,'Tag','lmz-solve-evaluate');
            setEnable(evaluate,~obj.IsBusy&&~isempty(obj.Controller.State.WorkingSolution));
            sectionControls={obj.StartSectionDropDown,obj.StopSectionDropDown, ...
                obj.StartSideDropDown,obj.StopSideDropDown, ...
                obj.CrossingDirectionDropDown,obj.MinimumReturnTimeField};
            enableControls(sectionControls,~obj.IsBusy&& ...
                ~isempty(obj.Controller.sectionIds()));
            setEnable(obj.TransferButton,~obj.IsBusy&& ...
                ~isempty(obj.Controller.State.WorkingSolution));
            setEnable(obj.EventMaskTable,~obj.IsBusy&&(timingOnly||shooting));
            shootingControls={obj.FormulationDropDown,obj.SolverDropDown, ...
                obj.HorizonLengthSpinner,obj.InterfaceMaskField, ...
                obj.ControlMaskField,obj.EnergyModeDropDown, ...
                obj.ResidualToleranceField,obj.TemplateInitializerDropDown};
            enableControls(shootingControls,shooting&&~obj.IsBusy);
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
            controls.FormulationDropDown=obj.FormulationDropDown;
            controls.SolverDropDown=obj.SolverDropDown;
            controls.HorizonLengthSpinner=obj.HorizonLengthSpinner;
            controls.InterfaceMaskField=obj.InterfaceMaskField;
            controls.ControlMaskField=obj.ControlMaskField;
            controls.EnergyModeDropDown=obj.EnergyModeDropDown;
            controls.ResidualToleranceField=obj.ResidualToleranceField;
            controls.TemplateInitializerDropDown=obj.TemplateInitializerDropDown;
            controls.ResidualClassificationLabel= ...
                obj.ResidualClassificationLabel;
            controls.ShootingDiagnosticsTable=obj.ShootingDiagnosticsTable;
            controls.IterationTable=obj.IterationTable;
            controls.SectionSupportLabel=obj.SectionSupportLabel;
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
                shooting=obj.Controller.shootingEditorData();
                if shooting.Available&&~isempty(shooting.EventNames)
                    rows=[shooting.EventNames(:), ...
                        num2cell(shooting.EventFreeMask(:)); ...
                        {'return_time',shooting.ReturnTimeFree}];
                    obj.EventMaskTable.Data=rows;
                    obj.FixedDataLabel.Text=sprintf([ ...
                        '%d-segment shooting: event schedules are explicit; ' ...
                        'interface/control masks are configured below.'], ...
                        shooting.SegmentCount);
                else
                    obj.EventMaskTable.Data=cell(0,2);
                    obj.FixedDataLabel.Text= ...
                        'Periodic mode: state and parameters are decision data.';
                end
            end
            crossing=[];
            if ~isempty(obj.Controller.State.TimingResult)
                crossing=obj.Controller.State.TimingResult.SectionCrossing;
            elseif ~isempty(obj.Controller.State.SectionTransferResult)
                crossing=obj.Controller.State.SectionTransferResult.Crossing;
            end
            obj.TransversalityLabel.Text=transversalityText(crossing);
            obj.refreshSectionSupport(start,stop);
        end

        function refreshShootingControls(obj)
            value=obj.Controller.shootingEditorData();
            configuration=value.Configuration;
            defaultInitializer=obj.configureInitializerItems(value);
            obj.FormulationDropDown.Value=fieldOr(configuration, ...
                'ShootingFormulation','multiple_shooting');
            obj.SolverDropDown.Value=fieldOr(configuration,'Solver','auto');
            obj.HorizonLengthSpinner.Value=fieldOr(configuration, ...
                'HorizonLength',2);
            obj.InterfaceMaskField.Value=maskText(fieldOr(configuration, ...
                'InterfaceStateMask',true));
            obj.ControlMaskField.Value=maskText(fieldOr(configuration, ...
                'ControlFreeMask',false));
            obj.EnergyModeDropDown.Value=fieldOr(configuration, ...
                'EnergyWorkMode','diagnostic_only');
            obj.ResidualToleranceField.Value=fieldOr(configuration, ...
                'ResidualTolerance',1e-7);
            initializer=fieldOr(configuration,'TemplateInitializer', ...
                'schema_defaults');
            if any(strcmp(initializer,{'schema_defaults', ...
                    'exact_source_horizon','nearest_compatible_template'}))&& ...
                    ~strcmp(defaultInitializer,'schema_defaults')
                initializer=defaultInitializer;
            end
            if ~any(strcmp(initializer,obj.TemplateInitializerDropDown.ItemsData))
                initializer=obj.TemplateInitializerDropDown.ItemsData{1};
            end
            obj.TemplateInitializerDropDown.Value=initializer;
            classification=value.ResidualClassification;
            obj.ResidualClassificationLabel.Text= ...
                ['Residual: ' strrep(classification,'_',' ')];
            obj.ResidualClassificationLabel.FontColor= ...
                classificationColor(classification);
            obj.ShootingDiagnosticsTable.Data=shootingRows( ...
                value,obj.Controller.State.ShootingResult);
        end

        function refreshRegisteredSolveDefaults(obj)
            key=[obj.Controller.State.ModelId '|' ...
                obj.Controller.State.WorkflowId];
            if strcmp(key,obj.RegisteredSolveDefaultsKey),return,end
            obj.RegisteredSolveDefaultsKey=key;
            if ismethod(obj.Controller,'generatedSeedRadius')
                try
                    radius=obj.Controller.generatedSeedRadius();
                    if isnumeric(radius)&&isscalar(radius)&& ...
                            isfinite(radius)&&radius>0
                        obj.SecondSeedRadiusField.Value=radius;
                    end
                catch
                end
            end
            if ismethod(obj.Controller,'solveDefaultOptions')
                try
                    defaults=obj.Controller.solveDefaultOptions();
                    obj.SolveButton.Tooltip=[ ...
                        'Refine the working solution. Registered defaults: ' ...
                        solveOptionsSummary(defaults)];
                catch
                end
            end
        end

        function defaultId=configureInitializerItems(obj,editor)
            descriptors=[];
            if nargin>=2&&isstruct(editor)&& ...
                    isfield(editor,'InitializerDescriptors')
                descriptors=editor.InitializerDescriptors;
            elseif ismethod(obj.Controller,'shootingInitializerDescriptors')
                try
                    descriptors=obj.Controller.shootingInitializerDescriptors();
                catch
                end
            end
            [ids,labels,defaultId]=initializerItems(descriptors);
            obj.TemplateInitializerDropDown.Items=labels;
            obj.TemplateInitializerDropDown.ItemsData=ids;
        end

        function refreshSectionSupport(obj,startId,stopId)
            rows=obj.Controller.sectionCombinationData();match=[];
            for index=1:numel(rows)
                if strcmp(rows(index).StartSectionId,startId)&& ...
                        strcmp(rows(index).StopSectionId,stopId)
                    match=rows(index);break
                end
            end
            if isempty(match)
                obj.SectionSupportLabel.Text= ...
                    'Section combination: unavailable';
            else
                obj.SectionSupportLabel.Text=sprintf( ...
                    'Section combination: %s — %s', ...
                    match.Classification,match.Reason);
            end
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
                if any(strcmp(obj.Controller.State.SolveMode, ...
                        {'Multiple shooting','Horizon feasibility'}))
                    obj.Controller.setShootingSettings(struct( ...
                        'EventFreeMask',[mask(:).' returnFree]));
                else
                    obj.Controller.setEventFreeMask(mask,returnFree);
                end
            catch exception
                obj.refresh();obj.reportError(exception);
            end
        end

        function shootingChanged(obj)
            try
                formulation=obj.FormulationDropDown.Value;
                horizonFormulation='periodic';
                if strcmp(obj.Controller.State.ProblemId, ...
                        'section_transition')
                    horizonFormulation='transition';
                elseif strcmp(formulation,'horizon_feasibility')
                    horizonFormulation='feasibility';
                end
                changes=struct('ShootingFormulation',formulation, ...
                    'Formulation',horizonFormulation, ...
                    'Solver',obj.SolverDropDown.Value, ...
                    'HorizonLength',obj.HorizonLengthSpinner.Value, ...
                    'InterfaceStateMask',parseMask( ...
                    obj.InterfaceMaskField.Value), ...
                    'ControlFreeMask',parseMask(obj.ControlMaskField.Value), ...
                    'EnergyWorkMode',obj.EnergyModeDropDown.Value, ...
                    'ResidualTolerance',obj.ResidualToleranceField.Value, ...
                    'TemplateInitializer', ...
                    obj.TemplateInitializerDropDown.Value);
                obj.Controller.setShootingSettings(changes);
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
            try
                obj.Controller.evaluateWorkingSolution(true);
            catch exception
                obj.reportError(exception);
            end
        end
        function solve(obj)
            try
                result=obj.Controller.solveWorkingSolution(struct());
                if ~isempty(obj.OverlayController)&& ...
                        isa(result,'lmz.data.SolveResult')
                    obj.OverlayController.clearLayer('current_solver_iterate');
                    obj.OverlayController.setSolution('solved_point', ...
                        result.Solution);
                end
            catch exception
                obj.reportError(exception);
            end
        end
        function simulate(obj)
            try
                obj.Controller.simulateWorkingSolution();
            catch exception
                obj.reportError(exception);
            end
        end
        function applyNoise(obj)
            try
                solution=obj.Controller.perturbWorkingSolution( ...
                    obj.NoiseMagnitudeField.Value, ...
                    'schema-scaled',obj.NoiseSeedSpinner.Value);
                if ~isempty(obj.OverlayController)
                    obj.OverlayController.setSolution('noise_candidate',solution);
                end
            catch exception
                obj.reportError(exception);
            end
        end
        function makeAdjacentSeed(obj)
            try
                direction=1;
                if strcmp(obj.DirectionDropDown.Value,'previous')
                    direction=-1;
                end
                obj.Controller.makeAdjacentSeedPair(direction,struct());
            catch exception
                obj.reportError(exception);
            end
        end
        function makeManualSeed(obj)
            try
                obj.Controller.makeManualSeedPair(obj.FirstIndexSpinner.Value, ...
                    obj.SecondIndexSpinner.Value,struct());
            catch exception
                obj.reportError(exception);
            end
        end
        function makeSecondSeed(obj)
            try
                obj.Controller.makeSecondSeed( ...
                    obj.SecondSeedRadiusField.Value);
            catch exception
                obj.reportError(exception);
            end
        end
        function describeSeedPair(obj,pair)
            indices=diagnosticField(pair.Diagnostics,'SourceIndices',[NaN NaN]);
            if isnumeric(indices)&&numel(indices)==2&&all(isfinite(indices))
                if abs(diff(indices))==1
                    source='Adjacent branch seed pair';
                else
                    source='Manual branch seed pair';
                end
                residuals=diagnosticField(pair.Diagnostics, ...
                    'ResidualNorms',[]);
                residuals=residuals(isfinite(residuals));
                if isempty(residuals)
                    obj.StatusLabel.Text=sprintf( ...
                        '%s %g → %g • radius %.5g',source, ...
                        indices(1),indices(2),pair.AchievedRadius);
                else
                    obj.StatusLabel.Text=sprintf( ...
                        '%s %g → %g • radius %.5g • max source residual %.3g', ...
                        source,indices(1),indices(2),pair.AchievedRadius, ...
                        max(residuals));
                end
            else
                residual=diagnosticField(pair.Diagnostics,'ResidualNorm',NaN);
                if isfinite(residual)
                    obj.StatusLabel.Text=sprintf( ...
                        'Generated second seed • radius %.5g • residual %.3g', ...
                        pair.AchievedRadius,residual);
                else
                    obj.StatusLabel.Text=sprintf( ...
                        'Generated second seed • radius %.5g', ...
                        pair.AchievedRadius);
                end
            end
            obj.plotSeedPair(pair);
        end
        function plotSeedPair(obj,pair)
            if ~isempty(obj.OverlayController)
                prediction=diagnosticField(pair.Diagnostics, ...
                    'Prediction',[]);
                if isempty(prediction)
                    % An adjacent/manual pair supersedes a generated predictor.
                    obj.OverlayController.clearLayer('predicted_seed');
                else
                    obj.OverlayController.setDecisions('predicted_seed', ...
                        prediction,pair.Second);
                end
                obj.OverlayController.setPair(pair);
            end
            if strcmp(obj.HostMode,'workspace')
                cla(obj.SeedAxes);title(obj.SeedAxes, ...
                    'Seed pair shown on persistent Branch / State Plot');
                return
            end
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

        function refreshSolveProgress(obj)
            progress=[];
            if isprop(obj.Controller.State,'SolveProgress')
                progress=obj.Controller.State.SolveProgress;
            end
            if isempty(progress)&&~isempty(obj.Controller.State.SolveResult)&& ...
                    isprop(obj.Controller.State.SolveResult,'Progress')
                progress=obj.Controller.State.SolveResult.Progress;
            end
            if isempty(progress)||~isa(progress,'lmz.data.SolveProgress')
                obj.IterationTable.Data=cell(0,6);return
            end
            snapshots=progress.Snapshots;rows=cell(numel(snapshots),6);
            for index=1:numel(snapshots)
                item=snapshots(index);
                rows(index,:)={item.Stage,item.Iteration,item.FunctionCount, ...
                    item.ScaledResidual,item.StepNorm,item.FirstOrderOptimality};
            end
            obj.IterationTable.Data=rows;
            if isempty(snapshots),return,end
            current=snapshots(end);
            obj.StatusLabel.Text=sprintf('%s • iteration %g • residual %.3g', ...
                strrep(current.Stage,'_',' '),current.Iteration, ...
                current.ScaledResidual);
            terminal=progress.Completed||any(strcmp(current.Stage,{ ...
                'solve_completed','solve_failed','controlled_stop'}));
            if terminal&&~isempty(obj.OverlayController)
                obj.OverlayController.clearLayer('current_solver_iterate');
            elseif ~isempty(obj.OverlayController)&& ...
                    ~isempty(current.DecisionValues)&& ...
                    ~isempty(obj.Controller.State.WorkingSolution)
                obj.OverlayController.setDecisions('current_solver_iterate', ...
                    current.DecisionValues,obj.Controller.State.WorkingSolution);
            end
            if strcmp(obj.HostMode,'workspace')&& ...
                    isempty(obj.Controller.State.ShootingResult)
                residuals=[snapshots.ScaledResidual];iterations=[snapshots.Iteration];
                finite=isfinite(residuals)&isfinite(iterations);
                cla(obj.SeedAxes);
                if any(finite)
                    semilogy(obj.SeedAxes,iterations(finite), ...
                        max(residuals(finite),realmin),'-o','LineWidth',1.4);
                end
                grid(obj.SeedAxes,'on');xlabel(obj.SeedAxes,'Iteration');
                ylabel(obj.SeedAxes,'Scaled residual');
                title(obj.SeedAxes,'Residual history');
            end
        end

        function refreshCandidateOverlay(obj)
            if isempty(obj.OverlayController),return,end
            working=obj.Controller.State.WorkingSolution;
            locked=obj.Controller.State.LockedSelection;
            if isempty(working)||isempty(locked)
                obj.OverlayController.clearLayer('edited_candidate');return
            end
            try
                source=obj.Controller.lockedSolution();
                changed=~isequaln(source.DecisionValues,working.DecisionValues)|| ...
                    ~isequaln(source.ParameterValues,working.ParameterValues);
                if changed
                    obj.OverlayController.setSolution('edited_candidate',working);
                else
                    obj.OverlayController.clearLayer('edited_candidate');
                    obj.OverlayController.clearLayer('noise_candidate');
                end
            catch
                obj.OverlayController.clearLayer('edited_candidate');
            end
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
function value=solveOptionsSummary(options)
if ~isstruct(options)||isempty(fieldnames(options)),value='engine defaults';return,end
preferred={'FunctionTolerance','StepTolerance','MaxIterations', ...
    'MaxFunctionEvaluations'};
parts={};
for index=1:numel(preferred)
    name=preferred{index};
    if ~isfield(options,name),continue,end
    item=options.(name);
    if isnumeric(item)&&isscalar(item)
        parts{end+1}=sprintf('%s=%.6g',name,item); %#ok<AGROW>
    end
end
if isempty(parts),value='registered workflow options'; ...
else,value=strjoin(parts,', ');end
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
function value=maskText(mask)
mask=logical(mask(:));
if isempty(mask)||all(mask)
    value='all';
elseif ~any(mask)
    value='none';
else
    value=strjoin(arrayfun(@(item)num2str(item),mask.', ...
        'UniformOutput',false),',');
end
end
function value=parseMask(source)
source=lower(strtrim(char(source)));
if strcmp(source,'all'),value=true;return,end
if strcmp(source,'none'),value=false;return,end
parts=regexp(source,'[,\s]+','split');parts=parts(~cellfun(@isempty,parts));
numbers=cellfun(@str2double,parts);
if isempty(numbers)||any(isnan(numbers))||any(~ismember(numbers,[0 1]))
    error('lmz:GUI:ShootingMaskText', ...
        'Masks must be all, none, or comma-separated 0/1 values.');
end
value=logical(numbers(:));
end
function value=classificationColor(classification)
if any(strcmp(classification,{'root_found','least_squares_feasible'}))
    value=[0.05 0.45 0.16];
elseif strcmp(classification,'not-run')
    value=[0.25 0.25 0.25];
else
    value=[0.75 0.2 0.1];
end
end
function rows=shootingRows(editor,result)
rows={'segments',num2str(editor.SegmentCount); ...
    'nodes',num2str(editor.NodeCount); ...
    'unknowns / residuals',sprintf('%d / %d', ...
    editor.UnknownCount,editor.ResidualCount)};
if isempty(result),return,end
report=result.FeasibilityReport;
rows(end+1,:)={'rank / nullity',sprintf('%d / %d', ...
    report.JacobianRank,report.Nullity)};
rows(end+1,:)={'condition',sprintf('%.4g',report.ConditionEstimate)};
rows(end+1,:)={'scaled residual',sprintf('%.4g',report.ScaledResidualNorm)};
rows(end+1,:)={'termination',report.TerminationReason};
rows(end+1,:)={'initializer history', ...
    initializerHistorySummary(result.InitializerHistory)};
rows(end+1,:)={'recovery history', ...
    recoveryHistorySummary(result.InitializerHistory)};
if ~isempty(report.SingularValues)
    singular=report.SingularValues;
    first=max(1,numel(singular)-2);
    rows(end+1,:)={'smallest singular values',mat2str( ...
        singular(first:end).',4)};
end
diagnostics=result.SolveResult.Evaluation.Diagnostics;
fields={'ContactNorms','InterfaceDefectNorms', ...
    'SectionResidualNorms','EnergyWorkResidualNorms'};
labels={'contact norms','interface defects','section residuals', ...
    'energy/work residuals'};
for index=1:numel(fields)
    if isfield(diagnostics,fields{index})
        rows(end+1,:)={labels{index}, ...
            mat2str(diagnostics.(fields{index}).',4)}; %#ok<AGROW>
    end
end
[energyDelta,declaredWork,deltaRecorded,workRecorded]= ...
    energyAuditProfiles(result,editor.SegmentCount);
rows(end+1,:)={'EnergyDelta by stride', ...
    recordedProfileText(energyDelta,deltaRecorded)};
rows(end+1,:)={'DeclaredWork by stride', ...
    recordedProfileText(declaredWork,workRecorded)};
end

function plotHorizonDiagnostics(axesHandle,result)
cla(axesHandle);hold(axesHandle,'on');
diagnostics=result.SolveResult.Evaluation.Diagnostics;
count=result.Horizon.segmentCount();
decoded=decodedShootingResult(result);
profiles={};labels={};
fields={'ContactNorms','InterfaceDefectNorms', ...
    'SectionResidualNorms','EnergyWorkResidualNorms'};
names={'contact','interface defect','section','energy/work'};
for index=1:numel(fields)
    if isfield(diagnostics,fields{index})
        profiles{end+1}=diagnostics.(fields{index})(:); %#ok<AGROW>
        labels{end+1}=names{index}; %#ok<AGROW>
    end
end
[extra,extraLabels]=sectionDefectProfiles(result,decoded,count);
profiles=[profiles extra];labels=[labels extraLabels];
[extra,extraLabels]=scheduleProfiles(decoded.Schedules,count);
profiles=[profiles extra];labels=[labels extraLabels];
[extra,extraLabels]=controlProfiles(decoded.Controls,count);
profiles=[profiles extra];labels=[labels extraLabels];
[energyDelta,declaredWork,deltaRecorded,workRecorded]= ...
    energyAuditProfiles(result,count);
profiles{end+1}=recordedProfile(energyDelta,deltaRecorded);
profiles{end+1}=recordedProfile(declaredWork,workRecorded);
if any(deltaRecorded)
    labels{end+1}='EnergyDelta';
else
    labels{end+1}='EnergyDelta (not recorded)';
end
if any(workRecorded)
    labels{end+1}='DeclaredWork';
else
    labels{end+1}='DeclaredWork (not recorded)';
end
for index=1:numel(profiles)
    values=profiles{index};
    plot(axesHandle,linspace(1,count,numel(values)), ...
        normalizedProfile(values),'-o','DisplayName',labels{index});
end
if isfield(result.SolveResult.Output,'ResidualHistory')
    values=result.SolveResult.Output.ResidualHistory(:);
    plot(axesHandle,linspace(1,count,numel(values)), ...
        normalizedProfile(values),'--','LineWidth',1.3, ...
        'DisplayName','solver residual history');
end
hold(axesHandle,'off');grid(axesHandle,'on');
xlabel(axesHandle,'Stride (solver history spans the horizon)');
ylabel(axesHandle,'Normalized magnitude; exact values are in the table');
title(axesHandle,'Horizon diagnostic profiles');
legend(axesHandle,'Location','best');
end

function value=initializerHistorySummary(history)
items=historyItems(history);entries={};
for index=1:numel(items)
    item=items{index};
    if ~isstruct(item)||~isscalar(item),continue,end
    entries{end+1}=historyEntryText(item,index); %#ok<AGROW>
end
value=limitedSummary(entries);
end

function value=recoveryHistorySummary(history)
parents=historyItems(history);entries={};
for parentIndex=1:numel(parents)
    parent=parents{parentIndex};
    if ~isstruct(parent)||~isscalar(parent),continue,end
    candidates={};
    if isfield(parent,'Attempts'),candidates=historyItems(parent.Attempts);end
    if isfield(parent,'RecoveryAttempts')
        candidates=[candidates;historyItems(parent.RecoveryAttempts)]; %#ok<AGROW>
    end
    for attemptIndex=1:numel(candidates)
        attempt=candidates{attemptIndex};
        if ~isstruct(attempt)||~isscalar(attempt),continue,end
        prefix=sprintf('entry %d attempt %d: ',parentIndex,attemptIndex);
        if isfield(parent,'StrideIndex')&&isnumeric(parent.StrideIndex)&& ...
                isscalar(parent.StrideIndex)&&isfinite(parent.StrideIndex)
            prefix=sprintf('stride %d attempt %d: ', ...
                parent.StrideIndex,attemptIndex);
        end
        entries{end+1}=[prefix historyEntryText( ...
            attempt,attemptIndex)]; %#ok<AGROW>
    end
end
value=limitedSummary(entries);
end

function value=historyEntryText(item,index)
name='record';
if isfield(item,'Strategy')&&ischar(item.Strategy)&& ...
        ~isempty(item.Strategy)
    name=item.Strategy;
elseif isfield(item,'Method')&&ischar(item.Method)&&~isempty(item.Method)
    name=item.Method;
end
states={};
if isfield(item,'Selected')&&isscalar(item.Selected)&&logical(item.Selected)
    states{end+1}='selected';
end
if isfield(item,'Accepted')&&isscalar(item.Accepted)
    if logical(item.Accepted)
        states{end+1}='accepted';
    else
        states{end+1}='rejected';
    end
end
if isfield(item,'SolverCompleted')&&isscalar(item.SolverCompleted)&& ...
        ~logical(item.SolverCompleted)
    states{end+1}='solver failed';
end
if isfield(item,'Classification')&&ischar(item.Classification)&& ...
        ~isempty(item.Classification)
    states{end+1}=strrep(item.Classification,'_',' ');
end
prefix=sprintf('%d: ',index);
if isfield(item,'StrideIndex')&&isnumeric(item.StrideIndex)&& ...
        isscalar(item.StrideIndex)&&isfinite(item.StrideIndex)
    prefix=sprintf('stride %d: ',item.StrideIndex);
end
if isempty(states),value=[prefix name]; ...
else,value=sprintf('%s%s [%s]',prefix,name,strjoin(states,', '));end
end

function value=limitedSummary(entries)
if isempty(entries),value='not recorded';return,end
limit=8;
if numel(entries)>limit
    omitted=numel(entries)-limit;entries=entries(1:limit);
    entries{end+1}=sprintf('+%d more',omitted);
end
value=strjoin(entries,'; ');
end

function value=historyItems(source)
if isempty(source)
    value={};
elseif iscell(source)
    value=source(:);
elseif isstruct(source)
    value=num2cell(source(:));
else
    value={};
end
end

function [delta,work,deltaRecorded,workRecorded]= ...
        energyAuditProfiles(result,count)
delta=nan(count,1);work=nan(count,1);
deltaRecorded=false(count,1);workRecorded=false(count,1);
for index=1:min(count,result.Horizon.segmentCount())
    specification=result.Horizon.Segments{index}.EnergyWorkSpecification;
    declared=fieldOr(specification,'DeclaredWork',[]);
    if isnumeric(declared)&&isreal(declared)&&isscalar(declared)&& ...
            isfinite(declared)
        work(index)=declared;workRecorded(index)=true;
    end
    if index>numel(result.SegmentResults),continue,end
    segment=result.SegmentResults{index};
    if ~isstruct(segment)||~isscalar(segment)|| ...
            ~isfield(segment,'Diagnostics')|| ...
            ~isstruct(segment.Diagnostics)
        continue
    end
    diagnostics=segment.Diagnostics;candidate=[];
    if isfield(diagnostics,'Energy')&& ...
            isstruct(diagnostics.Energy)&& ...
            isfield(diagnostics.Energy,'EnergyDelta')
        candidate=diagnostics.Energy.EnergyDelta;
    elseif isfield(diagnostics,'EnergyDelta')
        candidate=diagnostics.EnergyDelta;
    end
    if isnumeric(candidate)&&isreal(candidate)&&isscalar(candidate)&& ...
            isfinite(candidate)
        delta(index)=candidate;deltaRecorded(index)=true;
    end
end
end

function value=recordedProfile(source,recorded)
value=source(:);value(~recorded(:))=NaN;
end

function value=recordedProfileText(source,recorded)
source=source(:);recorded=logical(recorded(:));
if isempty(source)||~any(recorded),value='not recorded';return,end
if all(recorded),value=mat2str(source.',6);return,end
entries=cell(numel(source),1);
for index=1:numel(source)
    if recorded(index),entries{index}=sprintf('%d: %.6g',index,source(index)); ...
    else,entries{index}=sprintf('%d: not recorded',index);end
end
value=strjoin(entries,'; ');
end

function value=normalizedProfile(source)
value=abs(source(:));finite=value(isfinite(value));
if isempty(finite),scale=1;else,scale=max(finite);end
if scale==0,scale=1;end
value=value/scale;
end

function [profiles,labels]=sectionDefectProfiles(result,decoded,count)
names={};matrix=nan(count,0);
for index=1:min(count,numel(result.SegmentResults))
    segmentResult=result.SegmentResults{index};
    if ~isstruct(segmentResult)||~isfield(segmentResult, ...
            'TerminalCoordinates')
        continue
    end
    node=decoded.Nodes{index+1};
    localNames=node.StateSchema.CoordinateNames;
    values=segmentResult.TerminalCoordinates(:)- ...
        node.SectionCoordinates(:);
    [matrix,names]=assignNamedRow( ...
        matrix,names,index,count,localNames,values);
end
[profiles,labels]=profilesFromMatrix( ...
    matrix,names,'section defect ');
end

function [profiles,labels]=scheduleProfiles(schedules,count)
names={};matrix=nan(count,0);
for index=1:count
    schedule=schedules{index};
    if ~isa(schedule,'lmz.schedule.EventSchedule'),continue,end
    localNames=[schedule.names() {'return_time'}];
    values=[schedule.times();schedule.ReturnTime];
    [matrix,names]=assignNamedRow( ...
        matrix,names,index,count,localNames,values);
end
[profiles,labels]=profilesFromMatrix(matrix,names,'timing ');
end

function [profiles,labels]=controlProfiles(controls,count)
names={};matrix=nan(count,0);
for index=1:count
    [localNames,values]=controlEntries(controls{index});
    [matrix,names]=assignNamedRow( ...
        matrix,names,index,count,localNames,values);
end
[profiles,labels]=profilesFromMatrix(matrix,names,'control ');
end

function [names,values]=controlEntries(source)
names={};values=zeros(0,1);
if isnumeric(source)
    values=source(:);
    names=arrayfun(@(index)sprintf('value_%d',index), ...
        1:numel(values),'UniformOutput',false);
    return
end
if ~isstruct(source)||~isscalar(source),return,end
fields=fieldnames(source);
for index=1:numel(fields)
    item=source.(fields{index});
    if ~isnumeric(item)||~isreal(item)||any(~isfinite(item(:))),continue,end
    item=item(:);values=[values;item]; %#ok<AGROW>
    if isscalar(item)
        names{end+1}=fields{index}; %#ok<AGROW>
    else
        for subindex=1:numel(item)
            names{end+1}=sprintf('%s_%d', ...
                fields{index},subindex); %#ok<AGROW>
        end
    end
end
end

function value=decodedShootingResult(result)
count=result.Horizon.segmentCount();
schedules=cell(count,1);controls=cell(count,1);
for index=1:count
    schedules{index}=result.Horizon.Segments{index}.EventSchedule;
    controls{index}=result.Horizon.Segments{index}.ControlParameters;
end
value=struct('Nodes',{result.Horizon.Nodes}, ...
    'Schedules',{schedules},'Controls',{controls});
if ~isfield(result.Diagnostics,'ProblemContract')|| ...
        ~isfield(result.Diagnostics.ProblemContract,'DecisionSchema')
    return
end
schema=lmz.shooting.ShootingDecisionSchema.fromStruct( ...
    result.Diagnostics.ProblemContract.DecisionSchema);
value=schema.decode(result.SolveResult.Solution.DecisionValues, ...
    result.Horizon);
end

function [matrix,names]=assignNamedRow( ...
        matrix,names,row,count,localNames,values)
if ischar(localNames),localNames={localNames};end
for index=1:min(numel(localNames),numel(values))
    column=find(strcmp(localNames{index},names),1);
    if isempty(column)
        names{end+1}=localNames{index}; %#ok<AGROW>
        matrix(:,end+1)=nan(count,1); %#ok<AGROW>
        column=size(matrix,2);
    end
    matrix(row,column)=values(index);
end
end

function [profiles,labels]=profilesFromMatrix(matrix,names,prefix)
profiles=cell(1,size(matrix,2));labels=cell(1,size(matrix,2));
for index=1:size(matrix,2)
    profiles{index}=matrix(:,index);
    labels{index}=[prefix names{index}];
end
end
function value=solutionCoordinate(solution,name)
if any(strcmp(name,solution.DecisionSchema.names()))
    value=solution.decision(name);
elseif any(strcmp(name,solution.ParameterSchema.names()))
    value=solution.parameter(name);
elseif isfield(solution.Observables,name)
    value=solution.Observables.(name);
else
    value=NaN;
end
end

function [ids,labels,defaultId]=initializerItems(descriptors)
ids={'schema_defaults'};labels={'Schema defaults'};defaultId='schema_defaults';
if isempty(descriptors),return,end
if iscell(descriptors),values=descriptors;else,values=num2cell(descriptors(:));end
candidateIds={};candidateLabels={};candidateDefault='';
for index=1:numel(values)
    value=values{index};
    id=descriptorValue(value,'Id',descriptorValue(value,'id',''));
    label=descriptorValue(value,'Label',descriptorValue(value,'label',id));
    if isempty(id)||~ischar(id)||~ischar(label),continue,end
    candidateIds{end+1}=id;candidateLabels{end+1}=label; %#ok<AGROW>
    if descriptorValue(value,'IsDefault', ...
            descriptorValue(value,'isDefault',false))
        candidateDefault=id;
    end
end
if isempty(candidateIds),return,end
ids=candidateIds;labels=candidateLabels;
if isempty(candidateDefault),defaultId=ids{1};else,defaultId=candidateDefault;end
end

function value=descriptorValue(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name),value=source.(name);return,end
if isobject(source)&&isprop(source,name),value=source.(name);end
if isstring(value)&&isscalar(value),value=char(value);end
end
