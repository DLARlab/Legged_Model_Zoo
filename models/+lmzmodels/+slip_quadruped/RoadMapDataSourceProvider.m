classdef RoadMapDataSourceProvider < lmz.workflow.BranchCatalogProvider
    %ROADMAPDATASOURCEPROVIDER Model-owned access to the scientific RoadMap.
    methods
        function records = list(~, descriptor, registry) %#ok<INUSD>
            catalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
            source = catalog.branchRecords();
            template = struct('id','','label','','path','','sourcePath','', ...
                'sourceHash','','nativePath','','pointCount',0, ...
                'recommendedPointIndex',1,'gaitSummary','');
            records = repmat(template,1,numel(source));
            for index = 1:numel(source)
                record = source(index);
                records(index).id = datasetId(record.name);
                records(index).label = record.name;
                records(index).sourcePath = lmz.util.PathGuard. ...
                    resolveWithin(catalog.RootPath,record.relativePath,true);
                records(index).path = records(index).sourcePath;
                records(index).sourceHash = record.sha256;
                records(index).nativePath = catalog.nativePath(record.name);
                records(index).pointCount = record.pointCount;
                records(index).recommendedPointIndex = ...
                    record.recommendedSeedIndex;
                records(index).gaitSummary = record.inferredGaitSummary;
            end
        end

        function dataset = load(obj, descriptor, datasetIdValue, registry)
            catalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
            record = findRecord(catalog.branchRecords(),datasetIdValue);
            path = lmz.util.PathGuard.resolveWithin( ...
                catalog.RootPath,record.relativePath,true);
            if ~obj.validateHash(path,record.sha256)
                error('lmz:RoadMap:HashMismatch', ...
                    'RoadMap source hash does not match the manifest.');
            end
            model = registry.createModel(descriptor.ModelId);
            problem = model.createProblem(descriptor.ProblemId,struct());
            branch = loadBranch(catalog,record,path,problem);
            style = obj.displayStyle(descriptor,datasetIdValue);
            classification = branch.Classifications{ ...
                min(2,branch.pointCount())};
            if isfield(classification,'Color')
                style.Color = classification.Color;
            end
            if isfield(classification,'LineStyle')
                style.LineStyle = classification.LineStyle;
            end
            metadata = struct('DatasetId',datasetId(record.name), ...
                'PointCount',branch.pointCount(), ...
                'RecommendedPointIndex',record.recommendedSeedIndex, ...
                'ParameterSummary',record.parameterSummary, ...
                'GaitSummary',record.inferredGaitSummary, ...
                'SourceHash',record.sha256, ...
                'NativePath',catalog.nativePath(record.name), ...
                'Status','built-in/read-only');
            dataset = lmz.data.BranchDataset(record.name,branch, ...
                'SourcePath',path,'ReadOnly',true, ...
                'DisplayStyle',style,'Metadata',metadata);
        end

        function adapter = legacyAdapter(~, descriptor, registry) %#ok<INUSD>
            adapter = ...
                lmzmodels.slip_quadruped.Results29LegacyDataAdapterProvider();
        end
    end
end

function branch = loadBranch(catalog,record,path,problem)
nativePath = catalog.nativePath(record.name);
if exist(nativePath,'file') == 2
    artifact = lmz.io.ArtifactStore.load(nativePath);
    if isfield(artifact,'diagnostics') && ...
            isfield(artifact.diagnostics,'LegacySourceSHA256') && ...
            strcmpi(artifact.diagnostics.LegacySourceSHA256,record.sha256)
        branch = lmz.data.SolutionBranch.fromArtifact(artifact);
        return
    end
end
branch = lmzmodels.slip_quadruped.Results29Adapter.loadBranch(path,problem);
end

function record = findRecord(records,id)
[~,candidate,extension] = fileparts(id);
if isempty(candidate)
    candidate = id;
elseif ~isempty(extension)
    candidate = [candidate extension];
end
for index = 1:numel(records)
    if strcmp(datasetId(records(index).name),id) || ...
            strcmp(records(index).name,id) || ...
            strcmp(datasetId(records(index).name),datasetId(candidate)) || ...
            strcmp(records(index).name,candidate)
        record = records(index);
        return
    end
end
error('lmz:RoadMap:UnknownFile','Unknown RoadMap branch: %s',id);
end

function value = datasetId(name)
[~,value] = fileparts(name);
end
