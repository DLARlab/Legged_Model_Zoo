classdef Results29Adapter
    % Legacy schema: rows 1:13 state, 14:22 event times, 23:29 parameters.
    methods
        function branch=loadBranch(~,path)
            raw=load(path); if ~isfield(raw,'results'), error('lmz:LegacyFormat','Expected variable results.'); end
            branch=lmzmodels.slipquadruped.Results29Adapter.decode(raw.results);
        end
    end
    methods (Static)
        function branch=decode(results)
            if ~isnumeric(results)||size(results,1)~=29, error('lmz:LegacyFormat','Quadruped results must have 29 rows.'); end
            branch=struct('schemaVersion','legacy-results29-v1','state',results(1:13,:), ...
                'eventTimes',results(14:22,:),'parameters',results(23:29,:),'pointCount',size(results,2));
        end
        function results=encode(branch)
            results=[branch.state;branch.eventTimes;branch.parameters];
            if size(results,1)~=29, error('lmz:LegacyFormat','Encoded branch must have 29 rows.'); end
        end
    end
end
