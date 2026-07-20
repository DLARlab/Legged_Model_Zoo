function violations=static_architecture_check(root)
% Check forbidden constructs in generic framework packages.
files=[dir(fullfile(root,'src','+lmz','**','*.m')); ...
    dir(fullfile(root,'models','+lmzmodels','**','*.m'))]; violations={};
getframeOwner=fullfile(root,'src','+lmz','+compat','Graphics.m');
patterns={'\<global\>','restoredefaultpath','addpath\s*\(\s*genpath','\<eval(in)?\s*\(','\<assignin\s*\('};
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); text=fileread(path);
    for j=1:numel(patterns)
        if ~isempty(regexp(text,patterns{j},'once')), violations{end+1}=sprintf('%s: %s',path,patterns{j}); end %#ok<AGROW>
    end
    if ~strcmp(path,getframeOwner)&& ...
            ~isempty(regexp(text,'\<getframe\s*\(','once'))
        violations{end+1}=sprintf( ... %#ok<AGROW>
            '%s: runtime getframe must route through lmz.compat.Graphics',path);
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
rawResultsAllow={adapterPath, ...
    fullfile(root,'models','+lmzmodels','+slip_quadruped','Results29Layout.m'), ...
    fullfile(root,'models','+lmzmodels','+slip_biped','Results14Adapter.m'), ...
    fullfile(root,'models','+lmzmodels','+slip_biped','Results14Layout.m')};
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

% Round 8 graphics boundaries.  The generic GUI may select profiles, but
% model renderer classes and scientific channel layouts stay model-owned.
simulationTab=fullfile(root,'src','+lmz','+gui','+tabs','SimulationTab.m');
if exist(simulationTab,'file')==2
    tabText=fileread(simulationTab);
    if ~isempty(regexp(tabText,'lmzmodels\.|(?:Quadruped|Biped|QuadLoad)Renderer','once'))
        violations{end+1}= ... %#ok<AGROW>
            'SimulationTab hard-codes a model renderer instead of RendererFactory';
    end
end

% Generic visualization code must consume named kinematics/observables.  A
% raw numeric state column here would silently couple it to a model schema.
visualizationFiles=dir(fullfile(root,'src','+lmz','+viz','*.m'));
for k=1:numel(visualizationFiles)
    path=fullfile(visualizationFiles(k).folder,visualizationFiles(k).name);
    text=fileread(path);
    if ~isempty(regexp(text,'\.States\s*\(\s*(?::|\d+)\s*,\s*\d+','once'))|| ...
            ~isempty(regexp(text,'\.state\s*\(\s*\d+','once'))
        violations{end+1}=sprintf( ... %#ok<AGROW>
            '%s: numeric model-state indexing in generic visualization package',path);
    end
end

% Model renderers own axes children only.  Figure creation, recording, and
% dependencies on immutable source checkouts belong to framework services or
% maintainer tooling, never an ordinary renderer.
scientificPackages={'+slip_quadruped','+slip_biped','+slip_quad_load'};
rendererPatterns={'\<figure\s*\(','\<uifigure\s*\(','\<VideoWriter\s*\(', ...
    '\<imwrite\s*\(','\<getframe\s*\(', ...
    'SLIP_Model_Zoo|Jerboa_Gait_Transitions|Load_Pulling_Quadrupeds'};
for packageIndex=1:numel(scientificPackages)
    rendererFiles=dir(fullfile(root,'models','+lmzmodels', ...
        scientificPackages{packageIndex},'*Renderer.m'));
    for fileIndex=1:numel(rendererFiles)
        path=fullfile(rendererFiles(fileIndex).folder,rendererFiles(fileIndex).name);
        text=fileread(path);
        for patternIndex=1:numel(rendererPatterns)
            if ~isempty(regexp(text,rendererPatterns{patternIndex},'once'))
                violations{end+1}=sprintf('%s: forbidden renderer ownership token %s', ... %#ok<AGROW>
                    path,rendererPatterns{patternIndex});
            end
        end
    end
end

% Only clean_generic may opt into the deliberately simplified scientific
% renderers.  Research and high-contrast scientific profiles retain the
% compound ResearchRenderer geometry.
for packageIndex=1:numel(scientificPackages)
    modelId=scientificPackages{packageIndex}(2:end);
    configPath=fullfile(root,'catalog',modelId,'graphics.lmz.json');
    if exist(configPath,'file')~=2
        violations{end+1}=sprintf('%s: missing graphics.lmz.json',modelId); %#ok<AGROW>
        continue
    end
    config=lmz.compat.Json.decode(fileread(configPath));
    profiles=config.profiles;
    for profileIndex=1:numel(profiles)
        profile=profiles(profileIndex);
        if any(strcmp(profile.id,{'research_legacy','high_contrast'}))&& ...
                isempty(strfind(profile.rendererClass,'.ResearchRenderer')) %#ok<STREMP>
            violations{end+1}=sprintf( ... %#ok<AGROW>
                '%s/%s does not use compound ResearchRenderer geometry', ...
                modelId,profile.id);
        end
    end
end
end
