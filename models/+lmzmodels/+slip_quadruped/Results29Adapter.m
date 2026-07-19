classdef Results29Adapter
    %RESULTS29ADAPTER Exact legacy quadruped matrix boundary.
    methods
        function branch = loadBranch(~, path)
            loaded = load(path, 'results');
            if ~isfield(loaded, 'results')
                error('lmz:slip_quadruped:LegacyFormat', ...
                    'Expected variable results.');
            end
            branch = lmzmodels.slip_quadruped.Results29Adapter.decode(loaded.results);
        end
    end
    methods (Static)
        function branch = decode(results)
            if ~isnumeric(results) || size(results, 1) ~= 29 || ...
                    any(~isfinite(results(:)))
                error('lmz:slip_quadruped:LegacyFormat', ...
                    'Quadruped results must be a finite 29-row matrix.');
            end
            branch = struct('schemaVersion','legacy-results29-v1', ...
                'modelId','slip_quadruped','state',results(1:13,:), ...
                'eventTimes',results(14:22,:),'parameters',results(23:29,:), ...
                'pointCount',size(results,2));
        end
        function results = encode(branch)
            results = [branch.state; branch.eventTimes; branch.parameters];
            if size(results,1) ~= 29
                error('lmz:slip_quadruped:LegacyFormat', ...
                    'Encoded branch must have 29 rows.');
            end
        end
    end
end
