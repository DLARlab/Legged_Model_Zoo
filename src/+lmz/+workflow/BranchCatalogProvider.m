classdef (Abstract) BranchCatalogProvider < lmz.workflow.DataSourceProvider
    %BRANCHCATALOGPROVIDER Common model-independent branch operations.
    methods
        function matches = filterByFixedParameters(~, branches, name, ...
                value, tolerance)
            if nargin < 5, tolerance = 1e-10; end
            if ~iscell(branches), branches = num2cell(branches); end
            matches = false(size(branches));
            for index = 1:numel(branches)
                values = branches{index}.parameter(name);
                matches(index) = all(abs(values - value) <= ...
                    tolerance * max(1, abs(value)));
            end
        end

        function names = identifyVaryingParameter(~, branch, tolerance)
            if nargin < 3, tolerance = 1e-10; end
            names = {};
            candidates = branch.ParameterSchema.names();
            for index = 1:numel(candidates)
                values = branch.parameter(candidates{index});
                if max(values) - min(values) > ...
                        tolerance * max(1, max(abs(values)))
                    names{end + 1} = candidates{index}; %#ok<AGROW>
                end
            end
        end

        function dataset = selectActiveDataset(~, datasets, datasetId)
            for index = 1:numel(datasets)
                candidate = datasets{index};
                if strcmp(candidate.Id, datasetId) || ...
                        strcmp(candidate.Name, datasetId)
                    dataset = candidate;
                    return
                end
            end
            error('lmz:Workflow:DatasetMissing', ...
                'Active branch dataset is missing.');
        end
    end
end
