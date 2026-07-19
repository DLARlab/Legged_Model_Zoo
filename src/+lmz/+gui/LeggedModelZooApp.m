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
            obj.ProblemDropDown = uidropdown(header);
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

            obj.addUnavailableTab(tabs, 'Branch', 'Branch import and exploration is not implemented.');
            obj.addUnavailableTab(tabs, 'Solution', 'Native solution editing is not implemented.');
            obj.addUnavailableTab(tabs, 'Solve', 'Root solving is not implemented.');
            obj.addUnavailableTab(tabs, 'Continuation', 'Continuation is not implemented.');
            obj.addUnavailableTab(tabs, 'Optimization', 'Optimization is not implemented.');

            obj.StatusArea = uitextarea(root, 'Editable', 'off', ...
                'Value', {'Ready. Select a model and run its built-in demonstration.'});
        end

        function addUnavailableTab(~, tabs, name, message)
            tab = uitab(tabs, 'Title', name);
            grid = uigridlayout(tab, [1 1]);
            uilabel(grid, 'Text', message, 'HorizontalAlignment', 'center');
        end

        function modelChanged(obj)
            obj.Controller.selectModel(obj.ModelDropDown.Value);
            obj.refreshModel();
        end

        function refreshModel(obj)
            obj.ModelDropDown.Value = obj.Controller.State.ModelId;
            problems = obj.Controller.problemIds();
            obj.ProblemDropDown.Items = problems;
            obj.ProblemDropDown.Value = problems{1};
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
    end
end

function value = onOff(condition)
if condition, value = 'on'; else, value = 'off'; end
end
