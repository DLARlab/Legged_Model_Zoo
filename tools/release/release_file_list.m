function [files,report]=release_file_list(profile,role)
%RELEASE_FILE_LIST Resolve a profile without weakening authorization gates.
if nargin<2||isempty(role),role='source-zip';end
profile=normalizeProfile(profile);
[scan,manifest]=scan_redistribution();
entries=manifest.files;selected=false(numel(entries),1);
for index=1:numel(entries)
    profiles=release_cellstr(entries(index).profiles);
    roles=release_cellstr(entries(index).releaseRoles);
    selected(index)=any(strcmp(profile,profiles))&&any(strcmp(role,roles));
end
selectedEntries=entries(selected);files=sort({selectedEntries.relativePath});
blockers={};
for index=1:numel(selectedEntries)
    if ~selectedEntries(index).redistributable|| ...
            ~strcmp(selectedEntries(index).decisionStatus,'permitted')
        blockers{end+1}=selectedEntries(index).relativePath; %#ok<AGROW>
    end
end
projectAuthorized=manifest.projectDecision.redistributable&& ...
    strcmp(manifest.projectDecision.decisionStatus,'permitted');
report=struct('Profile',profile,'Role',role,'Entries',selectedEntries, ...
    'Files',{files},'BlockingFiles',{sort(blockers)}, ...
    'ProjectDecision',manifest.projectDecision, ...
    'Authorized',projectAuthorized&&isempty(blockers), ...
    'Scan',scan,'Manifest',manifest);
end

function value=normalizeProfile(value)
if isstring(value)&&isscalar(value),value=char(value);end
aliases=struct('core','core','scientific','scientific', ...
    'legged_model_zoo_core','core','legged_model_zoo_scientific','scientific');
key=strrep(strrep(lower(value),'-','_'),' ','_');
if ~isfield(aliases,key),error('lmz:Release:UnknownProfile','Unknown release profile: %s',value);end
value=aliases.(key);
end
