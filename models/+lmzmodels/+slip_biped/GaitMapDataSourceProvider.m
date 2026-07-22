classdef GaitMapDataSourceProvider < lmz.workflow.BranchCatalogProvider
    %GAITMAPDATASOURCEPROVIDER Model-owned access to the jerboa GaitMap.
    methods
        function records = list(~, descriptor, registry) %#ok<INUSD>
            catalog = lmzmodels.slip_biped.GaitMapCatalog.default();
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
                    record.recommendedDefaultIndex;
                records(index).gaitSummary = record.gait;
            end
        end

        function dataset = load(obj,descriptor,datasetIdValue,registry)
            catalog = lmzmodels.slip_biped.GaitMapCatalog.default();
            record = findRecord(catalog.branchRecords(),datasetIdValue);
            path = lmz.util.PathGuard.resolveWithin( ...
                catalog.RootPath,record.relativePath,true);
            if ~obj.validateHash(path,record.sha256)
                error('lmz:GaitMap:HashMismatch', ...
                    'Biped GaitMap source hash does not match its manifest.');
            end
            model = registry.createModel(descriptor.ModelId);
            problem = model.createProblem(descriptor.ProblemId,struct());
            branch = catalog.loadBranch(path,problem,true);
            style = obj.displayStyle(descriptor,datasetIdValue);
            classification = branch.Classifications{min( ...
                record.recommendedDefaultIndex,branch.pointCount())};
            if isfield(classification,'Color')
                style.Color = classification.Color;
            end
            if isfield(classification,'LineStyle')
                style.LineStyle = classification.LineStyle;
            end
            metadata = struct('DatasetId',datasetId(record.name), ...
                'PointCount',branch.pointCount(), ...
                'RecommendedPointIndex',record.recommendedDefaultIndex, ...
                'ParameterSummary','offset_left/offset_right', ...
                'GaitSummary',record.gait,'SourceHash',record.sha256, ...
                'NativePath',catalog.nativePath(record.name), ...
                'Status','built-in/read-only');
            dataset = lmz.data.BranchDataset(record.name,branch, ...
                'SourcePath',path,'ReadOnly',true, ...
                'DisplayStyle',style,'Metadata',metadata);
        end

        function adapter = legacyAdapter(~,descriptor,registry) %#ok<INUSD>
            adapter = ...
                lmzmodels.slip_biped.Results14LegacyDataAdapterProvider();
        end
    end
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
error('lmz:GaitMap:UnknownFile','Unknown GaitMap branch: %s',id);
end

function value = datasetId(name)
[~,value] = fileparts(name);
end
