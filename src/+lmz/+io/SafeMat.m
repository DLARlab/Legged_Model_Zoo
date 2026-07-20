classdef SafeMat
    %SAFEMAT Preflight and recursively validate untrusted MAT inputs.
    properties (Constant, Access = private)
        DefaultMaximumBytes = 536870912
        DefaultMaximumElements = 20000000
        DefaultMaximumDepth = 64
    end
    methods (Static)
        function loaded = loadVariables(path, expectedNames, varargin)
            parser = inputParser;
            addRequired(parser, 'path', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addRequired(parser, 'expectedNames');
            addParameter(parser, 'ExactVariables', false, ...
                @(x) islogical(x) && isscalar(x));
            addParameter(parser, 'Root', '', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'MaximumBytes', ...
                lmz.io.SafeMat.DefaultMaximumBytes, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
            addParameter(parser, 'MaximumElements', ...
                lmz.io.SafeMat.DefaultMaximumElements, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
            addParameter(parser, 'MaximumDepth', ...
                lmz.io.SafeMat.DefaultMaximumDepth, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
            addParameter(parser, 'RequireFinite', false, ...
                @(x) islogical(x) && isscalar(x));
            parse(parser, path, expectedNames, varargin{:});
            options = parser.Results;
            names = lmz.compat.Text.cellstr(expectedNames, 'MAT variable names');
            if isempty(names) || numel(unique(names)) ~= numel(names) || ...
                    any(cellfun(@(x) isempty(regexp(x, ...
                    '^[A-Za-z][A-Za-z0-9_]*$', 'once')), names))
                error('lmz:Mat:VariableNames', ...
                    'Expected MAT variable names must be unique identifiers.');
            end
            path = lmz.util.PathGuard.canonical(options.path, true);
            if ~isempty(options.Root)
                lmz.util.PathGuard.assertWithin(options.Root, path);
            end
            information = dir(path);
            if information.bytes > options.MaximumBytes
                error('lmz:Mat:TooLarge', ...
                    'MAT input exceeds the %d-byte limit: %s', ...
                    options.MaximumBytes, path);
            end
            variables = whos('-file', path);
            actualNames = {variables.name};
            missing = setdiff(names, actualNames);
            if ~isempty(missing)
                error('lmz:Mat:MissingVariable', ...
                    'MAT input is missing required variable %s.', missing{1});
            end
            if options.ExactVariables && ...
                    (~isempty(setdiff(actualNames, names)) || numel(actualNames) ~= numel(names))
                error('lmz:Mat:UnexpectedVariable', ...
                    'MAT input contains unexpected top-level variables.');
            end
            allowedTop = {'double','single','logical','char','cell','struct', ...
                'string','int8','uint8','int16','uint16','int32','uint32', ...
                'int64','uint64'};
            for index = 1:numel(names)
                record = variables(strcmp(actualNames, names{index}));
                if isempty(record) || ~any(strcmp(record.class, allowedTop))
                    error('lmz:Mat:UnsafeTopLevelType', ...
                        'Variable %s has unsupported class %s.', ...
                        names{index}, record.class);
                end
                if prod(double(record.size)) > options.MaximumElements
                    error('lmz:Mat:Elements', ...
                        'Variable %s exceeds the element limit.', names{index});
                end
            end
            loaded = load(path, names{:});
            count = 0;
            for index = 1:numel(names)
                count = lmz.io.SafeMat.validateValue(loaded.(names{index}), ...
                    0, options, count, names{index});
            end
        end
    end

    methods (Static, Access = private)
        function count = validateValue(value, depth, options, count, location)
            if depth > options.MaximumDepth
                error('lmz:Mat:Depth', ...
                    'MAT value exceeds the nesting limit at %s.', location);
            end
            count = count + max(1, numel(value));
            if count > options.MaximumElements
                error('lmz:Mat:Elements', ...
                    'MAT values exceed the aggregate element limit.');
            end
            if isnumeric(value)
                if ~isreal(value)
                    error('lmz:Mat:Complex', ...
                        'Complex values are not allowed at %s.', location);
                end
                if options.RequireFinite && any(~isfinite(value(:)))
                    error('lmz:Mat:Nonfinite', ...
                        'Nonfinite values are not allowed at %s.', location);
                end
                return
            end
            if islogical(value) || ischar(value)
                return
            end
            if isstring(value)
                if any(ismissing(value(:)))
                    error('lmz:Mat:MissingString', ...
                        'Missing string values are not allowed at %s.', location);
                end
                lengths = strlength(value);
                count = count + sum(double(lengths(:)));
                if count > options.MaximumElements
                    error('lmz:Mat:Elements', ...
                        'MAT string data exceeds the aggregate element limit.');
                end
                return
            end
            if iscell(value)
                for index = 1:numel(value)
                    count = lmz.io.SafeMat.validateValue(value{index}, ...
                        depth + 1, options, count, ...
                        sprintf('%s{%d}', location, index));
                end
                return
            end
            if isstruct(value) && ~isobject(value)
                for element = 1:numel(value)
                    names = fieldnames(value(element));
                    for index = 1:numel(names)
                        count = lmz.io.SafeMat.validateValue( ...
                            value(element).(names{index}), depth + 1, ...
                            options, count, [location '.' names{index}]);
                    end
                end
                return
            end
            error('lmz:Mat:UnsafeType', ...
                'Unsupported MAT value class %s at %s.', class(value), location);
        end
    end
end
