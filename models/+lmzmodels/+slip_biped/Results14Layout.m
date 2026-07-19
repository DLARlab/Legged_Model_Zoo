classdef Results14Layout
    %RESULTS14LAYOUT Lossless layout of published biped branch matrices.
    properties (Constant)
        RowCount = 14
        DecisionRows = 1:12
        ParameterRows = 13:14
        DecisionNames = {'dx','y','dy','alphaL','dalphaL','alphaR', ...
            'dalphaR','tL_TD','tL_LO','tR_TD','tR_LO','tAPEX'}
        ParameterNames = {'offset_left','offset_right'}
    end
    methods (Static)
        function validate(results)
            if ~isnumeric(results) || ndims(results) ~= 2 || ...
                    size(results,1) ~= lmzmodels.slip_biped.Results14Layout.RowCount || ...
                    isempty(results) || any(~isfinite(results(:)))
                error('lmz:slip_biped:LegacyFormat', ...
                    'Results14 must be a finite, nonempty 14-by-N matrix.');
            end
            if any(results(12,:) <= 0)
                error('lmz:slip_biped:LegacyFormat', ...
                    'Every Results14 stride period must be positive.');
            end
        end
    end
end
