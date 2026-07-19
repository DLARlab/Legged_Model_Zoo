classdef FeasibilityPolicy
    %FEASIBILITYPOLICY Scientific validity checks kept outside the residual.
    methods (Static)
        function value = assess(decision, parameters, residual)
            messages = {};
            valid = numel(decision) == 22 && numel(parameters) == 7 && ...
                all(isfinite(decision(:))) && all(isfinite(parameters(:))) && ...
                all(isfinite(residual(:)));
            if ~valid, messages{end+1} = 'Candidate contains invalid or nonfinite values.'; end %#ok<AGROW>
            if numel(decision) == 22 && decision(22) <= 0
                valid = false; messages{end+1} = 'Stride period must be positive.'; %#ok<AGROW>
            end
            if numel(parameters) == 7 && any(parameters([1:4 6:7]) <= 0)
                valid = false; messages{end+1} = 'Physical parameters must be positive.'; %#ok<AGROW>
            end
            minimumGap = NaN;
            if numel(decision) == 22 && decision(22) > 0
                phases = sort(mod(decision(14:21),decision(22)));
                gaps = diff([phases;phases(1)+decision(22)]);
                minimumGap = min(gaps);
            end
            value = struct('Valid',valid,'Messages',{messages}, ...
                'MinimumEventGap',minimumGap);
        end
    end
end
