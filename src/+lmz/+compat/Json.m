classdef Json
    %JSON Central JSON and text-file helpers.
    methods (Static)
        function value = read(path)
            path = lmz.compat.Text.character(path, 'JSON path');
            if exist(path, 'file') ~= 2
                error('lmz:Compatibility:MissingJson', ...
                    'JSON file does not exist: %s', path);
            end
            value = lmz.compat.Json.decode(fileread(path));
        end

        function value = decode(text)
            text = lmz.compat.Text.character(text, 'JSON text');
            try
                value = jsondecode(text);
            catch exception
                error('lmz:Compatibility:InvalidJson', ...
                    'Could not decode JSON: %s', exception.message);
            end
        end

        function text = encode(value, pretty)
            if nargin < 2
                pretty = false;
            end
            if pretty
                try
                    text = jsonencode(value, 'PrettyPrint', true);
                    return
                catch
                    % PrettyPrint is optional on compatibility releases.
                end
            end
            text = jsonencode(value);
        end
    end
end
