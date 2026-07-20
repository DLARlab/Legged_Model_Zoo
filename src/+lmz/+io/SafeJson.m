classdef SafeJson
    %SAFEJSON Bounded JSON loading for declarative repository inputs.
    properties (Constant, Access = private)
        DefaultMaximumBytes = 1048576
        DefaultMaximumDepth = 32
        DefaultMaximumItems = 100000
    end
    methods (Static)
        function value = read(path, varargin)
            parser = inputParser;
            addRequired(parser, 'path', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'Root', '', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'MaximumBytes', ...
                lmz.io.SafeJson.DefaultMaximumBytes, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
            addParameter(parser, 'MaximumDepth', ...
                lmz.io.SafeJson.DefaultMaximumDepth, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
            addParameter(parser, 'MaximumItems', ...
                lmz.io.SafeJson.DefaultMaximumItems, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
            parse(parser, path, varargin{:});
            options = parser.Results;
            path = lmz.util.PathGuard.canonical(options.path, true);
            if ~isempty(options.Root)
                lmz.util.PathGuard.assertWithin(options.Root, path);
            end
            information = dir(path);
            if information.bytes > options.MaximumBytes
                error('lmz:Json:TooLarge', ...
                    'JSON input exceeds the %d-byte limit: %s', ...
                    options.MaximumBytes, path);
            end
            value = lmz.compat.Json.read(path);
            count = 0;
            lmz.io.SafeJson.validateValue(value, 0, options, count);
        end
    end

    methods (Static, Access = private)
        function count = validateValue(value, depth, options, count)
            if depth > options.MaximumDepth
                error('lmz:Json:Depth', 'JSON input exceeds the nesting limit.');
            end
            count = count + max(1, numel(value));
            if count > options.MaximumItems
                error('lmz:Json:Items', 'JSON input exceeds the item limit.');
            end
            if isnumeric(value)
                if ~isreal(value) || any(~isfinite(value(:)))
                    error('lmz:Json:Numeric', ...
                        'JSON numeric values must be finite and real.');
                end
                return
            end
            if islogical(value) || ischar(value)
                return
            end
            if iscell(value)
                for index = 1:numel(value)
                    count = lmz.io.SafeJson.validateValue( ...
                        value{index}, depth + 1, options, count);
                end
                return
            end
            if isstruct(value)
                for element = 1:numel(value)
                    names = fieldnames(value(element));
                    for index = 1:numel(names)
                        count = lmz.io.SafeJson.validateValue( ...
                            value(element).(names{index}), depth + 1, ...
                            options, count);
                    end
                end
                return
            end
            error('lmz:Json:UnsafeType', ...
                'JSON decoded to an unsupported value of class %s.', class(value));
        end
    end
end
