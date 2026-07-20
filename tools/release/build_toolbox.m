function result=build_toolbox(profile,options)
%BUILD_TOOLBOX Build an authorization-gated MATLAB toolbox package.
if nargin<2,options=struct();end
options=normalizeOptions(options);
[files,selection]=release_file_list(profile,'toolbox');
root=lmz.util.ProjectPaths.root();sourceState=release_source_state(root);
result=struct('Profile',selection.Profile,'Mode',options.Mode, ...
    'Authorized',selection.Authorized,'BlockingFiles',{selection.BlockingFiles}, ...
    'ToolboxPath','','Sha256','','Retained',false,'InstallTest',struct(), ...
    'TestEvidence',struct(),'SourceTreeState',sourceState);
if strcmp(options.Mode,'dry-run')
    fprintf('LMZ_TOOLBOX_DRY_RUN profile=%s files=%d blockers=%d\n', ...
        selection.Profile,numel(files),numel(selection.BlockingFiles));return
end
if strcmp(options.Mode,'public')&&~selection.Authorized
    error('lmz:Release:AuthorizationBlocked', ...
        'Public %s toolbox build is not authorized.',selection.Profile);
end
if exist('matlab.addons.toolbox.ToolboxOptions','class')~=8
    error('lmz:Release:ToolboxOptionsUnavailable', ...
        'This MATLAB release cannot construct ToolboxOptions; use the ZIP fallback.');
end
temporary=tempname;mkdir(temporary);
cleanup=onCleanup(@()release_remove_tree(temporary));
stage=fullfile(temporary,'LeggedModelZoo');mkdir(stage);
for index=1:numel(files)
    release_copy_file(fullfile(root,strrep(files{index},'/',filesep)), ...
        fullfile(stage,strrep(files{index},'/',filesep)));
end
release_copy_file(fullfile(root,'release','redistribution_manifest.json'), ...
    fullfile(stage,'release','redistribution_manifest.json'));
if selection.Authorized,authority='permitted';else,authority='NOT_FOR_REDISTRIBUTION';end
metadata=struct('schemaVersion','1.0.0', ...
    'frameworkVersion',lmz.util.Version.current(),'profile',selection.Profile, ...
    'authorizationStatus',authority, ...
    'repositoryCommit',sourceState.repositoryCommit, ...
    'sourceTreeState',sourceState, ...
    'testEvidence',toolboxEvidence('not-requested',struct()));
metadataPath=fullfile(stage,'TOOLBOX_RELEASE.json');
identifier=['dlarlab-legged-model-zoo-' selection.Profile];
if options.RunInstallTest
    metadata.testEvidence=toolboxEvidence('pending',struct());
    release_write_json(metadataPath,metadata);
    preflightPath=fullfile(temporary,sprintf( ...
        'Legged_Model_Zoo-%s-%s-preflight.mltbx', ...
        lmz.util.Version.current(),selection.Profile));
    packageToolbox(stage,preflightPath,identifier,selection.Profile,authority);
    preflightInstall=run_clean_install_test(preflightPath);
    metadata.testEvidence=toolboxEvidence('passed',preflightInstall);
end
release_write_json(metadataPath,metadata);
toolboxPath=fullfile(temporary,sprintf('Legged_Model_Zoo-%s-%s.mltbx', ...
    lmz.util.Version.current(),selection.Profile));
packageToolbox(stage,toolboxPath,identifier,selection.Profile,authority);
if exist(toolboxPath,'file')~=2,error('lmz:Release:ToolboxBuildFailed','Toolbox packager produced no file.');end
result.Sha256=lmz.util.FileHash.sha256(toolboxPath);
if options.RunInstallTest,result.InstallTest=run_clean_install_test(toolboxPath);end
result.TestEvidence=metadata.testEvidence;
if strcmp(options.Mode,'public')
    if exist(options.OutputDirectory,'dir')~=7,mkdir(options.OutputDirectory);end
    finalPath=fullfile(options.OutputDirectory, ...
        sprintf('Legged_Model_Zoo-%s-%s.mltbx',lmz.util.Version.current(),selection.Profile));
    release_copy_file(toolboxPath,[finalPath '.tmp']);
    [ok,message]=movefile([finalPath '.tmp'],finalPath,'f');
    if ~ok,error('lmz:Release:AtomicMoveFailed','%s',message);end
    result.ToolboxPath=finalPath;result.Retained=true;
end
fprintf('LMZ_TOOLBOX_BUILD_OK profile=%s mode=%s sha256=%s retained=%d\n', ...
    selection.Profile,options.Mode,result.Sha256,result.Retained);
clear cleanup
end

function packageToolbox(stage,toolboxPath,identifier,profile,authority)
packageFiles=release_collect_files(stage);
absoluteFiles=cellfun(@(path)fullfile(stage,strrep(path,'/',filesep)), ...
    packageFiles,'UniformOutput',false);
matlabPaths={stage};
if exist(fullfile(stage,'src'),'dir')==7,matlabPaths{end+1}=fullfile(stage,'src');end
if exist(fullfile(stage,'models'),'dir')==7,matlabPaths{end+1}=fullfile(stage,'models');end
toolboxOptions=matlab.addons.toolbox.ToolboxOptions(stage,identifier, ...
    'ToolboxName',['Legged Model Zoo ' profile], ...
    'ToolboxVersion',toolboxNumericVersion(), ...
    'Summary','Legged Model Zoo release profile', ...
    'Description',['Authorization status: ' authority], ...
    'ToolboxFiles',absoluteFiles,'ToolboxMatlabPath',matlabPaths, ...
    'OutputFile',toolboxPath,'MinimumMatlabRelease', ...
    lmz.util.Version.minimumMatlabRelease());
matlab.addons.toolbox.packageToolbox(toolboxOptions);
end

function value=toolboxEvidence(status,install)
value=struct('packageVerification','not-requested', ...
    'cleanInstall','not-requested','registryDiscovery',false, ...
    'permittedWorkflow',false,'guiConstruction',false, ...
    'artifactRoundTrip',false,'pathRemoval',false, ...
    'automatedTestSuite','not-run-by-package-builder', ...
    'evidenceScope',['The toolbox was packaged, but clean installation is ' ...
        'reported separately unless requested.']);
if strcmp(status,'pending')
    value.packageVerification='pending';value.cleanInstall='pending';
    value.evidenceScope=['Temporary preflight toolbox; it is never retained ' ...
        'or returned by the builder.'];return
end
if strcmp(status,'passed')
    value.packageVerification='clean-install-passed';
    value.cleanInstall='passed';
    value.registryDiscovery=install.RegistryDiscovery;
    value.permittedWorkflow=install.Workflow;
    value.guiConstruction=install.GuiConstruction;
    value.artifactRoundTrip=install.ArtifactRoundTrip;
    value.pathRemoval=install.Unloaded;
    value.evidenceScope=['Recorded from a preflight toolbox with identical ' ...
        'functional payload. The final toolbox is rebuilt only to embed this ' ...
        'evidence, then independently clean-install tested before it can be ' ...
        'returned or retained.'];
end
end

function value=toolboxNumericVersion()
version=lmz.util.Version.parse(lmz.util.Version.current());number=0;
if ~isempty(version.Prerelease)&&numel(version.Prerelease)>=2&& ...
        strcmp(version.Prerelease{1},'rc')
    number=str2double(version.Prerelease{2});
end
value=sprintf('%d.%d.%d.%d',version.Major,version.Minor,version.Patch,number);
end

function options=normalizeOptions(options)
defaults=struct('Mode','public','DryRun',false,'RunInstallTest',false, ...
    'OutputDirectory',fullfile(lmz.util.ProjectPaths.root(),'release','out'));
names=fieldnames(options);for index=1:numel(names),defaults.(names{index})=options.(names{index});end
options=defaults;if options.DryRun,options.Mode='dry-run';end
if ~any(strcmp(options.Mode,{'public','dry-run','technical-validation'}))
    error('lmz:Release:InvalidMode','Invalid toolbox build mode.');
end
end
