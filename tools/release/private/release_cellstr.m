function value=release_cellstr(value)
if isempty(value),value={};elseif ischar(value),value={value};elseif isstring(value),value=cellstr(value(:));elseif iscell(value),value=reshape(value,1,[]);else,error('lmz:Release:InvalidStringList','Expected a JSON string list.');end
end
