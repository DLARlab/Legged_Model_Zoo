function release_write_json(path,value)
%RELEASE_WRITE_JSON Write deterministic UTF-8 JSON plus a final newline.
folder=fileparts(path);
if exist(folder,'dir')~=7,mkdir(folder);end
text=jsonencode(value);
fid=fopen(path,'w','n','UTF-8');
if fid<0,error('lmz:Release:WriteFailed','Cannot write %s.',path);end
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',text);
clear cleanup
end
