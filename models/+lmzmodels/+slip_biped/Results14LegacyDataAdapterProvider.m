classdef Results14LegacyDataAdapterProvider < ...
        lmz.workflow.LegacyDataAdapterProvider
    %RESULTS14LEGACYDATAADAPTERPROVIDER Results14 import/export boundary.
    methods
        function valid = canLoad(~,path)
            valid = false;
            if ~ischar(path) || exist(path,'file') ~= 2
                return
            end
            try
                variables = whos('-file',path);
                index = find(strcmp({variables.name},'results'),1);
                valid = ~isempty(index) && variables(index).size(1) == 14 && ...
                    numel(variables(index).size) == 2;
            catch
                valid = false;
            end
        end

        function branch = importBranch(obj,path,problem)
            if ~obj.canLoad(path)
                error('lmz:slip_biped:LegacyFormat', ...
                    'Expected a MAT file containing a 14-row results matrix.');
            end
            branch = lmzmodels.slip_biped.Results14Adapter. ...
                loadBranch(path,problem);
        end

        function exportBranch(~,path,branch)
            results = lmzmodels.slip_biped.Results14Adapter. ...
                encode(branch);
            save(path,'results');
        end
    end
end
