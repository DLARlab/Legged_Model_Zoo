function report = import_slip_quadruped_roadmap(sourceRoadMap)
%IMPORT_SLIP_QUADRUPED_ROADMAP Recopy verified sources and rebuild natives.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src')); addpath(fullfile(root,'models'));
catalog = lmzmodels.slip_quadruped.RoadMapCatalog.default();
if nargin < 1
    sourceRoadMap = fullfile(fileparts(root),'SLIP_Model_Zoo','SLIP_Quadruped', ...
        'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits','1_Roadmap');
end
if exist(sourceRoadMap,'dir') ~= 7
    error('lmz:RoadMap:MissingSource','Source RoadMap folder is missing.');
end
registry = lmz.registry.ModelRegistry.discover();
problem = registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());
records = catalog.allRecords(); copied={}; generated={};
for index=1:numel(records)
    sourcePath=fullfile(sourceRoadMap,records(index).name);
    if exist(sourcePath,'file')~=2
        error('lmz:RoadMap:MissingSourceFile','Missing source file %s.',records(index).name);
    end
    if ~strcmpi(lmz.util.FileHash.sha256(sourcePath),records(index).sha256)
        error('lmz:RoadMap:SourceChanged','Source digest changed for %s.',records(index).name);
    end
    targetPath=fullfile(catalog.RootPath,records(index).relativePath);
    [ok,message]=copyfile(sourcePath,targetPath,'f');
    if ~ok,error('lmz:RoadMap:CopyFailed','%s',message);end
    copied{end+1}=targetPath; %#ok<AGROW>
    if strcmp(records(index).kind,'legacy-results-branch')
        artifact=lmzmodels.slip_quadruped.Results29Adapter.toNativeArtifact(targetPath,problem);
        nativePath=fullfile(catalog.RootPath,records(index).nativeArtifactPath);
        lmz.io.ArtifactStore.save(nativePath,artifact);
        generated{end+1}=nativePath; %#ok<AGROW>
    end
end
report=struct('SourceRoadMap',sourceRoadMap,'CopiedFiles',{copied}, ...
    'NativeArtifacts',{generated},'SourceCommit',catalog.Manifest.sourceCommit, ...
    'CompletedAt',datestr(now,30));
end
