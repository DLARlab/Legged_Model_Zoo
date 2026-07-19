function violations=static_architecture_check(root)
% Check forbidden constructs in generic framework packages.
files=[dir(fullfile(root,'src','+lmz','**','*.m')); ...
    dir(fullfile(root,'models','+lmzmodels','**','*.m'))]; violations={};
patterns={'\<global\>','restoredefaultpath','addpath\s*\(\s*genpath','\<eval(in)?\s*\(','\<assignin\s*\('};
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); text=fileread(path);
    for j=1:numel(patterns)
        if ~isempty(regexp(text,patterns{j},'once')), violations{end+1}=sprintf('%s: %s',path,patterns{j}); end %#ok<AGROW>
    end
end
restricted= [dir(fullfile(root,'src','+lmz','+gui','**','*.m')); ...
    dir(fullfile(root,'src','+lmz','+services','**','*.m'))];
restrictedPatterns={'\<fsolve\s*\(','\<fmincon\s*\(','\<fminsearch\s*\(', ...
    'Quadrupedal_ZeroFun','ZeroFunc_Biped','Quad_Load_ZeroFun', ...
    'not implemented','status\s*=\s*''not-implemented'''};
for k=1:numel(restricted)
    path=fullfile(restricted(k).folder,restricted(k).name);text=fileread(path);
    for j=1:numel(restrictedPatterns)
        if ~isempty(regexpi(text,restrictedPatterns{j},'once')),violations{end+1}=sprintf('%s: %s',path,restrictedPatterns{j});end %#ok<AGROW>
    end
end
quadrupedProblem=fullfile(root,'models','+lmzmodels','+slip_quadruped','PeriodicApexProblem.m');
if exist(quadrupedProblem,'file')==2
    problemText=fileread(quadrupedProblem);
    if ~isempty(regexp(problemText,'speed\s*\*\s*stride_period|stride_period\s*\*\s*speed','once'))
        violations{end+1}='Synthetic stride closure remains in slip_quadruped/periodic_apex';
    end
end
adapterPath=fullfile(root,'models','+lmzmodels','+slip_quadruped','Results29Adapter.m');
if exist(adapterPath,'file')==2
    adapterText=fileread(adapterPath);
    if isempty(strfind(adapterText,'lmz.data.SolutionBranch')) %#ok<STREMP>
        violations{end+1}='Results29Adapter does not construct a native SolutionBranch';
    end
end
modelFiles=dir(fullfile(root,'models','+lmzmodels','**','*.m'));
rawResultsAllow={adapterPath,fullfile(root,'models','+lmzmodels','+slip_quadruped','Results29Layout.m')};
for k=1:numel(modelFiles)
    path=fullfile(modelFiles(k).folder,modelFiles(k).name);
    if contains(path,[filesep '+legacy' filesep])||any(strcmp(path,rawResultsAllow)),continue,end
    text=fileread(path);
    if ~isempty(regexp(text,'results\s*\(\s*(?:\d|:)','once'))
        violations{end+1}=sprintf('%s: raw Results29 indexing outside adapter/layout boundary',path); %#ok<AGROW>
    end
end
genericFiles=dir(fullfile(root,'src','+lmz','**','*.m'));
for k=1:numel(genericFiles)
    path=fullfile(genericFiles(k).folder,genericFiles(k).name);text=fileread(path);
    if ~isempty(regexp(text,'PK_20_2|BD1_20_2','once'))
        violations{end+1}=sprintf('%s: hard-coded RoadMap filename in generic package',path); %#ok<AGROW>
    end
    if ~isempty(regexp(text,'(?:addpath|genpath)[^\n]*SLIP_Model_Zoo','once'))
        violations{end+1}=sprintf('%s: runtime source-repository path dependency',path); %#ok<AGROW>
    end
end
recorderPath=fullfile(root,'src','+lmz','+services','RecorderService.m');
if exist(recorderPath,'file')==2
    recorderText=fileread(recorderPath);
    requiredRecorderTokens={'onCleanup','commitTemporary','safeClose','safeRestore'};
    for tokenIndex=1:numel(requiredRecorderTokens)
        if isempty(strfind(recorderText,requiredRecorderTokens{tokenIndex})) %#ok<STREMP>
            violations{end+1}=sprintf('RecorderService is missing resource-safety token %s',requiredRecorderTokens{tokenIndex}); %#ok<AGROW>
        end
    end
end
oldPackages = {'+jerboabiped', '+slipquadruped', '+quadload'};
for k=1:numel(oldPackages)
    if exist(fullfile(root,'models','+lmzmodels',oldPackages{k}),'dir') == 7
        contents=dir(fullfile(root,'models','+lmzmodels',oldPackages{k},'*.m'));
        if ~isempty(contents), violations{end+1}=sprintf('Active old package: %s',oldPackages{k}); end %#ok<AGROW>
    end
end
end
