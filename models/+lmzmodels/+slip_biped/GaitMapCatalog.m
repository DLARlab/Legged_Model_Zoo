classdef GaitMapCatalog
    %GAITMAPCATALOG Manifest-driven built-in biped branch access.
    properties (SetAccess=private)
        RootPath
        ManifestPath
        Manifest
    end
    methods
        function obj=GaitMapCatalog(rootPath)
            if nargin<1
                rootPath=fullfile(lmz.util.ProjectPaths.examples(),'data', ...
                    'slip_biped','GaitMap');
            end
            obj.RootPath=lmz.util.PathGuard.canonical(rootPath,true);
            obj.ManifestPath=lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,'gaitmap_manifest.json',true);
            if exist(obj.ManifestPath,'file')~=2
                error('lmz:GaitMap:MissingManifest','Biped GaitMap manifest is missing.');
            end
            obj.Manifest=lmz.io.SafeJson.read(obj.ManifestPath, ...
                'Root',obj.RootPath);obj.validateManifest();
        end
        function records=branchRecords(obj)
            if iscell(obj.Manifest.files),records=[obj.Manifest.files{:}]; ...
            else,records=obj.Manifest.files;end
        end
        function paths=listBranches(obj)
            records=obj.branchRecords();
            paths=arrayfun(@(x)lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,x.relativePath,true),records, ...
                'UniformOutput',false);
        end
        function record=record(obj,file)
            [~,name,extension]=fileparts(file);key=[name extension];
            records=obj.branchRecords();index=find(strcmp({records.name},key),1);
            if isempty(index),error('lmz:GaitMap:UnknownFile','Unknown GaitMap file: %s',key);end
            record=records(index);
        end
        function path=defaultBranchPath(obj)
            record=obj.record(obj.Manifest.defaultBranch);path= ...
                lmz.util.PathGuard.resolveWithin(obj.RootPath,record.relativePath,true);
        end
        function index=recommendedSeedIndex(obj,file)
            record=obj.record(file);index=record.recommendedDefaultIndex;
        end
        function path=nativePath(obj,file)
            record=obj.record(file);path=lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,record.nativeArtifactPath,false);
        end
        function valid=validateSourceHash(obj,file)
            record=obj.record(file);path=lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,record.relativePath,true);
            valid=strcmpi(lmz.util.FileHash.sha256(path),record.sha256);
        end
        function branch=loadBranch(obj,file,problem,preferNative)
            if nargin<2||isempty(file),file=obj.defaultBranchPath();end
            if nargin<3,problem=[];end
            if nargin<4,preferNative=true;end
            record=obj.record(file);
            sourcePath=lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,record.relativePath,true);
            if ~strcmpi(lmz.util.FileHash.sha256(sourcePath),record.sha256)
                error('lmz:GaitMap:HashMismatch','Biped GaitMap source hash does not match its manifest.');
            end
            native=obj.nativePath(file);
            if preferNative && exist(native,'file')==2
                artifact=lmz.io.ArtifactStore.load(native);
                if ~isfield(artifact,'diagnostics') || ...
                        ~isfield(artifact.diagnostics,'LegacySourceSHA256') || ...
                        ~strcmpi(artifact.diagnostics.LegacySourceSHA256,record.sha256)
                    error('lmz:GaitMap:NativeProvenance', ...
                        'Native branch provenance does not match %s.',record.name);
                end
                branch=lmz.data.SolutionBranch.fromArtifact(artifact);
            else
                branch=lmzmodels.slip_biped.Results14Adapter.loadBranch( ...
                    sourcePath,problem,record.gait);
            end
        end
        function branches=loadAll(obj,problem,preferNative)
            if nargin<2,problem=[];end
            if nargin<3,preferNative=true;end
            records=obj.branchRecords();branches=cell(1,numel(records));
            for index=1:numel(records)
                branches{index}=obj.loadBranch(records(index).name,problem,preferNative);
            end
        end
    end
    methods (Static)
        function obj=default(),obj=lmzmodels.slip_biped.GaitMapCatalog();end
    end
    methods (Access=private)
        function validateManifest(obj)
            required={'schemaVersion','datasetId','modelId','problemId', ...
                'sourceRepository','sourceCommit','sourcePath','files'};
            for index=1:numel(required)
                if ~isfield(obj.Manifest,required{index})
                    error('lmz:GaitMap:InvalidManifest','Manifest is missing %s.',required{index});
                end
            end
            if ~strcmp(obj.Manifest.datasetId,'slip_biped_gaitmap') || ...
                    ~strcmp(obj.Manifest.modelId,'slip_biped') || ...
                    ~strcmp(obj.Manifest.problemId,'periodic_apex')
                error('lmz:GaitMap:InvalidManifest','Manifest identity is invalid.');
            end
            records=obj.branchRecords();requiredRecord={'name','relativePath','sha256', ...
                'rowCount','pointCount','gait','sourceVariable', ...
                'recommendedDefaultIndex','nativeArtifactPath'};
            total=0;
            for recordIndex=1:numel(records)
                record=records(recordIndex);
                for fieldIndex=1:numel(requiredRecord)
                    if ~isfield(record,requiredRecord{fieldIndex})
                        error('lmz:GaitMap:InvalidManifest','Record %d is missing %s.', ...
                            recordIndex,requiredRecord{fieldIndex});
                    end
                end
                path=lmz.util.PathGuard.resolveWithin( ...
                    obj.RootPath,record.relativePath,true);
                lmz.util.PathGuard.validateRelative(record.nativeArtifactPath);
                if record.rowCount~=14 || record.pointCount<1 || ...
                        ~strcmp(record.sourceVariable,'results') || ...
                        isempty(regexp(record.sha256,'^[0-9a-fA-F]{64}$','once')) || ...
                        record.recommendedDefaultIndex<1 || ...
                        record.recommendedDefaultIndex>record.pointCount || ...
                        exist(path,'file')~=2
                    error('lmz:GaitMap:InvalidManifest','Branch record %s is invalid.',record.name);
                end
                total=total+record.pointCount;
            end
            if total~=obj.Manifest.totalBranchPoints
                error('lmz:GaitMap:InvalidManifest','Total branch point count is inconsistent.');
            end
        end
    end
end
