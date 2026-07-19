classdef ScientificDatasetCatalog
    %SCIENTIFICDATASETCATALOG Manifest-driven repository-contained datasets.
    properties (SetAccess=private)
        RootPath
        ManifestPath
        Manifest
    end
    methods
        function obj=ScientificDatasetCatalog(rootPath)
            if nargin<1,rootPath=fullfile(lmz.util.ProjectPaths.examples(),'data','slip_quad_load','Scientific');end
            obj.RootPath=rootPath;obj.ManifestPath=fullfile(rootPath,'dataset_manifest.json');
            if exist(obj.ManifestPath,'file')~=2,error('lmz:QuadLoad:ManifestMissing','Scientific load manifest is missing.');end
            obj.Manifest=jsondecode(fileread(obj.ManifestPath));obj.validateManifest();
        end
        function records=records(obj)
            if iscell(obj.Manifest.files),records=[obj.Manifest.files{:}];else,records=obj.Manifest.files;end
        end
        function record=record(obj,idOrFile)
            records=obj.records();keys={records.id};names={records.name};baseNames=cell(size(names));
            for nameIndex=1:numel(names),[~,baseNames{nameIndex}]=fileparts(names{nameIndex});end
            index=find(strcmp(keys,idOrFile)|strcmp(names,idOrFile)|strcmp(baseNames,idOrFile),1);
            if isempty(index),error('lmz:QuadLoad:UnknownDataset','Unknown scientific load dataset: %s',idOrFile);end
            record=records(index);
        end
        function path=pathFor(obj,idOrFile)
            record=obj.record(idOrFile);path=fullfile(obj.RootPath,record.relativePath);
        end
        function path=defaultSinglePath(obj),path=obj.pathFor(obj.Manifest.defaultSingleStride);end
        function path=defaultMultiPath(obj),path=obj.pathFor(obj.Manifest.defaultMultiStride);end
        function dataset=load(obj,idOrFile),dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(obj.pathFor(idOrFile));end
        function valid=validateHash(obj,idOrFile)
            record=obj.record(idOrFile);valid=strcmpi(lmz.util.FileHash.sha256(obj.pathFor(idOrFile)),record.sha256);
        end
        function path=nativePath(obj,idOrFile)
            record=obj.record(idOrFile);path=fullfile(obj.RootPath,record.nativeArtifactPath);
        end
    end
    methods (Static)
        function obj=default(),obj=lmzmodels.slip_quad_load.ScientificDatasetCatalog();end
    end
    methods (Access=private)
        function validateManifest(obj)
            required={'schemaVersion','datasetId','modelId','sourceRepository','sourceCommit', ...
                'license','defaultSingleStride','defaultMultiStride','files'};
            for index=1:numel(required),if ~isfield(obj.Manifest,required{index}),error('lmz:QuadLoad:ManifestField','Manifest is missing %s.',required{index});end,end
            if ~strcmp(obj.Manifest.modelId,'slip_quad_load'),error('lmz:QuadLoad:ManifestIdentity','Manifest model identity is invalid.');end
            records=obj.records();
            for index=1:numel(records)
                record=records(index);fields={'id','name','relativePath','sourcePath','sha256','strideCount','xAccumLength','nativeArtifactPath'};
                for fieldIndex=1:numel(fields),if ~isfield(record,fields{fieldIndex}),error('lmz:QuadLoad:ManifestRecord','Dataset record is missing %s.',fields{fieldIndex});end,end
                if record.xAccumLength~=44+13*(record.strideCount-1)||exist(fullfile(obj.RootPath,record.relativePath),'file')~=2|| ...
                        isempty(regexp(record.sha256,'^[0-9a-fA-F]{64}$','once'))
                    error('lmz:QuadLoad:ManifestRecord','Dataset record %s is invalid.',record.name);
                end
            end
        end
    end
end
