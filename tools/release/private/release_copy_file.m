function release_copy_file(source,destination)
folder=fileparts(destination);
if exist(folder,'dir')~=7
    [ok,message]=mkdir(folder);
    if ~ok,error('lmz:Release:StageFailed','%s',message);end
end
[ok,message]=copyfile(source,destination,'f');
if ~ok,error('lmz:Release:StageFailed','%s',message);end
end
