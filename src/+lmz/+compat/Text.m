classdef Text
    %TEXT Normalize public text inputs without requiring string arrays.
    methods (Static)
        function value = character(value, name)
            if nargin < 2
                name = 'value';
            end
            if ischar(value)
                return
            end
            if isstring(value) && isscalar(value)
                value = char(value);
                return
            end
            error('lmz:Compatibility:Text', ...
                '%s must be a character vector or scalar string.', name);
        end

        function values = cellstr(values, name)
            if nargin < 2
                name = 'values';
            end
            if ischar(values) || (isstring(values) && isscalar(values))
                values = {lmz.compat.Text.character(values, name)};
                return
            end
            if isstring(values)
                values = cellstr(values(:));
            end
            if ~iscell(values) || ~all(cellfun(@ischar, values))
                error('lmz:Compatibility:TextList', ...
                    '%s must contain text values.', name);
            end
        end
    end
end
