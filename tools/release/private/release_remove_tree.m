function release_remove_tree(path)
if exist(path,'dir')==7,rmdir(path,'s');elseif exist(path,'file')==2,delete(path);end
end
