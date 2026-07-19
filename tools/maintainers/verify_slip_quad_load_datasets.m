function report=verify_slip_quad_load_datasets()
%VERIFY_SLIP_QUAD_LOAD_DATASETS Verify manifest, hashes, layout, and natives.
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();records=catalog.records();
entries=cell(numel(records),1);model=lmzmodels.slip_quad_load.Model();
for index=1:numel(records)
    record=records(index);dataset=catalog.load(record.id);decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(dataset.XAccum);
    exact=isequal(lmzmodels.slip_quad_load.XAccumAdapter.encode(decoded),dataset.XAccum);
    nativePath=catalog.nativePath(record.id);nativeValid=false;
    if exist(nativePath,'file')==2
        artifact=lmz.io.ArtifactStore.load(nativePath);solution=lmz.data.Solution.fromArtifact(artifact);
        nativeValid=isequal(solution.DecisionValues,dataset.XAccum)&&strcmp(solution.ModelId,'slip_quad_load');
    end
    problemId='multi_stride_fit';if dataset.StrideCount==1,problemId='single_stride';end
    problem=model.createProblem(problemId,struct('DatasetPath',dataset.Path,'InitialPerturbation',0)); %#ok<NASGU>
    entries{index}=struct('Id',record.id,'HashValid',catalog.validateHash(record.id), ...
        'StrideCount',dataset.StrideCount,'LayoutExact',exact,'NativeValid',nativeValid);
end
entries=vertcat(entries{:});valid=all([entries.HashValid])&&all([entries.LayoutExact])&&all([entries.NativeValid]);
if ~valid,error('lmz:QuadLoad:DatasetVerification','Scientific load dataset verification failed.');end
report=struct('Valid',valid,'DatasetCount',numel(entries),'Entries',entries, ...
    'SuccessMarker','LMZ_SLIP_QUAD_LOAD_VERIFY_OK');
end
