function report=import_slip_biped_gaitmap(sourceDirectory)
%IMPORT_SLIP_BIPED_GAITMAP Recopy verified Results14 and rebuild natives.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src'));addpath(fullfile(root,'models'));
if nargin<1
    sourceDirectory=fullfile(fileparts(root), ...
        '2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
        'Section2_solution_examples');
end
if exist(sourceDirectory,'dir')~=7
    error('lmz:GaitMap:MissingSource','Immutable source GaitMap folder is missing.');
end
sourceRoot=fileparts(sourceDirectory);
[status,head]=system(sprintf('git -C "%s" rev-parse HEAD',sourceRoot));
if status~=0||~strcmp(strtrim(head),'4595146c5881a5313bc8fe92de85099193ef9be9')
    error('lmz:GaitMap:SourceCommit','Biped source checkout is not at the recorded commit.');
end
[status,origin]=system(sprintf('git -C "%s" remote get-url origin',sourceRoot));
if status~=0||~strcmp(strtrim(origin), ...
        'https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git')
    error('lmz:GaitMap:SourceOrigin','Biped source checkout has an unexpected origin.');
end
catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
model=lmzmodels.slip_biped.Model();
problem=model.createProblem('periodic_apex',struct());
records=catalog.branchRecords();copied={};generated={};
for index=1:numel(records)
    sourcePath=fullfile(sourceDirectory,records(index).name);
    if exist(sourcePath,'file')~=2
        error('lmz:GaitMap:MissingSourceFile','Missing source file %s.',records(index).name);
    end
    if ~strcmpi(lmz.util.FileHash.sha256(sourcePath),records(index).sha256)
        error('lmz:GaitMap:SourceChanged','Source digest changed for %s.',records(index).name);
    end
    targetPath=fullfile(catalog.RootPath,records(index).relativePath);
    [ok,message]=copyfile(sourcePath,targetPath,'f');
    if ~ok,error('lmz:GaitMap:CopyFailed','%s',message);end
    copied{end+1}=targetPath; %#ok<AGROW>
    artifact=lmzmodels.slip_biped.Results14Adapter.toNativeArtifact( ...
        targetPath,problem,records(index).gait);
    nativePath=fullfile(catalog.RootPath,records(index).nativeArtifactPath);
    lmz.io.ArtifactStore.save(nativePath,artifact);
    generated{end+1}=nativePath; %#ok<AGROW>
end
report=struct('SourceDirectory',sourceDirectory,'CopiedFiles',{copied}, ...
    'NativeArtifacts',{generated},'SourceCommit',catalog.Manifest.sourceCommit, ...
    'CompletedAt',datestr(now,30),'SuccessMarker','LMZ_BIPED_GAITMAP_IMPORT_OK');
end
