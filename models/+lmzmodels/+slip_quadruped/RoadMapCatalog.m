classdef RoadMapCatalog
    %ROADMAPCATALOG Manifest-driven access to built-in quadruped branches.
    properties (SetAccess=private)
        RootPath
        ManifestPath
        Manifest
    end
    methods
        function obj = RoadMapCatalog(rootPath)
            if nargin < 1
                rootPath = fullfile(lmz.util.ProjectPaths.examples(),'data', ...
                    'slip_quadruped','RoadMap');
            end
            obj.RootPath = rootPath;
            obj.ManifestPath = fullfile(rootPath,'roadmap_manifest.json');
            if exist(obj.ManifestPath,'file') ~= 2
                error('lmz:RoadMap:MissingManifest','RoadMap manifest is missing.');
            end
            obj.Manifest = jsondecode(fileread(obj.ManifestPath));
            obj.validateManifest();
        end
        function files = listBranches(obj)
            records = obj.branchRecords();
            files = arrayfun(@(x)fullfile(obj.RootPath,x.relativePath), ...
                records,'UniformOutput',false);
        end
        function records = branchRecords(obj)
            files = obj.allRecords();
            records = files(strcmp({files.kind}, ...
                'legacy-results-branch'));
        end
        function records = allRecords(obj)
            if iscell(obj.Manifest.files)
                records = [obj.Manifest.files{:}];
            else
                records = obj.Manifest.files;
            end
        end
        function record = record(obj,file)
            [~,name,extension] = fileparts(file); key = [name extension];
            records=obj.allRecords(); index = find(strcmp({records.name},key),1);
            if isempty(index), error('lmz:RoadMap:UnknownFile','Unknown RoadMap file: %s',key); end
            record = records(index);
        end
        function path = defaultBranchPath(obj)
            record = obj.record(obj.Manifest.defaultBranch);
            path = fullfile(obj.RootPath,record.relativePath);
        end
        function path = nativePath(obj,file)
            record = obj.record(file);
            if isempty(record.nativeArtifactPath), path=''; return, end
            path = fullfile(obj.RootPath,record.nativeArtifactPath);
        end
        function index = recommendedSeedIndex(obj,file)
            record = obj.record(file);
            if isfield(record,'recommendedSeedIndex') && record.recommendedSeedIndex > 0
                index = record.recommendedSeedIndex;
            else
                index = max(1,round(0.3*record.pointCount));
            end
        end
        function valid = validateSourceHash(obj,file)
            record = obj.record(file); path = fullfile(obj.RootPath,record.relativePath);
            valid = strcmpi(lmz.util.FileHash.sha256(path),record.sha256);
        end
        function matches = filterByFixedParameters(~,branches,name,value,tolerance)
            if nargin < 5, tolerance=1e-10; end
            if ~iscell(branches), branches=num2cell(branches); end
            matches = false(size(branches));
            for index=1:numel(branches)
                values=branches{index}.parameter(name);
                matches(index)=all(abs(values-value)<=tolerance*max(1,abs(value)));
            end
        end
        function names = identifyVaryingParameter(~,branch,tolerance)
            if nargin < 3, tolerance=1e-10; end
            names={}; candidates=branch.ParameterSchema.names();
            for index=1:numel(candidates)
                values=branch.parameter(candidates{index});
                if max(values)-min(values)>tolerance*max(1,max(abs(values)))
                    names{end+1}=candidates{index}; %#ok<AGROW>
                end
            end
        end
        function dataset = selectActiveDataset(~,datasets,datasetId)
            dataset=[];
            for index=1:numel(datasets)
                if strcmp(datasets{index}.Id,datasetId),dataset=datasets{index};return,end
            end
            error('lmz:RoadMap:DatasetMissing','Active dataset is missing.');
        end
    end
    methods (Static)
        function obj = default(), obj=lmzmodels.slip_quadruped.RoadMapCatalog(); end
    end
    methods (Access=private)
        function validateManifest(obj)
            required={'schemaVersion','datasetId','modelId','problemId', ...
                'sourceRepository','sourceCommit','sourcePath','copiedAt','license','files'};
            for index=1:numel(required)
                if ~isfield(obj.Manifest,required{index})
                    error('lmz:RoadMap:InvalidManifest','Manifest is missing %s.',required{index});
                end
            end
            if ~strcmp(obj.Manifest.datasetId,'slip_quadruped_roadmap') || ...
                    ~strcmp(obj.Manifest.modelId,'slip_quadruped') || ...
                    ~strcmp(obj.Manifest.problemId,'periodic_apex')
                error('lmz:RoadMap:InvalidManifest','Manifest identity is invalid.');
            end
            records=obj.allRecords();recordRequired={'name','relativePath','sha256','kind', ...
                'pointCount','rowCount','legacyVariable','parameterSummary', ...
                'inferredGaitSummary','nativeArtifactPath'};
            if isempty(records)||numel(unique({records.name}))~=numel(records)
                error('lmz:RoadMap:InvalidManifest','Manifest file names must be present and unique.');
            end
            branchPoints=0;
            for recordIndex=1:numel(records)
                record=records(recordIndex);
                for fieldIndex=1:numel(recordRequired)
                    if ~isfield(record,recordRequired{fieldIndex})
                        error('lmz:RoadMap:InvalidManifest','File record %d is missing %s.',recordIndex,recordRequired{fieldIndex});
                    end
                end
                if isempty(regexp(record.sha256,'^[0-9a-fA-F]{64}$','once')) || ...
                        ~any(strcmp(record.kind,{'legacy-results-branch','reference-figure'})) || ...
                        exist(fullfile(obj.RootPath,record.relativePath),'file')~=2
                    error('lmz:RoadMap:InvalidManifest','File record %s is invalid.',record.name);
                end
                if strcmp(record.kind,'legacy-results-branch')
                    if record.rowCount~=29||record.pointCount<2||~strcmp(record.legacyVariable,'results')||isempty(record.nativeArtifactPath)
                        error('lmz:RoadMap:InvalidManifest','Branch record %s has an invalid Results29 contract.',record.name);
                    end
                    branchPoints=branchPoints+record.pointCount;
                end
            end
            if branchPoints~=obj.Manifest.totalBranchPoints
                error('lmz:RoadMap:InvalidManifest','Total branch point count is inconsistent.');
            end
        end
    end
end
