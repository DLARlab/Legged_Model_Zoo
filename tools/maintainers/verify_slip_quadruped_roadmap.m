function report = verify_slip_quadruped_roadmap()
%VERIFY_SLIP_QUADRUPED_ROADMAP Validate hashes, shapes, native artifacts.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src')); addpath(fullfile(root,'models'));
catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
registry=lmz.registry.ModelRegistry.discover();
problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());
allRecords=catalog.allRecords();
for recordIndex=1:numel(allRecords)
    path=fullfile(catalog.RootPath,allRecords(recordIndex).relativePath);
    if ~strcmpi(lmz.util.FileHash.sha256(path),allRecords(recordIndex).sha256)
        error('lmz:RoadMap:HashMismatch','RoadMap hash changed for %s.',allRecords(recordIndex).name);
    end
end
records=catalog.branchRecords(); pointCount=0; entries=repmat(struct( ...
    'Name','','HashValid',false,'PointCount',0,'NativeValid',false),1,numel(records));
for index=1:numel(records)
    sourcePath=fullfile(catalog.RootPath,records(index).relativePath);
    hashValid=catalog.validateSourceHash(sourcePath);
    loaded=load(sourcePath,'results');
    lmzmodels.slip_quadruped.Results29Layout.validate(loaded.results);
    if size(loaded.results,2)~=records(index).pointCount
        error('lmz:RoadMap:PointCountMismatch','Point count changed for %s.',records(index).name);
    end
    nativePath=fullfile(catalog.RootPath,records(index).nativeArtifactPath);
    artifact=lmz.io.ArtifactStore.load(nativePath);
    branch=lmz.data.SolutionBranch.fromArtifact(artifact);
    nativeValid=isequal(lmzmodels.slip_quadruped.Results29Adapter.encode(branch),loaded.results);
    entries(index)=struct('Name',records(index).name,'HashValid',hashValid, ...
        'PointCount',branch.pointCount(),'NativeValid',nativeValid);
    pointCount=pointCount+branch.pointCount();
end
if pointCount~=catalog.Manifest.totalBranchPoints || ...
        ~all([entries.HashValid]) || ~all([entries.NativeValid])
    error('lmz:RoadMap:VerificationFailed','RoadMap verification failed.');
end
report=struct('Valid',true,'BranchCount',numel(records),'PointCount',pointCount, ...
    'VerifiedFileCount',numel(allRecords),'Entries',entries,'SuccessMarker','LMZ_ROADMAP_VERIFY_OK');
end
