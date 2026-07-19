classdef Results29Layout
    %RESULTS29LAYOUT Sole named boundary for the legacy 29-row matrix.
    properties (Constant)
        StateRows = 1:13
        EventRows = 14:22
        ParameterRows = 23:29
        DecisionRows = 1:22
        RowCount = 29
    end
    methods (Static)
        function validate(results)
            if ~isnumeric(results) || ~isreal(results) || ...
                    size(results,1) ~= lmzmodels.slip_quadruped.Results29Layout.RowCount || ...
                    size(results,2) < 2 || any(~isfinite(results(:)))
                error('lmz:slip_quadruped:LegacyFormat', ...
                    'RoadMap results must be a finite real 29-row matrix with at least two columns.');
            end
            periods = results(22,:);
            if any(periods <= 0)
                error('lmz:slip_quadruped:InvalidPeriod', ...
                    'RoadMap stride periods must be positive.');
            end
            events = results(14:21,:);
            tolerance = 1e-10 * max(1, max(periods));
            if any(events(:) < -tolerance) || any(any(events > periods + tolerance))
                error('lmz:slip_quadruped:InvalidEventTime', ...
                    'RoadMap event times must lie within the stride period.');
            end
            parameters = results(23:29,:);
            if any(any(parameters([1:4 6:7],:) <= 0))
                error('lmz:slip_quadruped:InvalidParameter', ...
                    'Positive RoadMap parameters are invalid.');
            end
        end
    end
end
