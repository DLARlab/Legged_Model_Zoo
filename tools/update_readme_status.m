function update_readme_status
%UPDATE_README_STATUS Regenerate README model table from catalog manifests.
startup;
registry = lmz.registry.ModelRegistry.discover();
ids = registry.listModels();
rows = cell(numel(ids), 1);
for index = 1:numel(ids)
    manifest = registry.getManifest(ids{index});
    capabilities = manifest.capabilities;
    rows{index} = sprintf('| `%s` | %s | %s | %s | %s | %s | %s |', ...
        manifest.id, manifest.name, yesNo(capabilities.simulate), ...
        yesNo(capabilities.visualize), yesNo(capabilities.solve), ...
        yesNo(capabilities.('continue')), yesNo(capabilities.optimize));
end
header = {'<!-- LMZ:MODEL_TABLE:BEGIN -->', ...
    '| Model ID | Label | Simulation | Visualization | Solve | Continuation | Optimization |', ...
    '|---|---|---:|---:|---:|---:|---:|'};
generated = strjoin([header'; rows; {'<!-- LMZ:MODEL_TABLE:END -->'}], newline);
path = fullfile(lmz.util.ProjectPaths.root(), 'README.md');
text = fileread(path);
pattern = '<!-- LMZ:MODEL_TABLE:BEGIN -->[\s\S]*?<!-- LMZ:MODEL_TABLE:END -->';
updated = regexprep(text, pattern, generated, 'once');
if isempty(regexp(text, pattern, 'once'))
    error('lmz:Documentation:ModelTableMarkers', ...
        'README model-table markers are missing.');
end
if strcmp(text, updated)
    fprintf('README model table is already current.\n');
    return
end
file = fopen(path, 'w');
if file < 0, error('lmz:Documentation:WriteFailed','Cannot write README.'); end
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', updated);
clear cleanup
end

function value = yesNo(condition)
if condition, value = 'Yes'; else, value = 'No'; end
end
