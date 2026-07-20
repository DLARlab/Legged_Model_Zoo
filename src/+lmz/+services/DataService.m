classdef DataService
    %DATASERVICE Load repository-contained declarative example data.
    methods
        function ids = listBuiltInExamples(~, modelId)
            if ~ischar(modelId) || isempty(regexp(modelId, ...
                    '^[a-z][a-z0-9_]*$', 'once'))
                error('lmz:Data:ModelId', 'Built-in model ID is invalid.');
            end
            folder = fullfile(lmz.util.ProjectPaths.examples(), 'data', modelId);
            files = dir(fullfile(folder, '*.json'));
            ids = cell(numel(files), 1);
            for index = 1:numel(files)
                [~, ids{index}] = fileparts(files(index).name);
            end
            ids = sort(ids)';
        end

        function example = loadBuiltInExample(obj, modelId, exampleId)
            known = obj.listBuiltInExamples(modelId);
            if ~any(strcmp(exampleId, known))
                error('lmz:Data:UnknownBuiltInExample', ...
                    'Unknown example %s for %s.', exampleId, modelId);
            end
            if ~ischar(exampleId) || isempty(regexp(exampleId, ...
                    '^[A-Za-z][A-Za-z0-9_.-]*$', 'once'))
                error('lmz:Data:ExampleId', 'Built-in example ID is invalid.');
            end
            dataRoot = fullfile(lmz.util.ProjectPaths.examples(), 'data', modelId);
            path = lmz.util.PathGuard.resolveWithin( ...
                dataRoot, [exampleId '.json'], true);
            example = lmz.io.SafeJson.read(path, 'Root', dataRoot);
            required = {'schemaVersion','id','modelId','problemId', ...
                'options','provenance','license'};
            for index = 1:numel(required)
                if ~isfield(example, required{index})
                    error('lmz:Data:InvalidBuiltInExample', ...
                        'Example %s is missing %s.', exampleId, required{index});
                end
            end
            if ~strcmp(example.modelId, modelId)
                error('lmz:Data:ModelMismatch', ...
                    'Example model ID does not match its directory.');
            end
        end
    end
end
