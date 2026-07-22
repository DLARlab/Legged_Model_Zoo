classdef XAccumLegacyDataAdapterProvider < ...
        lmz.workflow.LegacyDataAdapterProvider
    %XACCUMLEGACYDATAADAPTERPROVIDER X_accum import/export boundary.
    methods
        function valid = canLoad(~,path)
            valid = false;
            if ~ischar(path) || exist(path,'file') ~= 2
                return
            end
            try
                variables = whos('-file',path);
                index = find(strcmp({variables.name},'X_accum'),1);
                if isempty(index) || prod(variables(index).size) < 44
                    return
                end
                lengthValue = prod(variables(index).size);
                valid = mod(lengthValue - 44,13) == 0;
            catch
                valid = false;
            end
        end

        function branch = importBranch(obj,path,problem)
            if ~obj.canLoad(path)
                error('lmz:QuadLoad:LegacyFormat', ...
                    ['Expected a MAT file containing an X_accum vector with ' ...
                    'length 44 + 13*(N-1).']);
            end
            source = lmzmodels.slip_quad_load.XAccumAdapter. ...
                loadDataset(path);
            solution = lmzmodels.slip_quad_load.XAccumAdapter. ...
                toSolution(problem,source);
            branch = lmz.data.SolutionBranch.fromSolutions(solution);
        end

        function exportBranch(~,path,branch)
            if ~isa(branch,'lmz.data.SolutionBranch') || ...
                    branch.pointCount() ~= 1 || ...
                    ~strcmp(branch.ModelId,'slip_quad_load')
                error('lmz:QuadLoad:LegacyCardinality', ...
                    ['A load-pulling X_accum export requires exactly one ' ...
                    'slip_quad_load point.']);
            end
            X_accum = branch.DecisionValues(:,1);
            lmzmodels.slip_quad_load.XAccumAdapter.decode(X_accum);
            save(path,'X_accum');
        end
    end
end
