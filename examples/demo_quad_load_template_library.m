%DEMO_QUAD_LOAD_TEMPLATE_LIBRARY Inspect hash-bound transition templates.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
if ~exist('round10OutputDirectory','var')||isempty(round10OutputDirectory)
    round10OutputDirectory=tempname(tempdir);
end
if exist(round10OutputDirectory,'dir')~=7
    [created,message]=mkdir(round10OutputDirectory);
    if ~created,error('lmz:Example:OutputDirectory','%s',message);end
end

context=lmz.api.RunContext.synchronous(1001);
library=lmzmodels.slip_quad_load.StrideTemplateLibrary();
records=library.records();templates=library.all(context);
hashesValid=arrayfun(@(item)library.validateHash(item.id),records);
segmentCount=sum(cellfun(@(item)item.StrideCount,templates));
if numel(records)~=4||segmentCount~=7||~all(hashesValid)
    error('lmz:Example:QuadLoadTemplateLibrary', ...
        'The complete hash-bound template inventory did not validate.');
end
output=struct('Records',records,'TemplateCount',numel(records), ...
    'SegmentTemplateCount',segmentCount,'HashesValid',hashesValid, ...
    'SourceCommit',library.Manifest.sourceCommit, ...
    'OutputDirectory',round10OutputDirectory, ...
    'SuccessMarker','LMZ_QUAD_LOAD_TEMPLATE_LIBRARY_OK');
fprintf('%s templates=%d segments=%d hashes=%d\n', ...
    output.SuccessMarker,output.TemplateCount, ...
    output.SegmentTemplateCount,all(output.HashesValid));
clear directoryCleanup
