classdef ScientificDataSourceProvider < lmz.workflow.DataSourceProvider
    %SCIENTIFICDATASOURCEPROVIDER Model-owned load-pulling dataset access.
    methods
        function records = list(~,descriptor,registry) %#ok<INUSD>
            catalog = ...
                lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            source = catalog.records();
            allowed = descriptorDatasetIds(descriptor);
            if ~isempty(allowed)
                source = source(ismember({source.id}, allowed));
            end
            template = struct('id','','label','','path','','sourcePath','', ...
                'sourceHash','','nativePath','','strideCount',0, ...
                'recommendedPointIndex',1);
            records = repmat(template,1,numel(source));
            for index = 1:numel(source)
                record = source(index);
                records(index).id = record.id;
                records(index).label = record.name;
                records(index).sourcePath = catalog.pathFor(record.id);
                records(index).path = records(index).sourcePath;
                records(index).sourceHash = record.sha256;
                records(index).nativePath = catalog.nativePath(record.id);
                records(index).strideCount = record.strideCount;
            end
        end

        function dataset = load(obj,descriptor,datasetId,registry)
            catalog = ...
                lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            record = findRecord(catalog.records(),datasetId);
            allowed = descriptorDatasetIds(descriptor);
            if ~isempty(allowed) && ~any(strcmp(record.id, allowed))
                error('lmz:QuadLoad:DatasetSource', ...
                    'Dataset %s is not registered by source %s.', ...
                    record.id, descriptor.Id);
            end
            path = catalog.pathFor(record.id);
            if ~obj.validateHash(path,record.sha256)
                error('lmz:QuadLoad:HashMismatch', ...
                    'Scientific load dataset hash does not match its manifest.');
            end
            source = catalog.load(record.id);
            model = registry.createModel(descriptor.ModelId);
            problemId = descriptor.ProblemId;
            problem = model.createProblem(problemId, ...
                struct('DatasetPath',path,'InitialPerturbation',0));
            solution = lmzmodels.slip_quad_load.XAccumAdapter. ...
                toSolution(problem,source);
            branch = lmz.data.SolutionBranch.fromSolutions(solution);
            metadata = struct('DatasetId',record.id, ...
                'PointCount',1,'RecommendedPointIndex',1, ...
                'StrideCount',record.strideCount, ...
                'ProblemId',problemId, ...
                'Kind',source.Kind,'XAccumLength',record.xAccumLength, ...
                'SourceDataset',source, ...
                'SourceHash',record.sha256, ...
                'NativePath',catalog.nativePath(record.id), ...
                'Status','built-in/read-only');
            dataset = lmz.data.BranchDataset(record.name,branch, ...
                'SourcePath',path,'ReadOnly',true, ...
                'DisplayStyle',obj.displayStyle(descriptor,datasetId), ...
                'Metadata',metadata);
        end

        function adapter = legacyAdapter(~,descriptor,registry) %#ok<INUSD>
            adapter = ...
                lmzmodels.slip_quad_load.XAccumLegacyDataAdapterProvider();
        end
    end
end

function values = descriptorDatasetIds(descriptor)
values = {};
if isstruct(descriptor.Metadata) && ...
        isfield(descriptor.Metadata, 'datasetIds')
    values = descriptor.Metadata.datasetIds;
end
if ischar(values), values = {values}; end
if isstring(values), values = cellstr(values); end
values = reshape(values, 1, []);
end

function record = findRecord(records,id)
[~,candidate,extension] = fileparts(id);
if isempty(candidate)
    candidate = id;
elseif ~isempty(extension)
    candidate = [candidate extension];
end
for index = 1:numel(records)
    [~,base] = fileparts(records(index).name);
    if strcmp(records(index).id,id) || strcmp(records(index).name,id) || ...
            strcmp(base,id) || strcmp(records(index).id,candidate) || ...
            strcmp(records(index).name,candidate) || strcmp(base,candidate)
        record = records(index);
        return
    end
end
error('lmz:QuadLoad:UnknownDataset', ...
    'Unknown scientific load dataset: %s',id);
end
