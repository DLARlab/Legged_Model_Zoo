function report=verify_slip_biped_gaitmap()
%VERIFY_SLIP_BIPED_GAITMAP Validate hashes, layouts, natives, round trips.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src'));addpath(fullfile(root,'models'));
catalog=lmzmodels.slip_biped.GaitMapCatalog.default();records=catalog.branchRecords();
pointCount=0;entries=repmat(struct('Name','','HashValid',false, ...
    'PointCount',0,'NativeValid',false),1,numel(records));
for index=1:numel(records)
    sourcePath=fullfile(catalog.RootPath,records(index).relativePath);
    hashValid=catalog.validateSourceHash(sourcePath);
    loaded=load(sourcePath,'results');lmzmodels.slip_biped.Results14Layout.validate(loaded.results);
    if size(loaded.results,2)~=records(index).pointCount
        error('lmz:GaitMap:PointCountMismatch','Point count changed for %s.',records(index).name);
    end
    nativePath=fullfile(catalog.RootPath,records(index).nativeArtifactPath);
    if exist(nativePath,'file')~=2
        error('lmz:GaitMap:MissingNative','Native artifact is missing for %s.',records(index).name);
    end
    branch=lmz.data.SolutionBranch.fromArtifact(lmz.io.ArtifactStore.load(nativePath));
    nativeValid=isequal(lmzmodels.slip_biped.Results14Adapter.encode(branch),loaded.results);
    entries(index)=struct('Name',records(index).name,'HashValid',hashValid, ...
        'PointCount',branch.pointCount(),'NativeValid',nativeValid);
    pointCount=pointCount+branch.pointCount();
end
if pointCount~=catalog.Manifest.totalBranchPoints || ...
        ~all([entries.HashValid]) || ~all([entries.NativeValid])
    error('lmz:GaitMap:VerificationFailed','Biped GaitMap verification failed.');
end
report=struct('Valid',true,'BranchCount',numel(records),'PointCount',pointCount, ...
    'Entries',entries,'SuccessMarker','LMZ_BIPED_GAITMAP_VERIFY_OK');
end
