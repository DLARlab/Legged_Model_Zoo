function [report,manifest]=scan_redistribution(varargin)
%SCAN_REDISTRIBUTION Validate or deterministically refresh file inventory.
%   REPORT = SCAN_REDISTRIBUTION validates the committed manifest.
%   REPORT = SCAN_REDISTRIBUTION('refresh') refreshes paths and hashes while
%   preserving existing owner-entered decision fields.
root=lmz.util.ProjectPaths.root();refresh=false;
for index=1:numel(varargin)
    value=varargin{index};
    if ischar(value)&&strcmpi(value,'refresh')
        refresh=true;
    elseif ischar(value)&&exist(value,'dir')==7
        root=value;
    else
        error('lmz:Release:InvalidScanOption','Unsupported scan option.');
    end
end
manifestPath=fullfile(root,'release','redistribution_manifest.json');
files=release_collect_files(root);
files=setdiff(files,{'release/redistribution_manifest.json'});
if refresh
    previous=[];
    if exist(manifestPath,'file')==2,previous=release_read_json(manifestPath);end
    manifest=makeManifest(root,files,previous);
    release_write_json(manifestPath,manifest);
else
    manifest=release_read_json(manifestPath);
end
report=validateManifest(root,files,manifest);
if report.StructuralViolationCount>0
    error('lmz:Release:InvalidRedistributionInventory', ...
        '%d redistribution inventory violations: %s; stale=[%s]; unlisted=[%s]', ...
        report.StructuralViolationCount,strjoin(report.Violations,' | '), ...
        strjoin(report.StaleHashes,','),strjoin(report.UnlistedFiles,','));
end
fprintf(['LMZ_REDISTRIBUTION_SCAN_OK files=%d blockers=%d ' ...
    'projectDecision=%s\n'],numel(manifest.files), ...
    numel(report.BlockingFiles),manifest.projectDecision.decisionStatus);
end

function manifest=makeManifest(root,files,previous)
manifest=struct('schemaVersion','1.0.0', ...
    'frameworkVersion',lmz.util.Version.current(), ...
    'repository','https://github.com/DLARlab/Legged_Model_Zoo.git', ...
    'repositoryCommit',release_commit(root), ...
    'selfHashPolicy','redistribution_manifest.json is excluded from its own file list', ...
    'projectDecision',struct('licenseId','NOASSERTION', ...
        'decisionStatus','unresolved','redistributable',false, ...
        'requiredNotice','Owner-supplied framework license or grant required.'), ...
    'files',struct([]));
old=struct([]);
if isstruct(previous)&&isfield(previous,'files'),old=previous.files;end
entries=repmat(emptyEntry(),numel(files),1);
for index=1:numel(files)
    relative=files{index};
    entry=classify(root,relative,manifest.repositoryCommit);
    entry.sha256=lmz.util.FileHash.sha256( ...
        fullfile(root,strrep(relative,'/',filesep)));
    if ~isempty(old)
        oldPaths={old.relativePath};match=find(strcmp(relative,oldPaths),1);
        if ~isempty(match),entry=preserveDecision(entry,old(match));end
    end
    entries(index)=entry;
end
manifest.files=entries;
if isstruct(previous)&&isfield(previous,'projectDecision')
    manifest.projectDecision=previous.projectDecision;
end
end

function entry=emptyEntry()
entry=struct('relativePath','','sha256','','category','', ...
    'sourceRepository','','sourceCommit','','licenseId','', ...
    'decisionStatus','','redistributable',false,'requiredNotice','', ...
    'generatedFrom',{{}},'profiles',{{}},'releaseRoles',{{}});
end

function entry=classify(root,relative,frameworkCommit) %#ok<INUSD>
entry=emptyEntry();entry.relativePath=relative;
entry.sourceRepository='https://github.com/DLARlab/Legged_Model_Zoo.git';
entry.sourceCommit=frameworkCommit;entry.licenseId='NOASSERTION';
entry.decisionStatus='unresolved';entry.redistributable=false;
entry.requiredNotice='Owner-supplied framework license or grant required.';
entry.category='framework';entry.profiles={'core','scientific'};
entry.releaseRoles=rolesFor(relative);
lowerPath=lower(relative);

if ~isempty(regexp(relative,'(?:^|/)Legged_Model_Zoo_.*Prompt\.md$','once'))
    entry.category='maintainer-prompt';entry.sourceRepository='local-user-input';
    entry.sourceCommit='UNVERSIONED';entry.licenseId='NOASSERTION';
    entry.decisionStatus='excluded';entry.requiredNotice='Excluded from every release profile.';
    entry.profiles={};entry.releaseRoles={};return
end
if strncmp(relative,'tools/maintainers/',18)
    entry.category='maintainer-only-tool';entry.profiles={};entry.releaseRoles={};return
end

if isTutorialAnalytic(relative)
    entry.category='tutorial-analytic';entry.profiles={'core','scientific'};
    entry.releaseRoles=rolesFor(relative);return
end

family=scientificFamily(relative,lowerPath);
if ~isempty(family)
    entry.category=['scientific-' family];entry.profiles={'scientific'};
    entry.releaseRoles=rolesFor(relative);
    switch family
        case 'biped'
            entry.sourceRepository=['https://github.com/DLARlab/' ...
                '2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git'];
            entry.sourceCommit='4595146c5881a5313bc8fe92de85099193ef9be9';
            entry.licenseId='CC-BY-NC-4.0-SCOPE-UNCONFIRMED';
            entry.requiredNotice='Biped CC BY-NC scope confirmation and attribution required.';
        case 'quadruped'
            entry.sourceRepository='https://github.com/DLARlab/SLIP_Model_Zoo.git';
            entry.sourceCommit='2c106101383ecee1b2a9d695efe09fbd72d5718a';
            entry.requiredNotice='Quadruped owner redistribution decision required.';
        case 'load'
            entry.sourceRepository=['https://github.com/DLARlab/' ...
                '2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git'];
            entry.sourceCommit='19f3133073c988cc0c3424a647b4adbb60a90b99';
            entry.licenseId='BSD-3-CLAUSE-CLAIM-UNVERIFIED';
            entry.requiredNotice='Authoritative load code/data license and scope required.';
        otherwise
            entry.sourceRepository='multiple-scientific-sources';
            entry.sourceCommit='MULTIPLE';
            entry.requiredNotice='All referenced scientific owner decisions required.';
    end
end
entry.generatedFrom=derivedSources(relative,family);
if ~isempty(entry.generatedFrom),entry.category=[entry.category '-derived'];end
end

function value=isTutorialAnalytic(relative)
value=strncmp(relative,'catalog/tutorial_hopper/',24)|| ...
    strncmp(relative,'models/+lmzmodels/+tutorial_hopper/',35)|| ...
    strncmp(relative,'examples/data/tutorial_hopper/',30)|| ...
    strcmp(relative,'examples/demo_tutorial_hopper.m');
end

function family=scientificFamily(relative,lowerPath)
family='';
if contains(lowerPath,'slip_quad_load')||contains(lowerPath,'quadload')|| ...
        contains(lowerPath,'xaccum')||contains(lowerPath,'multi_stride')|| ...
        contains(lowerPath,'loadingforce')||contains(lowerPath,'footfalltiming')|| ...
        contains(lowerPath,'strideduration')
    family='load';return
end
if contains(lowerPath,'slip_biped')||contains(lowerPath,'testbiped')|| ...
        contains(lowerPath,'results14')||contains(lowerPath,'jerboa')
    family='biped';return
end
if contains(lowerPath,'slip_quadruped')||contains(lowerPath,'roadmap')|| ...
        contains(lowerPath,'results29')||contains(lowerPath,'testquadruped')
    family='quadruped';return
end
if contains(lowerPath,'allscientificmodels')|| ...
        contains(lowerPath,'all_scientific_models')
    family='mixed';return
end
if strncmp(relative,'models/',7)||strncmp(relative,'catalog/',8)|| ...
        strncmp(relative,'examples/data/',14)
    family='mixed';
end
end

function roles=rolesFor(relative)
if strncmp(relative,'tests/',6)
    roles={'source-zip'};
elseif strncmp(relative,'tools/',6)
    roles={'source-zip'};
elseif ~isempty(regexp(relative,'\.prj$','once'))
    roles={'source-zip'};
else
    roles={'source-zip','toolbox'};
end
end

function sources=derivedSources(relative,family)
sources={};
if contains(relative,'/native/')&&~isempty(regexp(relative,'\.lmz\.mat$','once'))
    source=strrep(relative,'/native/','/');
    source=regexprep(source,'\.lmz\.mat$','.mat');sources={source};return
end
if strcmp(relative,'tests/fixtures/slip_quadruped_roadmap_baseline.mat')
    sources={'examples/data/slip_quadruped/RoadMap/roadmap_manifest.json'};return
end
if strcmp(relative,'tests/fixtures/baselines/slip_biped/source_equivalence.mat')
    sources={'examples/data/slip_biped/GaitMap/gaitmap_manifest.json', ...
        'examples/data/slip_biped/trajectory_fit/fit_manifest.json'};return
end
if strcmp(relative,'tests/fixtures/baselines/slip_quad_load/source_baselines.mat')
    sources={'examples/data/slip_quad_load/Scientific/dataset_manifest.json'};return
end
if strncmp(relative,'docs/screenshots/',17)&&~isempty(family)
    sources={'examples/data/slip_quadruped/RoadMap/roadmap_manifest.json'};
end
end

function entry=preserveDecision(entry,old)
fields={'sourceRepository','sourceCommit','licenseId','decisionStatus', ...
    'redistributable','requiredNotice','generatedFrom'};
for index=1:numel(fields)
    name=fields{index};if isfield(old,name),entry.(name)=old.(name);end
end
end

function report=validateManifest(root,currentFiles,manifest)
violations={};stale={};missing={};unlisted={};
requiredTop={'schemaVersion','frameworkVersion','repository', ...
    'repositoryCommit','projectDecision','files'};
for index=1:numel(requiredTop)
    if ~isfield(manifest,requiredTop{index}),violations{end+1}=['missing top-level ' requiredTop{index}];end %#ok<AGROW>
end
if ~isempty(violations),report=finishReport(violations,stale,missing,unlisted,{});return,end
entries=manifest.files;if isempty(entries),entries=struct([]);end
required={'relativePath','sha256','category','sourceRepository','sourceCommit', ...
    'licenseId','decisionStatus','redistributable','requiredNotice', ...
    'generatedFrom','profiles','releaseRoles'};
paths=cell(numel(entries),1);
allowedStatus={'permitted','prohibited','unresolved','excluded'};
for index=1:numel(entries)
    entry=entries(index);
    for fieldIndex=1:numel(required)
        if ~isfield(entry,required{fieldIndex})
            violations{end+1}=sprintf('entry %d missing %s',index,required{fieldIndex}); %#ok<AGROW>
        end
    end
    if ~isfield(entry,'relativePath'),continue,end
    relative=entry.relativePath;paths{index}=relative;
    if ~ischar(relative)||isempty(relative)||relative(1)=='/'|| ...
            ~isempty(regexp(relative,'(^|/)\.\.(/|$)|\\','once'))
        violations{end+1}=sprintf('unsafe path at entry %d',index);continue %#ok<AGROW>
    end
    if ~any(strcmp(entry.decisionStatus,allowedStatus))
        violations{end+1}=[relative ': invalid decisionStatus']; %#ok<AGROW>
    end
    path=fullfile(root,strrep(relative,'/',filesep));
    if exist(path,'file')~=2,missing{end+1}=relative;continue,end %#ok<AGROW>
    actual=lmz.util.FileHash.sha256(path);
    if ~strcmp(actual,entry.sha256),stale{end+1}=relative;end %#ok<AGROW>
end
if numel(unique(paths))~=numel(paths),violations{end+1}='duplicate relativePath entries';end
unlisted=setdiff(currentFiles,paths);
missing=unique([missing setdiff(paths,currentFiles)]);
for index=1:numel(entries)
    entry=entries(index);sources=release_cellstr(entry.generatedFrom);
    for sourceIndex=1:numel(sources)
        match=find(strcmp(sources{sourceIndex},paths),1);
        if isempty(match)
            violations{end+1}=sprintf('%s generatedFrom missing %s', ...
                entry.relativePath,sources{sourceIndex}); %#ok<AGROW>
        elseif entry.redistributable&& ...
                (~entries(match).redistributable|| ...
                ~strcmp(entries(match).decisionStatus,'permitted'))
            violations{end+1}=sprintf('%s exceeds source decision %s', ...
                entry.relativePath,sources{sourceIndex}); %#ok<AGROW>
        end
    end
end
if ~isempty(stale),violations{end+1}=sprintf('%d stale hashes',numel(stale));end
if ~isempty(missing),violations{end+1}=sprintf('%d missing files',numel(missing));end
if ~isempty(unlisted),violations{end+1}=sprintf('%d unlisted files',numel(unlisted));end
blocking={};
for index=1:numel(entries)
    profiles=release_cellstr(entries(index).profiles);
    if ~isempty(profiles)&&(~entries(index).redistributable|| ...
            ~strcmp(entries(index).decisionStatus,'permitted'))
        blocking{end+1}=entries(index).relativePath; %#ok<AGROW>
    end
end
report=finishReport(violations,stale,missing,unlisted,blocking);
end

function report=finishReport(violations,stale,missing,unlisted,blocking)
report=struct('Violations',{violations},'StaleHashes',{stale}, ...
    'MissingFiles',{missing},'UnlistedFiles',{unlisted}, ...
    'BlockingFiles',{blocking}, ...
    'StructuralViolationCount',numel(violations));
end
