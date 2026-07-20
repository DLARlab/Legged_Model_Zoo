function report=verify_release(archivePath)
%VERIFY_RELEASE Safely inspect and hash-check a release ZIP.
if exist(archivePath,'file')~=2,error('lmz:Release:MissingArchive','Missing archive: %s',archivePath);end
zip=java.util.zip.ZipFile(archivePath);zipCleanup=onCleanup(@()zip.close());
enumeration=zip.entries();names={};totalBytes=0;
while enumeration.hasMoreElements()
    entry=enumeration.nextElement();name=char(entry.getName());
    if unsafeEntry(name),error('lmz:Release:UnsafeArchivePath','Unsafe ZIP entry: %s',name);end
    names{end+1}=name; %#ok<AGROW>
    sizeValue=entry.getSize();if sizeValue>0,totalBytes=totalBytes+double(sizeValue);end
end
if numel(names)>10000||totalBytes>1024^3
    error('lmz:Release:ArchiveLimits','Archive exceeds verification limits.');
end
if numel(unique(names))~=numel(names),error('lmz:Release:DuplicateArchivePath','ZIP has duplicate entries.');end
clear zipCleanup
temporary=tempname;mkdir(temporary);cleanup=onCleanup(@()release_remove_tree(temporary));
unzip(archivePath,temporary);
roots=dir(temporary);roots=roots([roots.isdir]);roots=roots(~ismember({roots.name},{'.','..'}));
if numel(roots)~=1,error('lmz:Release:ArchiveRoot','Archive must have one root directory.');end
root=fullfile(temporary,roots(1).name);
manifest=release_read_json(fullfile(root,'RELEASE_MANIFEST.json'));
required={'schemaVersion','frameworkVersion','profile','repositoryCommit', ...
    'sourceTreeState','authorizationStatus','files','testEvidence'};
for index=1:numel(required)
    if ~isfield(manifest,required{index})
        error('lmz:Release:ManifestField', ...
            'Release manifest is missing %s.',required{index});
    end
end
sourceState=manifest.sourceTreeState;
if ~isstruct(sourceState)||~isscalar(sourceState)|| ...
        ~isfield(sourceState,'worktreeStatus')|| ...
        ~any(strcmp(sourceState.worktreeStatus,{'clean','dirty','unknown'}))
    error('lmz:Release:SourceTreeState', ...
        'Release manifest has invalid source-tree evidence.');
end
testEvidence=manifest.testEvidence;
if ~isstruct(testEvidence)||~isscalar(testEvidence)|| ...
        ~isfield(testEvidence,'packageVerification')|| ...
        ~isfield(testEvidence,'cleanInstall')|| ...
        ~isfield(testEvidence,'automatedTestSuite')
    error('lmz:Release:TestEvidence', ...
        'Release manifest has incomplete test evidence.');
end
if ~strcmp(manifest.frameworkVersion,strtrim(fileread(fullfile(root,'VERSION'))))
    error('lmz:Release:VersionMismatch','Archive VERSION and release manifest differ.');
end
entries=manifest.files;expected=cell(numel(entries),1);
for index=1:numel(entries)
    relative=entries(index).relativePath;expected{index}=relative;
    path=fullfile(root,strrep(relative,'/',filesep));
    if exist(path,'file')~=2,error('lmz:Release:MissingPayload','Missing payload: %s',relative);end
    if ~strcmp(lmz.util.FileHash.sha256(path),entries(index).sha256)
        error('lmz:Release:PayloadHash','Payload hash mismatch: %s',relative);
    end
end
actual=release_collect_files(root);actual=setdiff(actual,{'RELEASE_MANIFEST.json'});
if ~isequal(sort(expected(:)),sort(actual(:)))
    error('lmz:Release:PayloadInventory','Archive contains unmanifested payload files.');
end
for index=1:numel(actual)
    if contains(actual{index},'.git/')||contains(actual{index},'Prompt.md')|| ...
            strncmp(actual{index},'tools/maintainers/',18)
        error('lmz:Release:ExcludedPayload','Disallowed release payload: %s',actual{index});
    end
end
report=struct('Valid',true,'Profile',manifest.profile, ...
    'FrameworkVersion',manifest.frameworkVersion,'FileCount',numel(actual), ...
    'AuthorizationStatus',manifest.authorizationStatus, ...
    'SourceTreeState',sourceState,'TestEvidence',testEvidence, ...
    'ArchiveSha256',lmz.util.FileHash.sha256(archivePath));
fprintf('LMZ_RELEASE_VERIFY_OK profile=%s files=%d authorization=%s\n', ...
    report.Profile,report.FileCount,report.AuthorizationStatus);
clear cleanup
end

function value=unsafeEntry(name)
value=isempty(name)||name(1)=='/'||name(1)=='\'|| ...
    ~isempty(regexp(name,'(^|/)\.\.(/|$)|\\|^[A-Za-z]:','once'));
end
