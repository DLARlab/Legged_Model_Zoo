classdef PresentationEvents
    %PRESENTATIONEVENTS Valid presentation topics and deterministic order.
    properties (Constant)
        ModelChanged = 'ModelChanged'
        ProblemChanged = 'ProblemChanged'
        DatasetsChanged = 'DatasetsChanged'
        SelectionChanged = 'SelectionChanged'
        WorkingSolutionChanged = 'WorkingSolutionChanged'
        SimulationChanged = 'SimulationChanged'
        SolveResultChanged = 'SolveResultChanged'
        SeedPairChanged = 'SeedPairChanged'
        ContinuationChanged = 'ContinuationChanged'
        OptimizationChanged = 'OptimizationChanged'
        RunStateChanged = 'RunStateChanged'
        StatusChanged = 'StatusChanged'
        BranchViewChanged = 'BranchViewChanged'
        ExampleChanged = 'ExampleChanged'
        HoverChanged = 'HoverChanged'
    end

    methods (Static)
        function values = all()
            values = { ...
                lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.DatasetsChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.SimulationChanged, ...
                lmz.gui.PresentationEvents.SolveResultChanged, ...
                lmz.gui.PresentationEvents.SeedPairChanged, ...
                lmz.gui.PresentationEvents.ContinuationChanged, ...
                lmz.gui.PresentationEvents.OptimizationChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged, ...
                lmz.gui.PresentationEvents.StatusChanged, ...
                lmz.gui.PresentationEvents.BranchViewChanged, ...
                lmz.gui.PresentationEvents.ExampleChanged, ...
                lmz.gui.PresentationEvents.HoverChanged};
        end

        function validate(value)
            if isstring(value), value = char(value); end
            if ~ischar(value) || ~any(strcmp(value,lmz.gui.PresentationEvents.all()))
                error('lmz:GUI:PresentationEvent', ...
                    'Unknown presentation event %s.',displayText(value));
            end
        end

        function indices = order(values)
            if ischar(values)||isstring(values), values = cellstr(values); end
            known = lmz.gui.PresentationEvents.all();
            indices = zeros(size(values));
            for index = 1:numel(values)
                lmz.gui.PresentationEvents.validate(values{index});
                indices(index) = find(strcmp(values{index},known),1);
            end
        end
    end
end

function value = displayText(source)
if ischar(source), value = source;
elseif isstring(source)&&isscalar(source), value = char(source);
else, value = class(source);
end
end
