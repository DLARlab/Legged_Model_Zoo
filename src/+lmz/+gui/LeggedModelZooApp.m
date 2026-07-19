classdef LeggedModelZooApp < handle
    %LEGGEDMODELZOOAPP Standalone model browser and RoadMap workbench.
    properties (SetAccess=private)
        Controller
        Figure
        ModelDropDown
        ProblemDropDown
        ExampleDropDown
        SimulateButton
        CapabilityLabel
        StatusArea

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
        AnimationRenderer
        AnimationPlayer

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
    end

    methods
        function obj=LeggedModelZooApp(varargin)
            parser=inputParser;
            addParameter(parser,'CreateFigure',true,@islogical);
            parse(parser,varargin{:});
            obj.Controller=lmz.gui.AppController();
            if any(strcmp('slip_quadruped',obj.Controller.modelIds()))
                obj.Controller.selectModel('slip_quadruped');
            end
            if parser.Results.CreateFigure
                obj.buildFigure();
                obj.refreshModel();
            end
        end

        function delete(obj)
            obj.stopAnimation();
            obj.Controller.stopCurrentRun();
            obj.Controller.stopRecording();
            if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end
        end
    end

    methods (Access=private)
        function buildFigure(obj)
            obj.Figure=uifigure('Name','Legged Model Zoo — Quadruped RoadMap', ...
                'Position',[40 40 1460 900]);
            obj.Figure.CloseRequestFcn=@(~,~)obj.closeRequested();
            obj.Figure.WindowButtonMotionFcn=@(~,~)obj.branchHovered();
            obj.Figure.KeyPressFcn=@(~,event)obj.navigateBranch(event);
            root=uigridlayout(obj.Figure,[3 1]);root.RowHeight={52,'1x',82};
            header=uigridlayout(root,[1 8]);header.ColumnWidth={145,165,75,165,70,170,'1x',110};
            uilabel(header,'Text','Legged Model Zoo','FontWeight','bold','FontSize',16);
            obj.ModelDropDown=uidropdown(header,'Items',obj.Controller.modelIds(), ...
                'ValueChangedFcn',@(~,~)obj.modelChanged());
            uilabel(header,'Text','Problem');
            obj.ProblemDropDown=uidropdown(header,'ValueChangedFcn',@(~,~)obj.problemChanged());
            uilabel(header,'Text','Example');
            obj.ExampleDropDown=uidropdown(header,'Items',obj.Controller.builtInExamples(), ...
                'ValueChangedFcn',@(~,~)obj.exampleChanged());
            obj.CapabilityLabel=uilabel(header,'Text','');
            obj.SimulateButton=uibutton(header,'Text','Run demo', ...
                'ButtonPushedFcn',@(~,~)obj.simulateDemo());
            tabs=uitabgroup(root);
            obj.buildSimulationTab(tabs);
            obj.buildBranchTab(tabs);
            obj.buildSolutionTab(tabs);
            obj.buildSolveTab(tabs);
            obj.buildContinuationTab(tabs);
            obj.buildOptimizationTab(tabs);
            obj.StatusArea=uitextarea(root,'Editable','off','Value',{'Ready.'});
        end

        function buildSimulationTab(obj,tabs)
            tab=uitab(tabs,'Title','Physical Simulation');
            grid=uigridlayout(tab,[3 2]);grid.RowHeight={'1x','1x',82};grid.ColumnWidth={'1.12x','1x'};
            obj.Axes=uiaxes(grid);place(obj.Axes,[1 2],1);title(obj.Axes,'Select and simulate a RoadMap point');

            trajectories=uitabgroup(grid);place(trajectories,1,2);
            torsoTab=uitab(trajectories,'Title','Torso');obj.TorsoAxes=uiaxes(torsoTab,'Position',[8 8 500 260]);
            backTab=uitab(trajectories,'Title','Back legs');obj.BackLegAxes=uiaxes(backTab,'Position',[8 8 500 260]);
            frontTab=uitab(trajectories,'Title','Front legs');obj.FrontLegAxes=uiaxes(frontTab,'Position',[8 8 500 260]);
            lower=uigridlayout(grid,[1 2]);place(lower,2,2);obj.GRFAxes=uiaxes(lower);obj.OscillatorAxes=uiaxes(lower);

            controls=uigridlayout(grid,[2 12]);place(controls,3,[1 2]);
            controls.RowHeight={30,34};controls.ColumnWidth={110,'1x','1x','1x',72,36,64,42,48,55,70,100};
            label=uilabel(controls,'Text','Normalized stride');place(label,1,1);
            obj.TimeSlider=uislider(controls,'Limits',[0 1], ...
                'ValueChangingFcn',@(~,event)obj.setAnimationTime(event.Value), ...
                'ValueChangedFcn',@(~,~)obj.setAnimationTime(obj.TimeSlider.Value));place(obj.TimeSlider,1,[2 4]);
            obj.NormalizedTimeField=uieditfield(controls,'numeric','Limits',[0 1],'Value',0, ...
                'ValueChangedFcn',@(~,~)obj.setAnimationTime(obj.NormalizedTimeField.Value));place(obj.NormalizedTimeField,1,5);
            label=uilabel(controls,'Text','FPS');place(label,1,6);
            obj.AnimationFPSSpinner=uispinner(controls,'Limits',[1 120],'Value',25,'Step',1);place(obj.AnimationFPSSpinner,1,7);
            label=uilabel(controls,'Text','Speed');place(label,1,8);
            obj.AnimationSpeedSpinner=uispinner(controls,'Limits',[0.1 10],'Value',1,'Step',0.1);place(obj.AnimationSpeedSpinner,1,9);
            obj.AnimationLoopCheckBox=uicheckbox(controls,'Text','Loop','Value',false);place(obj.AnimationLoopCheckBox,1,10);
            obj.AnimationForceCheckBox=uicheckbox(controls,'Text','Forces','Value',true, ...
                'ValueChangedFcn',@(~,~)obj.forceDisplayChanged());place(obj.AnimationForceCheckBox,1,11);
            obj.TrajectoryModeDropDown=uidropdown(controls,'Items',{'Complete','Progressive'}, ...
                'Value','Complete','ValueChangedFcn',@(~,~)obj.animationFrameChanged(obj.NormalizedTimeField.Value,[]));place(obj.TrajectoryModeDropDown,1,12);

            labels={'Play','Pause','Stop','Reset','Simulate point','GIF…','MP4…','Keyframes…','Export plots…','Oscillator GIF…','Cancel export'};
            callbacks={@()obj.playAnimation(),@()obj.pauseAnimation(),@()obj.stopAnimation(),@()obj.resetAnimation(), ...
                @()obj.simulateSelected(),@()obj.recordGif(),@()obj.recordMP4(),@()obj.recordKeyframes(), ...
                @()obj.exportSimulationPlots(),@()obj.recordOscillatorGif(),@()obj.Controller.stopRecording()};
            for index=1:numel(labels)
                button=uibutton(controls,'Text',labels{index},'ButtonPushedFcn',@(~,~)callbacks{index}());
                place(button,2,index);
            end
        end

        function buildBranchTab(obj,tabs)
            tab=uitab(tabs,'Title','RoadMap Branches');
            grid=uigridlayout(tab,[3 2]);grid.RowHeight={84,'1x',116};grid.ColumnWidth={'1x',315};
            buttons=uigridlayout(grid,[2 9]);place(buttons,1,[1 2]);buttons.ColumnWidth={165,95,85,92,105,90,105,105,'1x'};
            obj.RoadMapBranchDropDown=uidropdown(buttons);place(obj.RoadMapBranchDropDown,1,1);
            button=uibutton(buttons,'Text','Load selected','ButtonPushedFcn',@(~,~)obj.loadSelectedRoadMap());place(button,1,2);
            button=uibutton(buttons,'Text','Load all','ButtonPushedFcn',@(~,~)obj.loadAllBranches());place(button,1,3);
            button=uibutton(buttons,'Text','Open folder…','ButtonPushedFcn',@(~,~)obj.openBranchFolder());place(button,1,4);
            button=uibutton(buttons,'Text','Open MAT/artifact…','ButtonPushedFcn',@(~,~)obj.openBranchFile());place(button,1,5);
            button=uibutton(buttons,'Text','Reload','ButtonPushedFcn',@(~,~)obj.reloadActiveBranch());place(button,1,6);
            button=uibutton(buttons,'Text','Remove selected','ButtonPushedFcn',@(~,~)obj.removeActiveDataset());place(button,1,7);
            button=uibutton(buttons,'Text','Save native…','ButtonPushedFcn',@(~,~)obj.saveActiveBranch());place(button,1,8);
            button=uibutton(buttons,'Text','Export legacy…','ButtonPushedFcn',@(~,~)obj.exportLegacyBranch());place(button,1,9);
            button=uibutton(buttons,'Text','Plot selected','ButtonPushedFcn',@(~,~)obj.plotSelectedDataset());place(button,2,1);
            button=uibutton(buttons,'Text','Plot all','ButtonPushedFcn',@(~,~)obj.plotAllDatasets());place(button,2,2);
            button=uibutton(buttons,'Text','Clear plot','ButtonPushedFcn',@(~,~)obj.clearBranchPlot());place(button,2,3);
            button=uibutton(buttons,'Text','RoadMap preset','ButtonPushedFcn',@(~,~)obj.roadMapPreset());place(button,2,4);
            button=uibutton(buttons,'Text','Export plot…','ButtonPushedFcn',@(~,~)obj.exportBranchPlot());place(button,2,5);

            obj.BranchAxes=uiaxes(grid);place(obj.BranchAxes,2,1);obj.BranchAxes.XGrid='on';obj.BranchAxes.YGrid='on';title(obj.BranchAxes,'SLIP quadruped RoadMap');
            side=uigridlayout(grid,[4 1]);place(side,2,2);side.RowHeight={24,'1x',28,112};
            uilabel(side,'Text','Datasets (active selection)','FontWeight','bold');
            obj.BranchDatasetList=uilistbox(side,'ValueChangedFcn',@(~,~)obj.datasetChanged());
            obj.BranchVisibilityCheckBox=uicheckbox(side,'Text','Visible','Value',true, ...
                'ValueChangedFcn',@(~,~)obj.visibilityChanged());
            obj.BranchMetadataArea=uitextarea(side,'Editable','off','Value',{'No dataset'});

            axesControls=uigridlayout(grid,[3 10]);place(axesControls,3,[1 2]);
            axesControls.ColumnWidth={24,'1x',24,'1x',24,'1x',64,52,62,92};
            label=uilabel(axesControls,'Text','X');place(label,1,1);obj.BranchXDropDown=uidropdown(axesControls,'ValueChangedFcn',@(~,~)obj.axesChanged());place(obj.BranchXDropDown,1,2);
            label=uilabel(axesControls,'Text','Y');place(label,1,3);obj.BranchYDropDown=uidropdown(axesControls,'ValueChangedFcn',@(~,~)obj.axesChanged());place(obj.BranchYDropDown,1,4);
            label=uilabel(axesControls,'Text','Z');place(label,1,5);obj.BranchZDropDown=uidropdown(axesControls,'ValueChangedFcn',@(~,~)obj.axesChanged());place(obj.BranchZDropDown,1,6);
            obj.BranchDimensionDropDown=uidropdown(axesControls,'Items',{'2-D','3-D'},'ValueChangedFcn',@(~,~)obj.axesChanged());place(obj.BranchDimensionDropDown,1,7);
            label=uilabel(axesControls,'Text','Index');place(label,1,8);obj.BranchIndexSpinner=uispinner(axesControls,'Limits',[1 Inf],'Step',1,'RoundFractionalValues','on','ValueChangedFcn',@(~,~)obj.indexChanged());place(obj.BranchIndexSpinner,1,9);
            obj.BranchPercentSlider=uislider(axesControls,'Limits',[0 100],'ValueChangedFcn',@(~,~)obj.percentChanged());place(obj.BranchPercentSlider,1,10);

            label=uilabel(axesControls,'Text','Az');place(label,2,1);obj.BranchAzimuthSpinner=uispinner(axesControls,'Limits',[-180 180],'Value',0,'ValueChangedFcn',@(~,~)obj.viewChanged());place(obj.BranchAzimuthSpinner,2,2);
            label=uilabel(axesControls,'Text','El');place(label,2,3);obj.BranchElevationSpinner=uispinner(axesControls,'Limits',[-90 90],'Value',90,'ValueChangedFcn',@(~,~)obj.viewChanged());place(obj.BranchElevationSpinner,2,4);
            label=uilabel(axesControls,'Text','Aspect');place(label,2,5);obj.BranchAspectDropDown=uidropdown(axesControls,'Items',{'auto','equal'},'Value','auto','ValueChangedFcn',@(~,~)obj.viewChanged());place(obj.BranchAspectDropDown,2,6);
            label=uilabel(axesControls,'Text','Branch %');place(label,2,8);

            label=uilabel(axesControls,'Text','X lim');place(label,3,1);obj.BranchXLimitsField=uieditfield(axesControls,'text','Value','auto','ValueChangedFcn',@(~,~)obj.applyAxisLimits());place(obj.BranchXLimitsField,3,2);
            label=uilabel(axesControls,'Text','Y lim');place(label,3,3);obj.BranchYLimitsField=uieditfield(axesControls,'text','Value','auto','ValueChangedFcn',@(~,~)obj.applyAxisLimits());place(obj.BranchYLimitsField,3,4);
            label=uilabel(axesControls,'Text','Z lim');place(label,3,5);obj.BranchZLimitsField=uieditfield(axesControls,'text','Value','auto','ValueChangedFcn',@(~,~)obj.applyAxisLimits());place(obj.BranchZLimitsField,3,6);
            label=uilabel(axesControls,'Text','Use [min max] or auto');place(label,3,[8 10]);
        end

        function buildSolutionTab(obj,tabs)
            tab=uitab(tabs,'Title','Solution Inspector');root=uigridlayout(tab,[2 1]);root.RowHeight={'1x',80};groups=uitabgroup(root);
            [obj.SolutionTable,~]=obj.makeTableTab(groups,'Initial State',true);
            [obj.EventTable,~]=obj.makeTableTab(groups,'Event Timing',true);
            [obj.ParameterTable,~]=obj.makeTableTab(groups,'Parameters',true);
            [obj.ObservableTable,~]=obj.makeTableTab(groups,'Observables',false);
            [obj.ResidualTable,~]=obj.makeTableTab(groups,'Residual Blocks',false);
            [obj.DiagnosticsTable,~]=obj.makeTableTab(groups,'Diagnostics',false);
            [obj.ProvenanceTable,~]=obj.makeTableTab(groups,'Provenance',false);
            controls=uigridlayout(root,[2 5]);
            uibutton(controls,'Text','Validate/evaluate','ButtonPushedFcn',@(~,~)obj.evaluateSelected());
            uibutton(controls,'Text','Restore locked point','ButtonPushedFcn',@(~,~)obj.restoreSolution());
            obj.ProjectionModeDropDown=uidropdown(controls,'Items',{'Wrap cyclic times','Project ground contact'},'Value','Wrap cyclic times');
            uibutton(controls,'Text','Project event schedule','ButtonPushedFcn',@(~,~)obj.projectSolution());
            uibutton(controls,'Text','Simulate candidate','ButtonPushedFcn',@(~,~)obj.simulateSelected());
            uibutton(controls,'Text','Save solution…','ButtonPushedFcn',@(~,~)obj.saveWorkingSolution());
            uibutton(controls,'Text','Add candidate dataset','ButtonPushedFcn',@(~,~)obj.addWorkingDataset());
            uibutton(controls,'Text','Send to Solve','ButtonPushedFcn',@(~,~)obj.solve());
            uibutton(controls,'Text','Send to Continuation','ButtonPushedFcn',@(~,~)obj.sendWorkingToContinuation());
        end

        function [tableHandle,tab]=makeTableTab(obj,group,titleText,editable)
            tab=uitab(group,'Title',titleText);tableHandle=uitable(tab,'Units','normalized','Position',[0 0 1 1]);
            if editable
                tableHandle.ColumnName={'Name','Label','Value','Unit','Bounds','Scale','Edited'};
                tableHandle.ColumnEditable=[false false true false false false false];
                tableHandle.CellEditCallback=@(~,event)obj.solutionValueEdited(tableHandle,event);
            end
        end

        function buildSolveTab(obj,tabs)
            tab=uitab(tabs,'Title','Solve / Seeds');grid=uigridlayout(tab,[3 1]);grid.RowHeight={80,42,'1x'};
            controls=uigridlayout(grid,[2 10]);controls.ColumnWidth={72,88,105,54,70,54,70,90,72,'1x'};
            label=uilabel(controls,'Text','Direction');place(label,1,1);obj.SeedDirectionDropDown=uidropdown(controls,'Items',{'next','previous'},'Value','next');place(obj.SeedDirectionDropDown,1,2);
            button=uibutton(controls,'Text','Adjacent pair','ButtonPushedFcn',@(~,~)obj.makeAdjacentSeed());place(button,1,3);
            label=uilabel(controls,'Text','First');place(label,1,4);obj.SeedFirstIndexSpinner=uispinner(controls,'Limits',[1 Inf],'Value',1,'Step',1,'RoundFractionalValues','on');place(obj.SeedFirstIndexSpinner,1,5);
            label=uilabel(controls,'Text','Second');place(label,1,6);obj.SeedSecondIndexSpinner=uispinner(controls,'Limits',[1 Inf],'Value',2,'Step',1,'RoundFractionalValues','on');place(obj.SeedSecondIndexSpinner,1,7);
            button=uibutton(controls,'Text','Manual pair','ButtonPushedFcn',@(~,~)obj.makeManualSeed());place(button,1,8);
            label=uilabel(controls,'Text','Radius');place(label,1,9);obj.SecondSeedRadiusField=uieditfield(controls,'numeric','Limits',[1e-6 Inf],'Value',0.01);place(obj.SecondSeedRadiusField,1,10);
            button=uibutton(controls,'Text','Evaluate','ButtonPushedFcn',@(~,~)obj.evaluateSelected());place(button,2,1);
            button=uibutton(controls,'Text','Solve/refine','ButtonPushedFcn',@(~,~)obj.solve());place(button,2,2);
            button=uibutton(controls,'Text','Generated second seed','ButtonPushedFcn',@(~,~)obj.makeSecondSeed());place(button,2,3);
            label=uilabel(controls,'Text','Noise');place(label,2,4);obj.NoiseMagnitudeField=uieditfield(controls,'numeric','Limits',[0 Inf],'Value',0.001);place(obj.NoiseMagnitudeField,2,5);
            label=uilabel(controls,'Text','Seed');place(label,2,6);obj.NoiseSeedSpinner=uispinner(controls,'Limits',[0 Inf],'Value',123,'Step',1,'RoundFractionalValues','on');place(obj.NoiseSeedSpinner,2,7);
            button=uibutton(controls,'Text','Apply noise','ButtonPushedFcn',@(~,~)obj.applyNoise());place(button,2,8);
            button=uibutton(controls,'Text','Simulate solved','ButtonPushedFcn',@(~,~)obj.simulateSelected());place(button,2,9);
            obj.SolveStatus=uilabel(grid,'Text','Ready','WordWrap','on');place(obj.SolveStatus,2,1);
            obj.SeedAxes=uiaxes(grid);place(obj.SeedAxes,3,1);title(obj.SeedAxes,'RoadMap seed-pair overlay');obj.SeedAxes.XGrid='on';obj.SeedAxes.YGrid='on';
        end

        function buildContinuationTab(obj,tabs)
            tab=uitab(tabs,'Title','Continuation');grid=uigridlayout(tab,[3 1]);grid.RowHeight={'1x',84,38};
            obj.ContinuationAxes=uiaxes(grid);obj.ContinuationAxes.XGrid='on';obj.ContinuationAxes.YGrid='on';title(obj.ContinuationAxes,'Live RoadMap continuation overlay');
            controls=uigridlayout(grid,[2 9]);controls.ColumnWidth={62,64,105,65,65,65,115,'1x',105};
            label=uilabel(controls,'Text','Points');place(label,1,1);obj.ContinuationPointsSpinner=uispinner(controls,'Limits',[3 1000],'Value',20,'Step',1,'RoundFractionalValues','on');place(obj.ContinuationPointsSpinner,1,2);
            button=uibutton(controls,'Text','Run continuation','ButtonPushedFcn',@(~,~)obj.continueBranch());place(button,1,3);
            button=uibutton(controls,'Text','Pause','ButtonPushedFcn',@(~,~)obj.pauseContinuation());place(button,1,4);
            button=uibutton(controls,'Text','Resume','ButtonPushedFcn',@(~,~)obj.resumeContinuation());place(button,1,5);
            button=uibutton(controls,'Text','Stop','ButtonPushedFcn',@(~,~)obj.stopContinuation());place(button,1,6);
            button=uibutton(controls,'Text','Add result dataset','ButtonPushedFcn',@(~,~)obj.addContinuationDataset());place(button,1,7);
            button=uibutton(controls,'Text','Save result…','ButtonPushedFcn',@(~,~)obj.saveContinuationResult());place(button,1,9);
            label=uilabel(controls,'Text','Checkpoint');place(label,2,1);
            obj.ContinuationCheckpointField=uieditfield(controls,'text','Value','');place(obj.ContinuationCheckpointField,2,[2 4]);
            button=uibutton(controls,'Text','Choose…','ButtonPushedFcn',@(~,~)obj.chooseCheckpoint());place(button,2,5);
            button=uibutton(controls,'Text','Resume file','ButtonPushedFcn',@(~,~)obj.resumeCheckpoint());place(button,2,6);
            obj.ContinuationParameterDropDown=uidropdown(controls);place(obj.ContinuationParameterDropDown,2,7);
            obj.ContinuationTargetsField=uieditfield(controls,'text','Value','0 0.05');place(obj.ContinuationTargetsField,2,8);
            familyGrid=uigridlayout(controls,[1 2]);place(familyGrid,2,9);
            uibutton(familyGrid,'Text','Homotopy','ButtonPushedFcn',@(~,~)obj.runHomotopy());
            uibutton(familyGrid,'Text','Family','ButtonPushedFcn',@(~,~)obj.runFamilyScan());
            obj.ContinuationStatus=uilabel(grid,'Text','Ready','WordWrap','on');
        end

        function buildOptimizationTab(obj,tabs)
            tab=uitab(tabs,'Title','Optimization');grid=uigridlayout(tab,[2 1]);
            obj.OptimizationAxes=uiaxes(grid);
            uibutton(grid,'Text','Run fit (supported models)','ButtonPushedFcn',@(~,~)obj.optimize());
        end

        function modelChanged(obj)
            obj.stopAnimation();obj.Controller.selectModel(obj.ModelDropDown.Value);obj.refreshModel();
        end
        function problemChanged(obj),obj.Controller.State.ProblemId=obj.ProblemDropDown.Value;end
        function exampleChanged(obj),obj.Controller.State.ExampleId=obj.ExampleDropDown.Value;end

        function refreshModel(obj)
            obj.ModelDropDown.Value=obj.Controller.State.ModelId;
            problems=obj.Controller.problemIds();obj.ProblemDropDown.Items=problems;
            if any(strcmp(obj.Controller.State.ProblemId,problems)),obj.ProblemDropDown.Value=obj.Controller.State.ProblemId;else,obj.ProblemDropDown.Value=problems{1};end
            examples=obj.Controller.builtInExamples();obj.ExampleDropDown.Items=examples;obj.ExampleDropDown.Value=examples{1};obj.Controller.State.ExampleId=examples{1};
            capabilities=obj.Controller.capabilities();obj.SimulateButton.Enable=onOff(capabilities.simulate);
            obj.CapabilityLabel.Text=capabilityText(capabilities,obj.Controller.State.ModelId);
            obj.refreshRoadMapSelector();obj.refreshParameterSelector();obj.refreshDatasetControls();obj.renderBranch();obj.renderSolution();obj.StatusArea.Value={obj.Controller.State.Status};
        end

        function refreshRoadMapSelector(obj)
            if ~strcmp(obj.Controller.State.ModelId,'slip_quadruped')
                obj.RoadMapBranchDropDown.Items={'RoadMap unavailable'};obj.RoadMapBranchDropDown.ItemsData={''};return
            end
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();files=catalog.listBranches();labels=cell(size(files));
            for index=1:numel(files),[~,name,extension]=fileparts(files{index});labels{index}=[name extension];end
            obj.RoadMapBranchDropDown.Items=labels;obj.RoadMapBranchDropDown.ItemsData=files;obj.RoadMapBranchDropDown.Value=catalog.defaultBranchPath();
        end

        function refreshParameterSelector(obj)
            if isempty(obj.Controller.State.WorkingSolution),obj.ContinuationParameterDropDown.Items={'parameter'};return,end
            names=obj.Controller.State.WorkingSolution.ParameterSchema.names();obj.ContinuationParameterDropDown.Items=names;
            if any(strcmp('phi_neutral',names)),obj.ContinuationParameterDropDown.Value='phi_neutral';else,obj.ContinuationParameterDropDown.Value=names{1};end
        end

        function refreshDatasetControls(obj)
            datasets=obj.Controller.State.Datasets;items=cell(1,numel(datasets));ids=cell(1,numel(datasets));
            for index=1:numel(datasets)
                visible='○';if datasets{index}.Visible,visible='●';end
                gait=metadataField(datasets{index}.Metadata,'GaitSummary','');status=metadataField(datasets{index}.Metadata,'Status','');
                items{index}=sprintf('%s %s — %d points — %s — %s',visible,datasets{index}.Name,datasets{index}.Branch.pointCount(),shortText(gait,20),status);ids{index}=datasets{index}.Id;
            end
            obj.BranchDatasetList.Items=items;obj.BranchDatasetList.ItemsData=ids;
            if isempty(datasets)
                obj.BranchMetadataArea.Value={'No dataset loaded.'};return
            end
            obj.BranchDatasetList.Value=obj.Controller.State.ActiveDatasetId;dataset=obj.Controller.activeDataset();obj.BranchVisibilityCheckBox.Value=dataset.Visible;
            obj.BranchMetadataArea.Value=datasetMetadataLines(dataset);
            names=dataset.Branch.coordinateNames();obj.BranchXDropDown.Items=names;obj.BranchYDropDown.Items=names;obj.BranchZDropDown.Items=names;
            selected=obj.Controller.State.AxisVariables;while numel(selected)<3,selected{end+1}=names{min(numel(selected)+1,numel(names))};end
            for index=1:3,if ~any(strcmp(selected{index},names)),selected{index}=names{min(index,numel(names))};end,end
            obj.Controller.setAxisVariables(selected{1},selected{2},selected{3});
            obj.BranchXDropDown.Value=selected{1};obj.BranchYDropDown.Value=selected{2};obj.BranchZDropDown.Value=selected{3};
            n=dataset.Branch.pointCount();obj.BranchIndexSpinner.Limits=[1 n];
            selectedIndex=1;if ~isempty(obj.Controller.State.LockedSelection),selectedIndex=min(n,obj.Controller.State.LockedSelection.PointIndex);end
            obj.BranchIndexSpinner.Value=selectedIndex;obj.BranchPercentSlider.Value=100*(selectedIndex-1)/max(1,n-1);
            obj.SeedFirstIndexSpinner.Limits=[1 n];obj.SeedSecondIndexSpinner.Limits=[1 n];obj.SeedFirstIndexSpinner.Value=selectedIndex;obj.SeedSecondIndexSpinner.Value=min(n,selectedIndex+1);
            obj.refreshParameterSelector();
        end

        function simulateDemo(obj)
            try
                result=obj.Controller.simulate(struct());names=obj.Controller.bodyTrajectoryNames();
                plot(obj.Axes,result.state(names{1}),result.state(names{2}),'LineWidth',2);grid(obj.Axes,'on');xlabel(obj.Axes,names{1});ylabel(obj.Axes,names{2});title(obj.Axes,[obj.Controller.State.ModelId ' demonstration'],'Interpreter','none');obj.StatusArea.Value={obj.Controller.State.Status};
            catch exception,obj.showError(exception);end
        end

        function simulateSelected(obj)
            try
                if ~strcmp(obj.Controller.State.ModelId,'slip_quadruped'),error('lmz:GUI:QuadrupedView','Physical quadruped view requires slip_quadruped.');end
                obj.stopAnimation();simulation=obj.Controller.simulateWorkingSolution();
                obj.AnimationRenderer=lmzmodels.slip_quadruped.QuadrupedRenderer(obj.Axes,simulation);obj.AnimationRenderer.ShowForces=obj.AnimationForceCheckBox.Value;
                obj.AnimationPlayer=lmz.gui.AnimationController(simulation,obj.AnimationRenderer);obj.AnimationPlayer.FrameChangedFcn=@(value,index)obj.animationFrameChanged(value,index);
                lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotTorso(obj.TorsoAxes,simulation);
                lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotBackLegs(obj.BackLegAxes,simulation);
                lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotFrontLegs(obj.FrontLegAxes,simulation);
                lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotGRF(obj.GRFAxes,simulation);
                lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotOscillator(obj.OscillatorAxes,simulation);
                obj.animationFrameChanged(0,1);obj.StatusArea.Value={obj.Controller.State.Status};
            catch exception,obj.showError(exception);end
        end

        function setAnimationTime(obj,value)
            if isempty(obj.AnimationPlayer),return,end
            if obj.AnimationPlayer.IsPlaying,obj.AnimationPlayer.pause();end
            obj.AnimationPlayer.setNormalizedTime(value);
        end
        function animationFrameChanged(obj,value,~)
            if isempty(value)||~isfinite(value),return,end
            obj.TimeSlider.Value=max(0,min(1,value));obj.NormalizedTimeField.Value=obj.TimeSlider.Value;
            if isempty(obj.Controller.State.Simulation),return,end
            axesList=[obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes obj.GRFAxes];time=obj.Controller.State.Simulation.Time;
            if strcmp(obj.TrajectoryModeDropDown.Value,'Progressive')
                upper=time(1)+obj.TimeSlider.Value*(time(end)-time(1));upper=max(upper,time(min(2,numel(time))));
                for index=1:numel(axesList),xlim(axesList(index),[time(1) upper]);end
            else
                for index=1:numel(axesList),xlim(axesList(index),[time(1) time(end)]);end
            end
        end
        function playAnimation(obj)
            if isempty(obj.AnimationPlayer),obj.simulateSelected();end;if isempty(obj.AnimationPlayer),return,end
            obj.AnimationPlayer.FPS=obj.AnimationFPSSpinner.Value;obj.AnimationPlayer.Speed=obj.AnimationSpeedSpinner.Value;obj.AnimationPlayer.Loop=obj.AnimationLoopCheckBox.Value;obj.AnimationPlayer.play();
        end
        function pauseAnimation(obj),if ~isempty(obj.AnimationPlayer),obj.AnimationPlayer.pause();end,end
        function stopAnimation(obj),if ~isempty(obj.AnimationPlayer),obj.AnimationPlayer.stop();end,end
        function resetAnimation(obj),if ~isempty(obj.AnimationPlayer),obj.AnimationPlayer.reset();end,end
        function forceDisplayChanged(obj),if ~isempty(obj.AnimationRenderer),obj.AnimationRenderer.ShowForces=obj.AnimationForceCheckBox.Value;obj.AnimationRenderer.updateFrame(obj.AnimationRenderer.CurrentIndex);end,end

        function recordGif(obj),obj.recordAnimationWithDialog('gif','*.gif','Save quadruped animation',struct('FrameCount',40));end
        function recordMP4(obj),obj.recordAnimationWithDialog('mp4','*.mp4','Save quadruped video',struct('FrameCount',60,'FPS',obj.AnimationFPSSpinner.Value));end
        function recordKeyframes(obj),obj.recordAnimationWithDialog('keyframes',{'*.png';'*.pdf'},'Export animation keyframes',struct('NormalizedTimes',[0 .25 .5 .75 1]));end
        function recordAnimationWithDialog(obj,format,filter,titleText,options)
            if isempty(obj.AnimationRenderer),obj.simulateSelected();end;if isempty(obj.AnimationRenderer),return,end
            [file,path]=uiputfile(filter,titleText);if isequal(file,0),return,end
            try,obj.Controller.recordAnimation(format,fullfile(path,file),obj.AnimationRenderer,options);obj.animationFrameChanged(obj.AnimationPlayer.NormalizedTime,[]);obj.StatusArea.Value={['Saved ' fullfile(path,file)]};catch exception,obj.showError(exception);end
        end
        function recordOscillatorGif(obj)
            if isempty(obj.Controller.State.Simulation),obj.simulateSelected();end;if isempty(obj.Controller.State.Simulation),return,end
            [file,path]=uiputfile('*.gif','Save oscillator GIF');if isequal(file,0),return,end
            try
                obj.Controller.recordAxesGif(obj.OscillatorAxes,@(phase)obj.updateOscillatorCursor(phase),fullfile(path,file),struct('FrameCount',40));
                obj.updateOscillatorCursor(obj.NormalizedTimeField.Value);obj.StatusArea.Value={['Saved ' fullfile(path,file)]};
            catch exception,obj.showError(exception);end
        end
        function updateOscillatorCursor(obj,phase)
            delete(findobj(obj.OscillatorAxes,'Tag','OscillatorCursor'));cursor=xline(obj.OscillatorAxes,phase,'r-','LineWidth',2);cursor.Tag='OscillatorCursor';
        end
        function exportSimulationPlots(obj)
            if isempty(obj.Controller.State.Simulation),obj.simulateSelected();end;if isempty(obj.Controller.State.Simulation),return,end
            [file,path]=uiputfile({'*.png';'*.pdf'},'Export trajectory and force plots');if isequal(file,0),return,end
            [~,name,extension]=fileparts(file);axesList={obj.TorsoAxes,obj.BackLegAxes,obj.FrontLegAxes,obj.GRFAxes,obj.OscillatorAxes};suffix={'torso','back_legs','front_legs','grf','oscillator'};
            try,for index=1:numel(axesList),obj.Controller.exportPlot(axesList{index},fullfile(path,sprintf('%s_%s%s',name,suffix{index},extension)));end;obj.StatusArea.Value={sprintf('Exported five plot files to %s.',path)};catch exception,obj.showError(exception);end
        end

        function loadSelectedRoadMap(obj)
            try,obj.Controller.loadRoadMap(obj.RoadMapBranchDropDown.Value);obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function loadAllBranches(obj)
            try,obj.Controller.loadAllRoadMapBranches();obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function openBranchFolder(obj)
            folder=uigetdir(pwd,'Open folder containing MAT/artifact branches');if isequal(folder,0),return,end
            try,obj.Controller.openBranchFolder(folder);obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function openBranchFile(obj)
            [file,path]=uigetfile({'*.mat','MAT or LMZ artifact'},'Open branch');if isequal(file,0),return,end
            try,obj.Controller.openBranch(fullfile(path,file));obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function reloadActiveBranch(obj),try,obj.Controller.reloadActiveDataset();obj.selectionChanged();catch exception,obj.showError(exception);end,end
        function removeActiveDataset(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            try,obj.Controller.removeDataset(obj.Controller.State.ActiveDatasetId);obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function datasetChanged(obj),try,obj.Controller.setActiveDataset(obj.BranchDatasetList.Value);obj.selectionChanged();catch exception,obj.showError(exception);end,end
        function visibilityChanged(obj),try,obj.Controller.setDatasetVisibility(obj.Controller.State.ActiveDatasetId,obj.BranchVisibilityCheckBox.Value);obj.refreshDatasetControls();obj.renderBranch();catch exception,obj.showError(exception);end,end
        function plotSelectedDataset(obj)
            for index=1:numel(obj.Controller.State.Datasets),obj.Controller.setDatasetVisibility(obj.Controller.State.Datasets{index}.Id,strcmp(obj.Controller.State.Datasets{index}.Id,obj.Controller.State.ActiveDatasetId));end
            obj.refreshDatasetControls();obj.renderBranch();
        end
        function plotAllDatasets(obj),for index=1:numel(obj.Controller.State.Datasets),obj.Controller.setDatasetVisibility(obj.Controller.State.Datasets{index}.Id,true);end;obj.refreshDatasetControls();obj.renderBranch();end
        function clearBranchPlot(obj),for index=1:numel(obj.Controller.State.Datasets),obj.Controller.setDatasetVisibility(obj.Controller.State.Datasets{index}.Id,false);end;obj.refreshDatasetControls();obj.renderBranch();end

        function axesChanged(obj)
            try,obj.Controller.setAxisVariables(obj.BranchXDropDown.Value,obj.BranchYDropDown.Value,obj.BranchZDropDown.Value);obj.renderBranch();catch exception,obj.showError(exception);end
        end
        function roadMapPreset(obj)
            obj.BranchXDropDown.Value='dx';obj.BranchYDropDown.Value='dphi';obj.BranchZDropDown.Value='y';obj.BranchDimensionDropDown.Value='2-D';obj.BranchAzimuthSpinner.Value=0;obj.BranchElevationSpinner.Value=90;
            obj.BranchXLimitsField.Value='[0 10]';obj.BranchYLimitsField.Value='[-0.05 0.15]';obj.BranchZLimitsField.Value='[0.6 1.2]';obj.axesChanged();obj.applyAxisLimits();
        end
        function viewChanged(obj)
            if strcmp(obj.BranchDimensionDropDown.Value,'3-D'),view(obj.BranchAxes,obj.BranchAzimuthSpinner.Value,obj.BranchElevationSpinner.Value);else,view(obj.BranchAxes,2);end
            if strcmp(obj.BranchAspectDropDown.Value,'equal'),axis(obj.BranchAxes,'equal');else,axis(obj.BranchAxes,'normal');end
        end
        function applyAxisLimits(obj)
            try,applyLimit(obj.BranchAxes,'x',obj.BranchXLimitsField.Value);applyLimit(obj.BranchAxes,'y',obj.BranchYLimitsField.Value);applyLimit(obj.BranchAxes,'z',obj.BranchZLimitsField.Value);catch exception,obj.showError(exception);end
        end

        function renderBranch(obj)
            if isempty(obj.BranchAxes),return,end
            cla(obj.BranchAxes);if isempty(obj.Controller.State.Datasets),return,end
            hold(obj.BranchAxes,'on');names=obj.Controller.State.AxisVariables;is3=strcmp(obj.BranchDimensionDropDown.Value,'3-D');
            for index=1:numel(obj.Controller.State.Datasets)
                dataset=obj.Controller.State.Datasets{index};if ~dataset.Visible,continue,end
                x=dataset.Branch.coordinate(names{1});y=dataset.Branch.coordinate(names{2});style=dataset.DisplayStyle;
                if is3
                    z=dataset.Branch.coordinate(names{3});line=plot3(obj.BranchAxes,x,y,z,'Color',style.Color,'LineStyle',style.LineStyle,'LineWidth',1.8);
                else
                    line=plot(obj.BranchAxes,x,y,'Color',style.Color,'LineStyle',style.LineStyle,'LineWidth',1.8);
                end
                line.UserData=dataset.Id;line.ButtonDownFcn=@(~,event)obj.branchClicked(dataset.Id,event);
            end
            obj.plotLockedMarker();hold(obj.BranchAxes,'off');grid(obj.BranchAxes,'on');xlabel(obj.BranchAxes,names{1},'Interpreter','none');ylabel(obj.BranchAxes,names{2},'Interpreter','none');
            if is3,zlabel(obj.BranchAxes,names{3},'Interpreter','none');end;obj.viewChanged();obj.applyAxisLimits();
        end

        function plotLockedMarker(obj)
            selection=obj.Controller.State.LockedSelection;if isempty(selection),return,end
            dataset=obj.Controller.activeDataset();if ~strcmp(selection.DatasetId,dataset.Id)||~dataset.Visible,return,end
            names=obj.Controller.State.AxisVariables;index=selection.PointIndex;x=dataset.Branch.coordinate(names{1});y=dataset.Branch.coordinate(names{2});
            if strcmp(obj.BranchDimensionDropDown.Value,'3-D'),z=dataset.Branch.coordinate(names{3});plot3(obj.BranchAxes,x(index),y(index),z(index),'kp','MarkerFaceColor',[1 .85 0],'MarkerSize',12,'Tag','LockedPoint');else,plot(obj.BranchAxes,x(index),y(index),'kp','MarkerFaceColor',[1 .85 0],'MarkerSize',12,'Tag','LockedPoint');end
        end

        function branchHovered(obj)
            if isempty(obj.BranchAxes)||~isgraphics(obj.BranchAxes)||isempty(obj.Controller.State.Datasets),return,end
            try
                hit=hittest(obj.Figure);hitAxes=ancestor(hit,'axes');if isempty(hitAxes)||~isequal(hitAxes,obj.BranchAxes),return,end
                point=obj.BranchAxes.CurrentPoint;dimensions=2;if strcmp(obj.BranchDimensionDropDown.Value,'3-D'),dimensions=3;end
                coordinates=obj.Controller.State.AxisVariables(1:dimensions);[selection,details]=obj.Controller.hoverNearestVisiblePoint(coordinates,point(1,1:dimensions));
                delete(findobj(obj.BranchAxes,'Tag','HoverPoint'));delete(findobj(obj.BranchAxes,'Tag','HoverDataTip'));holdState=ishold(obj.BranchAxes);hold(obj.BranchAxes,'on');values=cell2mat(details.Values);
                if dimensions==3
                    plot3(obj.BranchAxes,values(1),values(2),values(3),'ko','MarkerFaceColor','w','MarkerSize',7,'Tag','HoverPoint');tip=text(obj.BranchAxes,values(1),values(2),values(3),hoverText(details,selection),'BackgroundColor','w','Margin',3,'Tag','HoverDataTip','Interpreter','none');
                else
                    plot(obj.BranchAxes,values(1),values(2),'ko','MarkerFaceColor','w','MarkerSize',7,'Tag','HoverPoint');tip=text(obj.BranchAxes,values(1),values(2),hoverText(details,selection),'BackgroundColor','w','Margin',3,'Tag','HoverDataTip','Interpreter','none');
                end
                tip.VerticalAlignment='bottom';if ~holdState,hold(obj.BranchAxes,'off');end
            catch
            end
        end

        function branchClicked(obj,datasetId,event)
            try
                if isprop(event,'IntersectionPoint'),target=event.IntersectionPoint;else,point=obj.BranchAxes.CurrentPoint;target=point(1,:);end
                dimensions=2;if strcmp(obj.BranchDimensionDropDown.Value,'3-D'),dimensions=3;end
                coordinates=obj.Controller.State.AxisVariables(1:dimensions);selection=obj.Controller.hoverNearestPoint(datasetId,coordinates,target(1:dimensions));obj.Controller.lockBranchPoint(datasetId,selection.PointIndex);obj.selectionChanged();
            catch exception,obj.showError(exception);end
        end

        function navigateBranch(obj,event)
            if isempty(obj.Controller.State.LockedSelection),return,end
            switch event.Key
                case {'leftarrow','downarrow'},delta=-1;
                case {'rightarrow','uparrow'},delta=1;
                otherwise,return
            end
            n=obj.Controller.activeDataset().Branch.pointCount();index=max(1,min(n,obj.Controller.State.LockedSelection.PointIndex+delta));obj.Controller.selectByIndex(index);obj.selectionChanged();
        end
        function indexChanged(obj),obj.Controller.selectByIndex(obj.BranchIndexSpinner.Value);obj.selectionChanged();end
        function percentChanged(obj),obj.Controller.selectByPercentage(obj.BranchPercentSlider.Value);obj.selectionChanged();end

        function selectionChanged(obj)
            obj.stopAnimation();obj.AnimationRenderer=[];obj.AnimationPlayer=[];
            axesList=[obj.Axes obj.TorsoAxes obj.BackLegAxes obj.FrontLegAxes obj.GRFAxes obj.OscillatorAxes obj.SeedAxes obj.ContinuationAxes];
            for index=1:numel(axesList),if isgraphics(axesList(index)),cla(axesList(index));end,end
            obj.refreshDatasetControls();obj.renderBranch();obj.renderSolution();obj.StatusArea.Value={obj.Controller.State.Status};
        end

        function renderSolution(obj)
            if isempty(obj.SolutionTable)||isempty(obj.Controller.State.WorkingSolution),return,end
            solution=obj.Controller.State.WorkingSolution;locked=obj.Controller.lockedSolution();
            obj.SolutionTable.Data=obj.schemaRows(solution.DecisionSchema,solution.DecisionValues,'initial_state',locked);
            obj.EventTable.Data=obj.schemaRows(solution.DecisionSchema,solution.DecisionValues,'event_timing',locked);
            obj.ParameterTable.Data=obj.schemaRows(solution.ParameterSchema,solution.ParameterValues,'parameter',locked);
            fields=fieldnames(solution.Observables);observableData=cell(numel(fields),2);for index=1:numel(fields),observableData{index,1}=fields{index};observableData{index,2}=displayValue(solution.Observables.(fields{index}));end
            obj.ObservableTable.Data=observableData;obj.ObservableTable.ColumnName={'Observable','Value'};
            rows=cell(numel(solution.ResidualBlocks),3);for index=1:numel(solution.ResidualBlocks),rows(index,:)={solution.ResidualBlocks(index).Name,displayValue(solution.ResidualBlocks(index).Values),norm(solution.ResidualBlocks(index).Values)};end
            obj.ResidualTable.Data=rows;obj.ResidualTable.ColumnName={'Residual block','Values','Norm'};
            diagnostics=solution.Diagnostics;diagnostics.Feasibility=solution.Feasibility;diagnostics.Classification=solution.Classification;
            obj.DiagnosticsTable.Data=structRows(diagnostics);obj.DiagnosticsTable.ColumnName={'Field','Value'};
            obj.ProvenanceTable.Data=structRows(solution.Provenance);obj.ProvenanceTable.ColumnName={'Field','Value'};
        end

        function rows=schemaRows(~,schema,values,group,locked)
            selected=arrayfun(@(spec)strcmp(spec.Group,group),schema.Specs);specs=schema.Specs(selected);indices=find(selected);rows=cell(numel(specs),7);
            lockedValues=[];if ~isempty(locked),if strcmp(group,'parameter'),lockedValues=locked.ParameterValues;else,lockedValues=locked.DecisionValues;end,end
            for index=1:numel(specs)
                spec=specs(index);edited=false;if ~isempty(lockedValues),edited=abs(values(indices(index))-lockedValues(indices(index)))>1e-12*max(1,abs(lockedValues(indices(index))));end
                rows(index,:)={spec.Name,spec.Label,values(indices(index)),spec.Unit,sprintf('[%g, %g]',spec.LowerBound,spec.UpperBound),spec.Scale,edited};
            end
        end

        function solutionValueEdited(obj,tableHandle,event)
            try
                if event.Indices(2)~=3,return,end;name=tableHandle.Data{event.Indices(1),1};value=event.NewData;if ischar(value)||isstring(value),value=str2double(value);end
                if ~isscalar(value)||~isfinite(value),error('lmz:GUI:EditValue','Edited values must be finite numeric scalars.');end
                obj.Controller.editWorkingValue(name,value);obj.selectionChanged();obj.StatusArea.Value={sprintf('Edited working-copy value %s.',name)};
            catch exception,obj.renderSolution();obj.showError(exception);end
        end

        function evaluateSelected(obj)
            try,evaluation=obj.Controller.evaluateWorkingSolution(true);obj.SolveStatus.Text=sprintf('Residual %.6g • gait %s',evaluation.ScaledResidualNorm,evaluation.Diagnostics.GaitAbbreviation);obj.StatusArea.Value={obj.SolveStatus.Text};obj.renderSolution();catch exception,obj.showError(exception);end
        end
        function restoreSolution(obj),obj.Controller.restoreWorkingSolution();obj.selectionChanged();obj.StatusArea.Value={'Restored the locked source point.'};end
        function projectSolution(obj)
            try
                options=struct('EnforceGroundContact',strcmp(obj.ProjectionModeDropDown.Value,'Project ground contact'));
                [~,diagnostics]=obj.Controller.projectWorkingSolution(options);obj.selectionChanged();obj.StatusArea.Value={sprintf('%s; event-time change %.3g',diagnostics.Method,diagnostics.ChangeNorm)};
            catch exception,obj.showError(exception);end
        end
        function saveWorkingSolution(obj)
            [file,path]=uiputfile('*.lmz.mat','Save working solution');if isequal(file,0),return,end
            try,obj.Controller.saveWorkingSolution(fullfile(path,file));obj.StatusArea.Value={obj.Controller.State.Status};catch exception,obj.showError(exception);end
        end
        function addWorkingDataset(obj)
            try,name=['candidate_' datestr(now,'yyyymmdd_HHMMSS')];obj.Controller.addWorkingSolutionToDataset(name);obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function sendWorkingToContinuation(obj),obj.makeSecondSeed();end

        function solve(obj)
            try
                original=obj.Controller.State.WorkingSolution;result=obj.Controller.solveWorkingSolution(struct());comparison=obj.Controller.compareSolutions(original,result.Solution);
                iterations=outputField(result.Output,'iterations',NaN);gait=classificationField(result.Solution.Classification,'Abbreviation','');status=sprintf('%s • exit %d • iterations %g • residual %.3g • gait %s • change %.3g',result.Output.algorithm,result.ExitFlag,iterations,result.Evaluation.ScaledResidualNorm,gait,norm(comparison.decisionDifference));obj.selectionChanged();obj.SolveStatus.Text=status;obj.StatusArea.Value={status};
            catch exception,obj.showError(exception);end
        end
        function applyNoise(obj)
            try,obj.Controller.perturbWorkingSolution(obj.NoiseMagnitudeField.Value,'schema-scaled',obj.NoiseSeedSpinner.Value);status=obj.Controller.State.Status;obj.selectionChanged();obj.StatusArea.Value={status};catch exception,obj.showError(exception);end
        end
        function makeAdjacentSeed(obj)
            try,direction=1;if strcmp(obj.SeedDirectionDropDown.Value,'previous'),direction=-1;end;pair=obj.Controller.makeAdjacentSeedPair(direction,struct());obj.describeSeedPair(pair);catch exception,obj.showError(exception);end
        end
        function makeManualSeed(obj)
            try,pair=obj.Controller.makeManualSeedPair(obj.SeedFirstIndexSpinner.Value,obj.SeedSecondIndexSpinner.Value,struct());obj.describeSeedPair(pair);catch exception,obj.showError(exception);end
        end
        function makeSecondSeed(obj)
            try,pair=obj.Controller.makeSecondSeed(obj.SecondSeedRadiusField.Value);obj.describeSeedPair(pair);catch exception,obj.showError(exception);end
        end
        function describeSeedPair(obj,pair)
            indices=diagnosticField(pair.Diagnostics,'SourceIndices',[NaN NaN]);residual=diagnosticField(pair.Diagnostics,'ResidualNorm',NaN);
            obj.SolveStatus.Text=sprintf('Seed pair %g → %g • radius %.5g • generated residual %.3g',indices(1),indices(2),pair.AchievedRadius,residual);obj.plotSeedPair(pair);obj.StatusArea.Value={obj.SolveStatus.Text};
        end
        function plotSeedPair(obj,pair)
            cla(obj.SeedAxes);hold(obj.SeedAxes,'on');names=obj.Controller.State.AxisVariables(1:2);dataset=obj.Controller.activeDataset();plot(obj.SeedAxes,dataset.Branch.coordinate(names{1}),dataset.Branch.coordinate(names{2}),'Color',[.75 .75 .75]);
            first=[solutionCoordinate(pair.First,names{1}) solutionCoordinate(pair.First,names{2})];second=[solutionCoordinate(pair.Second,names{1}) solutionCoordinate(pair.Second,names{2})];plot(obj.SeedAxes,first(1),first(2),'bo','MarkerFaceColor','b','DisplayName','first seed');plot(obj.SeedAxes,second(1),second(2),'ro','MarkerFaceColor','r','DisplayName','second seed');quiver(obj.SeedAxes,first(1),first(2),second(1)-first(1),second(2)-first(2),0,'k','LineWidth',1.5,'DisplayName','predictor');hold(obj.SeedAxes,'off');grid(obj.SeedAxes,'on');xlabel(obj.SeedAxes,names{1},'Interpreter','none');ylabel(obj.SeedAxes,names{2},'Interpreter','none');legend(obj.SeedAxes,'show','Location','best');
        end

        function continueBranch(obj)
            try
                if isempty(obj.Controller.State.SeedPair),obj.makeAdjacentSeed();end;if isempty(obj.Controller.State.SeedPair),return,end
                obj.initializeContinuationPlot();options=struct('MaximumPoints',obj.ContinuationPointsSpinner.Value,'BothDirections',false,'InitialStep',obj.Controller.State.SeedPair.AchievedRadius,'PredictionFcn',@(state)obj.continuationPrediction(state),'AcceptedFcn',@(state)obj.continuationAccepted(state),'RejectedFcn',@(state)obj.continuationRejected(state));
                if ~isempty(strtrim(obj.ContinuationCheckpointField.Value)),options.CheckpointPath=obj.ContinuationCheckpointField.Value;end
                result=obj.Controller.runContinuation(options);obj.renderContinuationResult(result);obj.ContinuationStatus.Text=sprintf('%s • %d accepted • %d rejected',result.TerminationReason,result.Branch.pointCount(),result.Diagnostics.rejectedAttempts);obj.StatusArea.Value={obj.ContinuationStatus.Text};
            catch exception,obj.showError(exception);end
        end
        function initializeContinuationPlot(obj)
            cla(obj.ContinuationAxes);hold(obj.ContinuationAxes,'on');names=obj.Controller.State.AxisVariables(1:2);dataset=obj.Controller.activeDataset();plot(obj.ContinuationAxes,dataset.Branch.coordinate(names{1}),dataset.Branch.coordinate(names{2}),'Color',[.78 .78 .78],'DisplayName','source RoadMap');pair=obj.Controller.State.SeedPair;first=[solutionCoordinate(pair.First,names{1}) solutionCoordinate(pair.First,names{2})];second=[solutionCoordinate(pair.Second,names{1}) solutionCoordinate(pair.Second,names{2})];plot(obj.ContinuationAxes,[first(1) second(1)],[first(2) second(2)],'bo-','LineWidth',1.5,'Tag','ContinuationAccepted','DisplayName','accepted');hold(obj.ContinuationAxes,'off');grid(obj.ContinuationAxes,'on');xlabel(obj.ContinuationAxes,names{1},'Interpreter','none');ylabel(obj.ContinuationAxes,names{2},'Interpreter','none');legend(obj.ContinuationAxes,'show','Location','best');
        end
        function continuationPrediction(obj,state)
            obj.Controller.State.ContinuationPreview=state;delete(findobj(obj.ContinuationAxes,'Tag','ContinuationPrediction'));names=obj.Controller.State.AxisVariables(1:2);
            try,x=predictedCoordinate(state.DecisionValues,obj.Controller.State.SeedPair.Second,names{1});y=predictedCoordinate(state.DecisionValues,obj.Controller.State.SeedPair.Second,names{2});holdState=ishold(obj.ContinuationAxes);hold(obj.ContinuationAxes,'on');plot(obj.ContinuationAxes,x,y,'kx','MarkerSize',10,'LineWidth',2,'Tag','ContinuationPrediction','DisplayName','prediction');if ~holdState,hold(obj.ContinuationAxes,'off');end;catch,end
            obj.ContinuationStatus.Text=sprintf('Predicting point %d • step %.4g • direction %+d',state.PointIndex,state.StepSize,state.Direction);drawnow limitrate
        end
        function continuationAccepted(obj,state)
            line=findobj(obj.ContinuationAxes,'Tag','ContinuationAccepted');names=obj.Controller.State.AxisVariables(1:2);x=solutionCoordinate(state.Solution,names{1});y=solutionCoordinate(state.Solution,names{2});set(line,'XData',[line.XData x],'YData',[line.YData y]);delete(findobj(obj.ContinuationAxes,'Tag','ContinuationPrediction'));gait=classificationField(state.Solution.Classification,'Abbreviation','');obj.ContinuationStatus.Text=sprintf('Accepted point %d • residual %.3g • step %.4g • gait %s',state.PointIndex,state.ResidualNorm,state.StepSize,gait);drawnow limitrate
        end
        function continuationRejected(obj,state),obj.ContinuationStatus.Text=sprintf('Rejected point %d • residual %.3g • step %.4g • %s',state.PointIndex,state.ResidualNorm,state.StepSize,state.Reason);drawnow limitrate,end
        function renderContinuationResult(obj,result)
            names=obj.Controller.State.AxisVariables(1:2);hold(obj.ContinuationAxes,'on');plot(obj.ContinuationAxes,result.Branch.coordinate(names{1}),result.Branch.coordinate(names{2}),'mo-','LineWidth',1.5,'DisplayName','result');hold(obj.ContinuationAxes,'off');
        end
        function pauseContinuation(obj),obj.Controller.pauseCurrentRun();obj.ContinuationStatus.Text='Paused';drawnow,end
        function resumeContinuation(obj),obj.Controller.resumeCurrentRun();obj.ContinuationStatus.Text='Running';drawnow,end
        function stopContinuation(obj),obj.Controller.stopCurrentRun();obj.ContinuationStatus.Text='Controlled stop requested';drawnow,end
        function chooseCheckpoint(obj),[file,path]=uiputfile('*.lmz.mat','Choose continuation checkpoint');if ~isequal(file,0),obj.ContinuationCheckpointField.Value=fullfile(path,file);end,end
        function resumeCheckpoint(obj)
            path=obj.ContinuationCheckpointField.Value;if isempty(path),[file,folder]=uigetfile('*.lmz.mat','Resume continuation checkpoint');if isequal(file,0),return,end;path=fullfile(folder,file);obj.ContinuationCheckpointField.Value=path;end
            try,result=obj.Controller.resumeCheckpoint(path,struct('MaximumPoints',obj.ContinuationPointsSpinner.Value));obj.initializeContinuationPlot();obj.renderContinuationResult(result);obj.ContinuationStatus.Text=sprintf('Resumed checkpoint: %s (%d points)',result.TerminationReason,result.Branch.pointCount());catch exception,obj.showError(exception);end
        end
        function addContinuationDataset(obj)
            try,result=obj.Controller.State.ContinuationResult;if isempty(result),error('lmz:GUI:ContinuationResult','No continuation result is available.');end;obj.Controller.addBranchDataset(['continuation_' datestr(now,'yyyymmdd_HHMMSS')],result.Branch);obj.selectionChanged();catch exception,obj.showError(exception);end
        end
        function saveContinuationResult(obj)
            result=obj.Controller.State.ContinuationResult;if isempty(result),obj.showError(MException('lmz:GUI:ContinuationResult','No continuation result is available.'));return,end
            [file,path]=uiputfile('*.lmz.mat','Save continuation branch');if isequal(file,0),return,end;try,obj.Controller.saveBranch(fullfile(path,file),result.Branch);obj.StatusArea.Value={['Saved ' fullfile(path,file)]};catch exception,obj.showError(exception);end
        end
        function runHomotopy(obj)
            try,targets=parseNumericList(obj.ContinuationTargetsField.Value);result=obj.Controller.runParameterHomotopy(obj.ContinuationParameterDropDown.Value,targets,struct());obj.ContinuationStatus.Text=sprintf('Homotopy completed %d targets.',result.Completed);catch exception,obj.showError(exception);end
        end
        function runFamilyScan(obj)
            try,targets=parseNumericList(obj.ContinuationTargetsField.Value);options=struct('SecondSeedRadius',obj.SecondSeedRadiusField.Value,'ContinuationOptions',struct('MaximumPoints',obj.ContinuationPointsSpinner.Value,'BothDirections',false));report=obj.Controller.runBranchFamilyScan(obj.ContinuationParameterDropDown.Value,targets,options);obj.ContinuationStatus.Text=sprintf('Family completed %d, skipped %d, failed %d, blocked %d.',report.Completed,report.Skipped,report.Failed,report.Blocked);catch exception,obj.showError(exception);end
        end

        function optimize(obj)
            if ~obj.Controller.capabilities().optimize,obj.StatusArea.Value={'Selected model does not support optimization.'};return,end
            try,result=obj.Controller.runOptimization(struct());semilogy(obj.OptimizationAxes,max(result.History,eps),'o-');grid(obj.OptimizationAxes,'on');obj.StatusArea.Value={sprintf('Objective %.6g',result.Objective)};obj.renderSolution();catch exception,obj.showError(exception);end
        end
        function saveActiveBranch(obj),[file,path]=uiputfile('*.lmz.mat','Save native branch');if isequal(file,0),return,end;try,obj.Controller.saveBranch(fullfile(path,file),obj.Controller.activeDataset().Branch);obj.StatusArea.Value={['Saved ' fullfile(path,file)]};catch exception,obj.showError(exception);end,end
        function exportLegacyBranch(obj),[file,path]=uiputfile('*.mat','Export legacy Results29 branch');if isequal(file,0),return,end;try,obj.Controller.exportLegacyBranch(fullfile(path,file),obj.Controller.activeDataset().Branch);obj.StatusArea.Value={['Saved ' fullfile(path,file)]};catch exception,obj.showError(exception);end,end
        function exportBranchPlot(obj),[file,path]=uiputfile({'*.png';'*.pdf'},'Export RoadMap plot');if isequal(file,0),return,end;try,obj.Controller.exportPlot(obj.BranchAxes,fullfile(path,file));obj.StatusArea.Value={['Saved ' fullfile(path,file)]};catch exception,obj.showError(exception);end,end

        function closeRequested(obj)
            obj.stopAnimation();obj.Controller.stopCurrentRun();obj.Controller.stopRecording();obj.Figure.CloseRequestFcn=[];delete(obj.Figure);obj.Figure=[];
        end
        function showError(obj,exception),obj.StatusArea.Value={['ERROR: ' exception.message]};end
    end
end

function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end
function value=onOff(condition),if condition,value='on';else,value='off';end,end
function text=capabilityText(capabilities,modelId)
parts={'simulation'};if strcmp(modelId,'slip_quadruped'),parts=[parts {'RoadMap','scientific solve','continuation'}];else,if capabilities.solve,parts{end+1}='solve';end;if capabilities.('continue'),parts{end+1}='continuation';end;end;text=strjoin(parts,' • ');
end
function text=displayValue(value)
if isnumeric(value),if isscalar(value),text=sprintf('%.8g',value);else,text=mat2str(value,5);end;elseif ischar(value),text=value;elseif isstring(value),text=char(value);elseif islogical(value),text=mat2str(value);elseif isstruct(value),text=sprintf('struct (%d fields)',numel(fieldnames(value)));else,text=class(value);end
end
function rows=structRows(value)
if ~isstruct(value),rows={'value',displayValue(value)};return,end
names=fieldnames(value);rows=cell(numel(names),2);for index=1:numel(names),rows(index,:)={names{index},displayValue(value.(names{index}))};end
end
function value=metadataField(metadata,name,fallback),if isstruct(metadata)&&isfield(metadata,name),value=metadata.(name);else,value=fallback;end;if isnumeric(value),value=mat2str(value,4);end;end
function text=shortText(value,count),if isstring(value),value=char(value);end;if ~ischar(value),value=displayValue(value);end;if numel(value)>count,text=[value(1:count-1) '…'];else,text=value;end,end
function lines=datasetMetadataLines(dataset)
[~,file,extension]=fileparts(dataset.SourcePath);if isempty(file),source='in-memory';else,source=[file extension];end
lines={sprintf('Source: %s',source),sprintf('Status: %s',metadataField(dataset.Metadata,'Status','')),sprintf('Gait: %s',metadataField(dataset.Metadata,'GaitSummary','')),sprintf('Parameters: %s',metadataField(dataset.Metadata,'ParameterSummary','')),sprintf('Style: %s, RGB %s',dataset.DisplayStyle.LineStyle,mat2str(dataset.DisplayStyle.Color,3)),sprintf('Read-only: %s',mat2str(dataset.ReadOnly))};
end
function applyLimit(ax,dimension,text)
if strcmpi(strtrim(text),'auto'),switch dimension,case 'x',xlim(ax,'auto');case 'y',ylim(ax,'auto');case 'z',zlim(ax,'auto');end;return,end
values=sscanf(regexprep(text,'[\[\],;]',' '),'%f');if numel(values)~=2||values(1)>=values(2),error('lmz:GUI:AxisLimits','Axis limits require [minimum maximum].');end
switch dimension,case 'x',xlim(ax,values.');case 'y',ylim(ax,values.');case 'z',zlim(ax,values.');end
end
function text=hoverText(details,selection)
solution=details.Solution;coordinates=cell(1,numel(details.Coordinates));for index=1:numel(coordinates),coordinates{index}=sprintf('%s=%.5g',details.Coordinates{index},details.Values{index});end
parameterNames=solution.ParameterSchema.names();parameterParts=cell(1,numel(parameterNames));for index=1:numel(parameterNames),parameterParts{index}=sprintf('%s=%.4g',parameterNames{index},solution.ParameterValues(index));end
gait=classificationField(solution.Classification,'Abbreviation','?');residual=diagnosticField(solution.Diagnostics,'ResidualNorm',NaN);text=sprintf('%s #%d\n%s\ngait=%s residual=%.3g\n%s',details.Dataset.Name,selection.PointIndex,strjoin(coordinates,', '),gait,residual,strjoin(parameterParts,', '));
end
function value=classificationField(classification,name,fallback),if isstruct(classification)&&isfield(classification,name),value=classification.(name);else,value=fallback;end,end
function value=diagnosticField(diagnostics,name,fallback),if isstruct(diagnostics)&&isfield(diagnostics,name),value=diagnostics.(name);else,value=fallback;end,end
function value=outputField(output,name,fallback),if isstruct(output)&&isfield(output,name),value=output.(name);else,value=fallback;end,end
function value=solutionCoordinate(solution,name)
if any(strcmp(name,solution.DecisionSchema.names())),value=solution.decision(name);elseif any(strcmp(name,solution.ParameterSchema.names())),value=solution.parameter(name);elseif isfield(solution.Observables,name)&&isscalar(solution.Observables.(name)),value=solution.Observables.(name);else,error('lmz:GUI:Coordinate','Coordinate %s is unavailable for this solution.',name);end
end
function value=predictedCoordinate(decision,reference,name)
if any(strcmp(name,reference.DecisionSchema.names())),value=decision(reference.DecisionSchema.indexOf(name));elseif any(strcmp(name,reference.ParameterSchema.names())),value=reference.parameter(name);else,error('lmz:GUI:PredictionCoordinate','Prediction has no observable coordinate.');end
end
function values=parseNumericList(text),values=sscanf(strrep(text,',',' '),'%f').';if isempty(values)||any(~isfinite(values)),error('lmz:GUI:Targets','Enter one or more finite numeric targets.');end,end
