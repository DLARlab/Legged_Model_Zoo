function report = run_code_quality(projectRoot)
%RUN_CODE_QUALITY Analyze maintained MATLAB runtime code and architecture.
if nargin < 1
    projectRoot = lmz.util.ProjectPaths.root();
end
allowlist = code_quality_allowlist();
files = [lmz.compat.Files.recursive(fullfile(projectRoot, 'src'), '*.m', true); ...
    lmz.compat.Files.recursive(fullfile(projectRoot, 'models'), '*.m', true); ...
    dir(fullfile(projectRoot, 'startup.m')); ...
    dir(fullfile(projectRoot, 'legged_model_zoo.m'))];
violations = {};
allowed = struct('Path', {}, 'Line', {}, 'Identifier', {}, ...
    'Message', {}, 'Rationale', {});
excludedLegacy = {};
documentationFindings = {};
complexityFindings = {};

for index = 1:numel(files)
    path = fullfile(files(index).folder, files(index).name);
    relative = relativePath(projectRoot, path);
    if contains(relative, '/+legacy/')
        excludedLegacy{end + 1} = relative; %#ok<AGROW>
        continue
    end
    text = fileread(path);
    messages = checkcode(path, '-id', '-struct');
    for messageIndex = 1:numel(messages)
        message = messages(messageIndex);
        [accepted, rationale] = allowedFinding( ...
            allowlist, message.id, relative);
        if accepted
            allowed(end + 1) = struct('Path', relative, ... %#ok<AGROW>
                'Line', message.line, 'Identifier', message.id, ...
                'Message', message.message, 'Rationale', rationale);
        else
            violations{end + 1} = sprintf('%s:%d [%s] %s', ... %#ok<AGROW>
                relative, message.line, message.id, message.message);
        end
    end

    mismatch = classNameMismatch(path, text);
    if ~isempty(mismatch)
        violations{end + 1} = sprintf('%s: %s', relative, mismatch); %#ok<AGROW>
    end
    if contains(relative, '/+gui/') && ...
            ~isempty(regexp(withoutComments(text), ...
            '\<(fsolve|fmincon|fminsearch)\s*\(', 'once'))
        violations{end + 1} = sprintf( ... %#ok<AGROW>
            '%s: GUI code calls a numerical solver directly.', relative);
    end
    if contains(relative, '/+gui/') && ...
            ~isempty(regexp(text, ...
            'Quadrupedal_ZeroFun|ZeroFunc_Biped|Quad_Load_ZeroFun', 'once'))
        violations{end + 1} = sprintf( ... %#ok<AGROW>
            '%s: GUI code references a model-specific evaluator.', relative);
    end
    if ~isempty(regexp(withoutComments(text), '\<fopen\s*\(', 'once')) && ...
            isempty(regexp(withoutComments(text), ...
            '\<(onCleanup|fclose)\s*\(', 'once'))
        violations{end + 1} = sprintf( ... %#ok<AGROW>
            '%s: fopen has no visible cleanup boundary.', relative);
    end
    if missingPrimaryHelp(text)
        documentationFindings{end + 1} = sprintf( ... %#ok<AGROW>
            '%s: primary class/function has no adjacent help text.', relative);
    end
    nesting = approximateNesting(text);
    if nesting > 12
        complexityFindings{end + 1} = sprintf( ... %#ok<AGROW>
            '%s: approximate nesting depth is %d.', relative, nesting);
    end
end

stableHelpFiles = { ...
    'src/+lmz/+api/LeggedModel.m', ...
    'src/+lmz/+api/RunContext.m', ...
    'src/+lmz/+data/SolveResult.m', ...
    'src/+lmz/+data/ContinuationResult.m', ...
    'src/+lmz/+data/OptimizationResult.m', ...
    'src/+lmz/+services/SolveService.m', ...
    'src/+lmz/+services/ContinuationService.m', ...
    'src/+lmz/+services/OptimizationService.m'};
for index = 1:numel(stableHelpFiles)
    expected = stableHelpFiles{index};
    if any(cellfun(@(value) strncmp(value, expected, numel(expected)), ...
            documentationFindings))
        violations{end + 1} = sprintf( ... %#ok<AGROW>
            '%s: stable public API requires primary help text.', expected);
    end
end

report = struct('SchemaVersion', '1.0.0', ...
    'MatlabRelease', version('-release'), 'FilesAnalyzed', numel(files), ...
    'Violations', {violations}, 'AllowedFindings', allowed, ...
    'DocumentationFindings', {documentationFindings}, ...
    'ComplexityFindings', {complexityFindings}, ...
    'ExcludedLegacyFiles', {excludedLegacy}, ...
    'LegacyExclusionRationale', ...
    ['Source-preserved compatibility evaluators are assessed through ' ...
    'scientific numerical regression tests rather than style linting.']);
fprintf(['LMZ_CODE_QUALITY files=%d violations=%d allowed=%d ' ...
    'missingHelp=%d complexity=%d excludedLegacy=%d\n'], ...
    report.FilesAnalyzed, numel(violations), numel(allowed), ...
    numel(documentationFindings), numel(complexityFindings), ...
    numel(excludedLegacy));
end

function [accepted, rationale] = allowedFinding(entries, identifier, path)
accepted = false;
rationale = '';
for index = 1:numel(entries)
    if strcmp(entries(index).Identifier, identifier) && ...
            ~isempty(regexp(path, entries(index).ScopePattern, 'once'))
        accepted = true;
        rationale = entries(index).Rationale;
        return
    end
end
end

function value = classNameMismatch(path, text)
value = '';
token = regexp(text, ...
    '^\s*classdef(?:\s*\([^\)]*\))?\s+([A-Za-z]\w*)', ...
    'tokens', 'once');
if isempty(token)
    return
end
[~, fileName] = fileparts(path);
if ~strcmp(fileName, token{1})
    value = sprintf('class name %s does not match file name %s.', ...
        token{1}, fileName);
end
end

function tf = missingPrimaryHelp(text)
lines = regexp(text, '\r\n|\n|\r', 'split');
first = find(~cellfun(@(line) isempty(strtrim(line)), lines), 1);
tf = false;
if isempty(first) || isempty(regexp(lines{first}, ...
        '^\s*(classdef|function)\>', 'once'))
    return
end
next = first + 1;
while next <= numel(lines) && isempty(strtrim(lines{next}))
    next = next + 1;
end
tf = next > numel(lines) || ...
    isempty(regexp(lines{next}, '^\s*%', 'once'));
end

function value = approximateNesting(text)
code = withoutComments(text);
lines = regexp(code, '\r\n|\n|\r', 'split');
depth = 0;
value = 0;
openPattern = '^\s*(if|for|while|switch|try|parfor|spmd)\>';
for index = 1:numel(lines)
    line = strtrim(lines{index});
    if ~isempty(regexp(line, '^end\>', 'once'))
        depth = max(0, depth - 1);
    end
    if ~isempty(regexp(line, openPattern, 'once'))
        depth = depth + 1;
        value = max(value, depth);
    end
end
end

function code = withoutComments(text)
lines = regexp(text, '\r\n|\n|\r', 'split');
for index = 1:numel(lines)
    marker = find(lines{index} == '%', 1);
    if ~isempty(marker)
        lines{index} = lines{index}(1:marker - 1);
    end
end
code = strjoin(lines, sprintf('\n'));
end

function value = relativePath(root, path)
prefix = [root filesep];
value = path;
if strncmp(path, prefix, numel(prefix))
    value = path(numel(prefix) + 1:end);
end
value = strrep(value, filesep, '/');
end
