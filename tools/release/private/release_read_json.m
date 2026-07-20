function value=release_read_json(path)
if exist(path,'file')~=2
    error('lmz:Release:MissingManifest','Missing release file: %s',path);
end
value=jsondecode(fileread(path));
end
