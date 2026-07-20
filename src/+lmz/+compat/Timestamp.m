classdef Timestamp
    %TIMESTAMP Central timestamp formatting with an R2019b-safe fallback.
    methods (Static)
        function value = current(forceFallback)
            if nargin < 1
                forceFallback = false;
            end
            if ~forceFallback && exist('datetime', 'class') == 8
                try
                    instant = datetime('now', 'TimeZone', 'UTC', ...
                        'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
                    value = char(instant);
                    return
                catch
                    % The fallback deliberately avoids release-specific formats.
                end
            end
            value = datestr(now, 30);
        end

        function value = fileSafe()
            value = datestr(now, 'yyyymmdd_HHMMSSFFF');
        end
    end
end
