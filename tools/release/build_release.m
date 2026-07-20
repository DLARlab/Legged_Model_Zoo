function result=build_release(profile,options)
%BUILD_RELEASE Build an authorization-gated deterministic ZIP package.
if nargin<2,options=struct();end
options=normalizeOptions(options);
[files,selection]=release_file_list(profile,'source-zip');
root=lmz.util.ProjectPaths.root();sourceState=release_source_state(root);
result=struct('Profile',selection.Profile,'Mode',options.Mode, ...
    'Authorized',selection.Authorized,'BlockingFiles',{selection.BlockingFiles}, ...
    'ArchivePath','','Sha256','','Verification',struct(), ...
    'InstallTest',struct(),'TestEvidence',struct(), ...
    'SourceTreeState',sourceState,'FileCount',numel(files),'Retained',false);
if strcmp(options.Mode,'dry-run')
    fprintf('LMZ_RELEASE_DRY_RUN profile=%s files=%d blockers=%d\n', ...
        selection.Profile,numel(files),numel(selection.BlockingFiles));
    return
end
if strcmp(options.Mode,'public')&&~selection.Authorized
    error('lmz:Release:AuthorizationBlocked', ...
        ['Public %s build blocked by the project decision and %d selected ' ...
        'file decisions. No archive was written.'],selection.Profile, ...
        numel(selection.BlockingFiles));
end

temporary=tempname;
[ok,message]=mkdir(temporary);if ~ok,error('lmz:Release:StageFailed','%s',message);end
cleanup=onCleanup(@()release_remove_tree(temporary));
archiveRoot=sprintf('Legged_Model_Zoo-%s-%s', ...
    lmz.util.Version.current(),selection.Profile);
stage=fullfile(temporary,archiveRoot);mkdir(stage);
for index=1:numel(files)
    release_copy_file(fullfile(root,strrep(files{index},'/',filesep)), ...
        fullfile(stage,strrep(files{index},'/',filesep)));
end
release_copy_file(fullfile(root,'release','redistribution_manifest.json'), ...
    fullfile(stage,'release','redistribution_manifest.json'));

payload=release_collect_files(stage);
entries=repmat(struct('relativePath','','sha256',''),numel(payload),1);
for index=1:numel(payload)
    entries(index).relativePath=payload{index};
    entries(index).sha256=lmz.util.FileHash.sha256( ...
        fullfile(stage,strrep(payload{index},'/',filesep)));
end
if selection.Authorized,authority='permitted';else,authority='NOT_FOR_REDISTRIBUTION';end
releaseManifest=struct('schemaVersion','1.0.0', ...
    'frameworkVersion',lmz.util.Version.current(), ...
    'artifactSchemaVersion',lmz.util.Version.artifactSchemaVersion(), ...
    'catalogSchemaVersion',lmz.util.Version.catalogSchemaVersion(), ...
    'minimumMatlabRelease',lmz.util.Version.minimumMatlabRelease(), ...
    'profile',selection.Profile, ...
    'repositoryCommit',sourceState.repositoryCommit, ...
    'sourceTreeState',sourceState, ...
    'authorizationStatus',authority,'files',entries, ...
    'testEvidence',testEvidence('verification-only',struct()), ...
    'licenseDecision',selection.ProjectDecision);
manifestPath=fullfile(stage,'RELEASE_MANIFEST.json');
if options.RunInstallTest
    releaseManifest.testEvidence=testEvidence('pending',struct());
    release_write_json(manifestPath,releaseManifest);
    payload=release_collect_files(stage);
    preflightArchive=fullfile(temporary,[archiveRoot '-preflight.zip']);
    write_deterministic_zip(stage,payload,preflightArchive,archiveRoot);
    preflightVerification=verify_release(preflightArchive);
    preflightInstall=run_clean_install_test(preflightArchive);
    releaseManifest.testEvidence=testEvidence('passed',preflightInstall);
    releaseManifest.testEvidence.preflightArchiveVerification= ...
        preflightVerification.Valid;
end
release_write_json(manifestPath,releaseManifest);
payload=release_collect_files(stage);
temporaryArchive=fullfile(temporary,[archiveRoot '.zip']);
write_deterministic_zip(stage,payload,temporaryArchive,archiveRoot);
verification=verify_release(temporaryArchive);
checksum=lmz.util.FileHash.sha256(temporaryArchive);
result.Sha256=checksum;result.Verification=verification;
if options.RunInstallTest,result.InstallTest=run_clean_install_test(temporaryArchive);end
result.TestEvidence=releaseManifest.testEvidence;

if strcmp(options.Mode,'public')
    output=options.OutputDirectory;
    if exist(output,'dir')~=7,mkdir(output);end
    finalPath=fullfile(output,[archiveRoot '.zip']);
    temporaryFinal=[finalPath '.tmp'];
    release_copy_file(temporaryArchive,temporaryFinal);
    [moved,message]=movefile(temporaryFinal,finalPath,'f');
    if ~moved,error('lmz:Release:AtomicMoveFailed','%s',message);end
    writeChecksum([finalPath '.sha256'],checksum,[archiveRoot '.zip']);
    result.ArchivePath=finalPath;result.Retained=true;
else
    result.ArchivePath='';result.Retained=false;
end
fprintf('LMZ_RELEASE_BUILD_OK profile=%s mode=%s files=%d sha256=%s retained=%d\n', ...
    selection.Profile,options.Mode,numel(payload),checksum,result.Retained);
clear cleanup
end

function value=testEvidence(status,install)
value=struct('packageVerification','passed-before-builder-return', ...
    'cleanInstall','not-requested','registryDiscovery',false, ...
    'permittedWorkflow',false,'guiConstruction',false, ...
    'artifactRoundTrip',false,'pathRemoval',false, ...
    'automatedTestSuite','not-run-by-package-builder', ...
    'evidenceScope',['Verification applies to this deterministic archive. ' ...
        'The repository test suite is reported separately.']);
if strcmp(status,'pending')
    value.packageVerification='pending';value.cleanInstall='pending';
    value.evidenceScope=['Temporary preflight package; it is never retained ' ...
        'or returned by the builder.'];return
end
if strcmp(status,'passed')
    value.cleanInstall='passed';
    value.registryDiscovery=install.RegistryDiscovery;
    value.permittedWorkflow=install.Workflow;
    value.guiConstruction=install.GuiConstruction;
    value.artifactRoundTrip=install.ArtifactRoundTrip;
    value.pathRemoval=install.Unloaded;
    value.evidenceScope=['Recorded from a preflight archive with identical ' ...
        'functional payload. The final archive is rebuilt only to embed this ' ...
        'evidence, then independently reverified and clean-install tested ' ...
        'before it can be returned or retained.'];
end
end

function options=normalizeOptions(options)
defaults=struct('Mode','public','DryRun',false,'RunInstallTest',false, ...
    'OutputDirectory',fullfile(lmz.util.ProjectPaths.root(),'release','out'));
names=fieldnames(options);for index=1:numel(names),defaults.(names{index})=options.(names{index});end
options=defaults;if options.DryRun,options.Mode='dry-run';end
allowed={'public','dry-run','technical-validation'};
if ~any(strcmp(options.Mode,allowed)),error('lmz:Release:InvalidMode','Invalid build mode: %s',options.Mode);end
end

function writeChecksum(path,checksum,name)
fid=fopen(path,'w');if fid<0,error('lmz:Release:WriteFailed','Cannot write %s.',path);end
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s  %s\n',checksum,name);clear cleanup
end
