classdef Results29LegacyDataAdapterProvider < ...
        lmz.workflow.LegacyDataAdapterProvider
    %RESULTS29LEGACYDATAADAPTERPROVIDER Results29 import/export boundary.
    methods
        function valid = canLoad(~,path)
            valid = false;
            if ~ischar(path) || exist(path,'file') ~= 2
                return
            end
            try
                variables = whos('-file',path);
                index = find(strcmp({variables.name},'results'),1);
                valid = ~isempty(index) && variables(index).size(1) == 29 && ...
                    numel(variables(index).size) == 2;
            catch
                valid = false;
            end
        end

        function branch = importBranch(obj,path,problem)
            if ~obj.canLoad(path)
                error('lmz:slip_quadruped:LegacyFormat', ...
                    'Expected a MAT file containing a 29-row results matrix.');
            end
            branch = lmzmodels.slip_quadruped.Results29Adapter. ...
                loadBranch(path,problem);
        end

        function exportBranch(~,path,branch)
            results = lmzmodels.slip_quadruped.Results29Adapter. ...
                encode(branch);
            save(path,'results');
        end
    end
end
