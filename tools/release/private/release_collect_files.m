function files=release_collect_files(root)
%RELEASE_COLLECT_FILES Return deterministic repository-relative file paths.
absolute=collect(root,root);
files=cell(size(absolute));
prefix=[root filesep];
for index=1:numel(absolute)
    files{index}=strrep(absolute{index}(numel(prefix)+1:end),filesep,'/');
end
files=sort(files);
end

function files=collect(folder,root)
entries=dir(folder);files={};
for index=1:numel(entries)
    name=entries(index).name;
    if strcmp(name,'.')||strcmp(name,'..'),continue,end
    path=fullfile(folder,name);
    if entries(index).isdir
        relative=relativePath(root,path);
        if excludedDirectory(relative),continue,end
        files=[files collect(path,root)]; %#ok<AGROW>
    elseif ~excludedFile(relativePath(root,path))
        files{end+1}=path; %#ok<AGROW>
    end
end
end

function value=excludedDirectory(relative)
parts=strsplit(strrep(relative,'\','/'),'/');
value=any(strcmp(parts,'.git'))||any(strcmp(parts,'.svn'))|| ...
    any(strcmp(parts,'slprj'))||any(strcmp(parts,'codegen'))|| ...
    any(strcmp(parts,'.matlab'))||strcmp(relative,'release/out')|| ...
    strcmp(relative,'release/staging');
end

function value=excludedFile(relative)
[~,name,extension]=fileparts(relative);
value=strcmp(name,'.DS_Store')||strcmpi(name,'Thumbs')|| ...
    ~isempty(regexp([name extension], ...
        '^Legged_Model_Zoo_.*Prompt\.md$','once'))|| ...
    strcmpi(extension,'.asv')||strcmpi(extension,'.autosave')|| ...
    strcmpi(extension,'.mltbx')||strcmpi(extension,'.zip')|| ...
    strcmpi(extension,'.sha256');
end

function value=relativePath(root,path)
prefix=[root filesep];value=path;
if strncmp(path,prefix,numel(prefix)),value=path(numel(prefix)+1:end);end
value=strrep(value,filesep,'/');
end
