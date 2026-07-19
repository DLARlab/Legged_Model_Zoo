function tables = generate_readme_tables(writeFile)
%GENERATE_README_TABLES Derive public capability and maturity tables.
if nargin < 1
    writeFile = false;
end
registry = lmz.registry.ModelRegistry.discover();
ids = registry.listModels();

problemCount=0;
for modelIndex=1:numel(ids)
    problemCount=problemCount+numel(registry.getManifest(ids{modelIndex}).problemDescriptors);
end
modelLines=cell(numel(ids)+2,1);
modelLines(1:2)={ ...
    '| Model ID | Label | Simulation | Visualization | Solve | Continuation | Optimization |'; ...
    '|---|---|---:|---:|---:|---:|---:|'};
problemLines=cell(problemCount+2,1);
problemLines(1:2)={ ...
    '| Problem | Kind | Maturity | Validation | Capabilities |'; ...
    '|---|---|---|---|---|'};
problemRow=2;
for modelIndex = 1:numel(ids)
    manifest = registry.getManifest(ids{modelIndex});
    capabilities = registry.getCapabilities(ids{modelIndex});
    modelLines{modelIndex+2,1} = sprintf( ...
        '| `%s` | %s | %s | %s | %s | %s | %s |', ...
        manifest.id,manifest.name,yesNo(capabilities.simulate), ...
        yesNo(capabilities.visualize),yesNo(capabilities.solve), ...
        yesNo(capabilities.('continue')),yesNo(capabilities.optimize));
    model = registry.createModel(ids{modelIndex});
    problemIds = model.listProblems();
    for problemIndex = 1:numel(problemIds)
        descriptor = registry.getProblemDescriptor(ids{modelIndex}, ...
            problemIds{problemIndex});
        problemRow=problemRow+1;
        problemLines{problemRow,1} = sprintf('| `%s/%s` | %s | %s | %s | %s |', ...
            ids{modelIndex},problemIds{problemIndex},descriptor.kind, ...
            descriptor.maturity,descriptor.validationStatus, ...
            capabilityList(descriptor.capabilities));
    end
end
tables = struct('Model',strjoin(modelLines,newline), ...
    'Problem',strjoin(problemLines,newline), ...
    'ModelRows',{modelLines(3:end)},'ProblemRows',{problemLines(3:end)});
if writeFile
    path = fullfile(lmz.util.ProjectPaths.root(),'README.md');
    readme = fileread(path);
    readme = replaceBlock(readme,'<!-- LMZ:MODEL_TABLE:BEGIN -->', ...
        '<!-- LMZ:MODEL_TABLE:END -->',tables.Model);
    readme = replaceBlock(readme,'<!-- LMZ:PROBLEM_TABLE:BEGIN -->', ...
        '<!-- LMZ:PROBLEM_TABLE:END -->',tables.Problem);
    file = fopen(path,'w');
    if file < 0
        error('lmz:Documentation:ReadmeWrite','Unable to open README.md.');
    end
    cleanup = onCleanup(@()fclose(file));
    fprintf(file,'%s',readme);clear cleanup
end
end

function value = yesNo(condition)
if condition,value='Yes';else,value='No';end
end

function value = capabilityList(capabilities)
names = {'simulate','visualize','animate','solve','continue','optimize', ...
    'parameterHomotopy','branchFamilyScan'};
labels = {'simulate','visualize','animate','solve','continue','optimize', ...
    'homotopy','family scan'};
enabled = {};
for index = 1:numel(names)
    if isfield(capabilities,names{index}) && capabilities.(names{index})
        enabled{end+1} = labels{index}; %#ok<AGROW>
    end
end
if isempty(enabled),value='none';else,value=strjoin(enabled,', ');end
end

function text = replaceBlock(text,startMarker,endMarker,content)
starts = strfind(text,startMarker);ends = strfind(text,endMarker);
if numel(starts)~=1 || numel(ends)~=1 || ends(1)<=starts(1)
    error('lmz:Documentation:TableMarkers', ...
        'README table markers are missing, duplicated, or out of order.');
end
prefixEnd=starts(1)+numel(startMarker)-1;
text=[text(1:prefixEnd) newline content newline text(ends(1):end)];
end
