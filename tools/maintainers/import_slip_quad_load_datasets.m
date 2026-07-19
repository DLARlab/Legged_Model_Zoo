function report=import_slip_quad_load_datasets(sourceRoot)
%IMPORT_SLIP_QUAD_LOAD_DATASETS Copy selected source data and build natives.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1,sourceRoot=fullfile(fileparts(root),'2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights');end
expectedOrigin='https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git';
expectedCommit='19f3133073c988cc0c3424a647b4adbb60a90b99';verifyCheckout(sourceRoot,expectedOrigin,expectedCommit);
target=fullfile(root,'examples','data','slip_quad_load','Scientific');
definitions={ ...
    'Section2_Single_Stride_Replication/P3_Individual_1_TR.mat','P3_Individual_1_TR.mat', ...
        '56736cc33ab31a0ab40b3de6783b625a07ebd54f1ae6a561b47aea5e04cd6abe','single_stride'; ...
    'Section3_Gait_Transition_Replication/P4_TR_RL_Individual_1.mat','P4_TR_RL_Individual_1.mat', ...
        'd23bd725a353d7cf1b6339699ed813755867b5dd1a0da213193eb24cb3bdad4b','multi_stride_fit'};
model=lmzmodels.slip_quad_load.Model();entries=cell(size(definitions,1),1);
for index=1:size(definitions,1)
    source=fullfile(sourceRoot,strrep(definitions{index,1},'/',filesep));destination=fullfile(target,definitions{index,2});
    [ok,message]=copyfile(source,destination,'f');if ~ok,error('lmz:QuadLoad:ImportCopy','%s',message);end
    if ~strcmpi(lmz.util.FileHash.sha256(destination),definitions{index,3}),error('lmz:QuadLoad:ImportHash','Hash mismatch for %s.',definitions{index,2});end
    dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(destination);
    problem=model.createProblem(definitions{index,4},struct('DatasetPath',destination,'InitialPerturbation',0));
    solution=lmzmodels.slip_quad_load.XAccumAdapter.toSolution(problem,dataset);
    nativePath=fullfile(target,'native',[definitions{index,2}(1:end-4) '.lmz.mat']);lmz.io.ArtifactStore.save(nativePath,solution.toArtifact());
    entries{index}=struct('Name',definitions{index,2},'SHA256',definitions{index,3}, ...
        'StrideCount',dataset.StrideCount,'NativePath',nativePath);
end
report=struct('Valid',true,'Entries',vertcat(entries{:}),'SuccessMarker','LMZ_SLIP_QUAD_LOAD_IMPORT_OK');
end
function verifyCheckout(root,expectedOrigin,expectedCommit)
[status,origin]=system(sprintf('git -C "%s" remote get-url origin',root));
if status~=0||~strcmp(strtrim(origin),expectedOrigin),error('lmz:QuadLoad:ImportOrigin','Unexpected source origin.');end
[status,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0||~strcmp(strtrim(commit),expectedCommit),error('lmz:QuadLoad:ImportCommit','Unexpected source commit.');end
[status,changes]=system(sprintf('git -C "%s" status --porcelain',root));
if status~=0||~isempty(strtrim(changes)),error('lmz:QuadLoad:ImportDirty','Source checkout must be clean.');end
end
