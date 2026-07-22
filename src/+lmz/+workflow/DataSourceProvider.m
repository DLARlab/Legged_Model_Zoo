classdef (Abstract) DataSourceProvider < handle
    %DATASOURCEPROVIDER Trusted model-owned data loading boundary.
    methods (Abstract)
        records = list(obj, descriptor, registry)
        dataset = load(obj, descriptor, datasetId, registry)
    end
    methods
        function datasets = loadAll(obj, descriptor, registry)
            records = obj.list(descriptor, registry);
            records = normalizeRecords(records);
            datasets = cell(1, numel(records));
            for index = 1:numel(records)
                datasets{index} = obj.load(descriptor, ...
                    recordId(records{index}), registry);
            end
        end

        function index = recommendedPoint(~, descriptor, dataset)
            index = 1;
            if isstruct(descriptor.Metadata) && ...
                    isfield(descriptor.Metadata, 'recommendedPointIndex')
                index = descriptor.Metadata.recommendedPointIndex;
            end
            if isa(dataset, 'lmz.data.BranchDataset') && ...
                    isstruct(dataset.Metadata) && ...
                    isfield(dataset.Metadata, 'RecommendedPointIndex')
                index = dataset.Metadata.RecommendedPointIndex;
            end
            if isa(dataset, 'lmz.data.BranchDataset')
                index = max(1, min(dataset.Branch.pointCount(), round(index)));
            end
        end

        function value = defaultAxes(~, descriptor)
            value = fieldOr(descriptor.Metadata, 'axisPresetId', '');
        end

        function value = displayStyle(~, descriptor, datasetId) %#ok<INUSD>
            value = struct('Color',[0 0.4470 0.7410], ...
                'LineStyle','-','Marker','none');
        end

        function adapter = legacyAdapter(~, descriptor, registry) %#ok<INUSD>
            adapter = [];
        end

        function valid = validateHash(~, path, expectedHash)
            valid = ischar(expectedHash) && numel(expectedHash) == 64 && ...
                strcmpi(lmz.util.FileHash.sha256(path), expectedHash);
        end
    end
end

function values = normalizeRecords(records)
if isempty(records), values = {}; return, end
if iscell(records), values = reshape(records, 1, []); return, end
if isstruct(records), values = num2cell(reshape(records, 1, [])); return, end
if ischar(records), values = {records}; return, end
error('lmz:Workflow:ProviderRecords', ...
    'Provider records must be text, structs, or a cell array.');
end

function value = recordId(record)
if ischar(record), value = record; return, end
if isstruct(record) && isfield(record, 'id'), value = record.id; return, end
if isstruct(record) && isfield(record, 'Id'), value = record.Id; return, end
if isstruct(record) && isfield(record, 'name'), value = record.name; return, end
error('lmz:Workflow:ProviderRecordId', ...
    'A provider record does not expose an ID.');
end

function value = fieldOr(source, name, fallback)
if isstruct(source) && isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
