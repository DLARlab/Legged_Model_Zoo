classdef LeggedModelZooApp < handle
    %LEGGEDMODELZOOAPP Programmatic standalone model browser and simulator.
    properties (SetAccess=private)
        Controller
        Figure
        ModelDropDown
        ProblemDropDown
        ExampleDropDown
        SimulateButton
        Axes
        TimeSlider
        StatusArea
        CapabilityLabel
        BranchAxes
        SolutionTable
        SolveStatus
        ContinuationAxes
        OptimizationAxes
    end
    methods
        function obj = LeggedModelZooApp(varargin)
            parser = inputParser;
            addParameter(parser, 'CreateFigure', true, @islogical);
            parse(parser, varargin{:});
            obj.Controller = lmz.gui.AppController();
            if parser.Results.CreateFigure
                obj.buildFigure();
                obj.refreshModel();
            end
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Access=private)
        function buildFigure(obj)
            obj.Figure = uifigure('Name', 'Legged Model Zoo', ...
                'Position', [100 100 1100 720]);
            obj.Figure.CloseRequestFcn = @(~,~) obj.closeRequested();
            root = uigridlayout(obj.Figure, [3 1]);
            root.RowHeight = {52, '1x', 92};

            header = uigridlayout(root, [1 8]);
            header.ColumnWidth = {140, 160, 90, 160, 85, 110, '1x', 110};
            uilabel(header, 'Text', 'Legged Model Zoo', ...
                'FontWeight', 'bold', 'FontSize', 16);
            obj.ModelDropDown = uidropdown(header, ...
                'Items', obj.Controller.modelIds(), ...
                'ValueChangedFcn', @(~,~) obj.modelChanged());
            uilabel(header, 'Text', 'Problem');
            obj.ProblemDropDown = uidropdown(header, ...
                'ValueChangedFcn', @(~,~) obj.problemChanged());
            uilabel(header, 'Text', 'Example');
            obj.ExampleDropDown = uidropdown(header, ...
                'Items', obj.Controller.builtInExamples());
            obj.CapabilityLabel = uilabel(header, 'Text', '');
            obj.SimulateButton = uibutton(header, 'Text', 'Simulate', ...
                'ButtonPushedFcn', @(~,~) obj.simulate());

            tabs = uitabgroup(root);
            simulationTab = uitab(tabs, 'Title', 'Simulation');
            simulationGrid = uigridlayout(simulationTab, [2 1]);
            simulationGrid.RowHeight = {'1x', 42};
            obj.Axes = uiaxes(simulationGrid);
            title(obj.Axes, 'Run a built-in demonstration');
            xlabel(obj.Axes, 'Horizontal position');
            ylabel(obj.Axes, 'Height');
            controls = uigridlayout(simulationGrid, [1 3]);
            controls.ColumnWidth = {120, '1x', 80};
            uilabel(controls, 'Text', 'Normalized time');
            obj.TimeSlider = uislider(controls, 'Limits', [0 1], ...
                'ValueChangedFcn', @(~,~) obj.updateTimeMarker());
            uilabel(controls, 'Text', '0–100%');

            obj.buildBranchTab(tabs);
            obj.buildSolutionTab(tabs);
            obj.buildSolveTab(tabs);
            obj.buildContinuationTab(tabs);
            obj.buildOptimizationTab(tabs);

            obj.StatusArea = uitextarea(root, 'Editable', 'off', ...
                'Value', {'Ready. Select a model and run its built-in demonstration.'});
        end

        function buildBranchTab(obj,tabs)
            tab=uitab(tabs,'Title','Branch');grid=uigridlayout(tab,[2 1]);grid.RowHeight={'1x',40};obj.BranchAxes=uiaxes(grid);
            controls=uigridlayout(grid,[1 3]);uibutton(controls,'Text','Reload built-in','ButtonPushedFcn',@(~,~)obj.reloadBranch());
            uibutton(controls,'Text','Select first','ButtonPushedFcn',@(~,~)obj.selectPoint(1));uibutton(controls,'Text','Select last','ButtonPushedFcn',@(~,~)obj.selectLastPoint());
        end
        function buildSolutionTab(obj,tabs)
            tab=uitab(tabs,'Title','Solution');grid=uigridlayout(tab,[2 1]);obj.SolutionTable=uitable(grid);uibutton(grid,'Text','Restore selected branch point','ButtonPushedFcn',@(~,~)obj.restoreSolution());
        end
        function buildSolveTab(obj,tabs)
            tab=uitab(tabs,'Title','Solve');grid=uigridlayout(tab,[3 1]);uibutton(grid,'Text','Solve selected solution','ButtonPushedFcn',@(~,~)obj.solve());obj.SolveStatus=uilabel(grid,'Text','Ready');uibutton(grid,'Text','Simulate solved solution','ButtonPushedFcn',@(~,~)obj.simulateSolved());
        end
        function buildContinuationTab(obj,tabs)
            tab=uitab(tabs,'Title','Continuation');grid=uigridlayout(tab,[2 1]);obj.ContinuationAxes=uiaxes(grid);controls=uigridlayout(grid,[1 2]);uibutton(controls,'Text','Make second seed','ButtonPushedFcn',@(~,~)obj.makeSecondSeed());uibutton(controls,'Text','Run short branch','ButtonPushedFcn',@(~,~)obj.continueBranch());
        end
        function buildOptimizationTab(obj,tabs)
            tab=uitab(tabs,'Title','Optimization');grid=uigridlayout(tab,[2 1]);obj.OptimizationAxes=uiaxes(grid);uibutton(grid,'Text','Run fit','ButtonPushedFcn',@(~,~)obj.optimize());
        end

        function modelChanged(obj)
            obj.Controller.selectModel(obj.ModelDropDown.Value);
            obj.refreshModel();
        end

        function problemChanged(obj)
            obj.Controller.State.ProblemId = obj.ProblemDropDown.Value;
        end

        function refreshModel(obj)
            obj.ModelDropDown.Value = obj.Controller.State.ModelId;
            problems = obj.Controller.problemIds();
            obj.ProblemDropDown.Items = problems;
            if any(strcmp(obj.Controller.State.ProblemId, problems))
                obj.ProblemDropDown.Value = obj.Controller.State.ProblemId;
            else
                obj.ProblemDropDown.Value = problems{1};
            end
            examples = obj.Controller.builtInExamples();
            obj.ExampleDropDown.Items = examples;
            obj.ExampleDropDown.Value = examples{1};
            obj.Controller.State.ExampleId = examples{1};
            capabilities = obj.Controller.capabilities();
            obj.SimulateButton.Enable = onOff(capabilities.simulate);
            obj.CapabilityLabel.Text = 'Simulation + visualization available';
            obj.StatusArea.Value = {obj.Controller.State.Status};
            cla(obj.Axes);
            title(obj.Axes, ['Built-in example: ' obj.Controller.State.ModelId], ...
                'Interpreter', 'none');
            obj.renderBranch();obj.renderSolution();
        end

        function simulate(obj)
            try
                obj.StatusArea.Value = {'Simulating...'};
                drawnow;
                result = obj.Controller.simulate(struct());
                names = obj.Controller.bodyTrajectoryNames();
                plot(obj.Axes, result.state(names{1}), result.state(names{2}), ...
                    'LineWidth', 2);
                grid(obj.Axes, 'on');
                xlabel(obj.Axes, names{1}, 'Interpreter', 'none');
                ylabel(obj.Axes, names{2}, 'Interpreter', 'none');
                title(obj.Axes, [obj.Controller.State.ModelId ' trajectory'], ...
                    'Interpreter', 'none');
                obj.StatusArea.Value = {obj.Controller.State.Status, ...
                    sprintf('%d samples, duration %.3g s', ...
                    numel(result.Time), result.Time(end))};
                obj.updateTimeMarker();
            catch exception
                obj.StatusArea.Value = {['ERROR: ' exception.message]};
            end
        end

        function updateTimeMarker(obj)
            result = obj.Controller.State.Simulation;
            if isempty(result), return, end
            names = obj.Controller.bodyTrajectoryNames();
            index = 1 + round(obj.TimeSlider.Value * (numel(result.Time) - 1));
            horizontal = result.state(names{1});
            vertical = result.state(names{2});
            hold(obj.Axes, 'on');
            markers = findobj(obj.Axes, 'Tag', 'CurrentTimeMarker');
            delete(markers);
            plot(obj.Axes, horizontal(index), vertical(index), ...
                'o', 'MarkerSize', 9, ...
                'MarkerFaceColor', [0.85 0.2 0.2], ...
                'Tag', 'CurrentTimeMarker');
            hold(obj.Axes, 'off');
        end

        function closeRequested(obj)
            obj.Controller.Context.Cancellation.cancel();
            obj.Figure.CloseRequestFcn = [];
            delete(obj.Figure);
            obj.Figure = [];
        end
        function reloadBranch(obj),obj.Controller.loadBuiltInBranch();obj.renderBranch();obj.renderSolution();end
        function selectPoint(obj,index),obj.Controller.selectBranchPoint(index);obj.renderSolution();end
        function selectLastPoint(obj),obj.selectPoint(obj.Controller.State.Datasets{1}.Branch.pointCount());end
        function restoreSolution(obj),obj.Controller.selectBranchPoint(obj.Controller.State.Selection.PointIndex);obj.renderSolution();end
        function renderBranch(obj)
            if isempty(obj.BranchAxes)||isempty(obj.Controller.State.Datasets),return,end
            branch=obj.Controller.State.Datasets{1}.Branch;names=branch.DecisionSchema.names();plot(obj.BranchAxes,branch.decision(names{1}),branch.decision(names{2}),'o-');xlabel(obj.BranchAxes,names{1},'Interpreter','none');ylabel(obj.BranchAxes,names{2},'Interpreter','none');grid(obj.BranchAxes,'on');
        end
        function renderSolution(obj)
            if isempty(obj.SolutionTable)||isempty(obj.Controller.State.WorkingSolution),return,end
            solution=obj.Controller.State.WorkingSolution;names=solution.DecisionSchema.names();values=num2cell(solution.DecisionValues);obj.SolutionTable.Data=[names,values];obj.SolutionTable.ColumnName={'Decision','Value'};
        end
        function solve(obj)
            try,result=obj.Controller.solveWorkingSolution(struct());obj.SolveStatus.Text=sprintf('Exit %d, residual %.3g',result.ExitFlag,result.Evaluation.ScaledResidualNorm);obj.renderSolution();catch exception,obj.SolveStatus.Text=exception.message;end
        end
        function simulateSolved(obj)
            solution=obj.Controller.State.WorkingSolution;if isempty(solution),return,end;model=obj.Controller.Registry.createModel(solution.ModelId);problem=model.createProblem(solution.ProblemId,struct());obj.Controller.State.Simulation=lmz.services.SolutionService().simulate(problem,solution,obj.Controller.Context);obj.StatusArea.Value={'Solved solution simulated'};
        end
        function makeSecondSeed(obj)
            try,pair=obj.Controller.makeSecondSeed(0.03);obj.StatusArea.Value={sprintf('Second seed radius %.4g',pair.AchievedRadius)};catch exception,obj.StatusArea.Value={exception.message};end
        end
        function continueBranch(obj)
            try,result=obj.Controller.runContinuation(struct('MaximumPoints',10,'BothDirections',true));branch=result.Branch;names=branch.DecisionSchema.names();plot(obj.ContinuationAxes,branch.decision(names{1}),branch.decision(names{2}),'o-');grid(obj.ContinuationAxes,'on');obj.StatusArea.Value={['Continuation: ' result.TerminationReason]};catch exception,obj.StatusArea.Value={exception.message};end
        end
        function optimize(obj)
            capabilities=obj.Controller.capabilities();if ~capabilities.optimize,obj.StatusArea.Value={'Selected model does not support optimization.'};return,end
            try,result=obj.Controller.runOptimization(struct());semilogy(obj.OptimizationAxes,max(result.History,eps),'o-');grid(obj.OptimizationAxes,'on');obj.StatusArea.Value={sprintf('Objective %.6g',result.Objective)};obj.renderSolution();catch exception,obj.StatusArea.Value={exception.message};end
        end
    end
end

function value = onOff(condition)
if condition, value = 'on'; else, value = 'off'; end
end
