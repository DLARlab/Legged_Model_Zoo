function violations=static_architecture_check(root)
% Check forbidden constructs in generic framework packages.
files=dir(fullfile(root,'src','+lmz','**','*.m')); violations={};
patterns={'\<global\>','restoredefaultpath','addpath\s*\(\s*genpath','\<eval(in)?\s*\(','\<assignin\s*\(','Quadrupedal_ZeroFun','ZeroFunc_Biped','Quad_Load_ZeroFun'};
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); text=fileread(path);
    for j=1:numel(patterns)
        if ~isempty(regexp(text,patterns{j},'once')), violations{end+1}=sprintf('%s: %s',path,patterns{j}); end %#ok<AGROW>
    end
end
end
