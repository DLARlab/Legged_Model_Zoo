function [report, results] = run_coverage(options)
%RUN_COVERAGE Measure statement coverage by file and MATLAB package.
%   This tool requires R2023a or newer for programmatic CoverageResult.
if nargin < 1
    options = struct();
end
if exist('matlab.unittest.plugins.codecoverage.CoverageResult', 'class') ~= 8
    error('lmz:Coverage:ProgrammaticResultUnavailable', ...
        ['Programmatic coverage summaries require MATLAB R2023a or newer. ' ...
        'Use the CI Cobertura output on older releases.']);
end

startup;
root = lmz.util.ProjectPaths.root();
toolsPath = fullfile(root, 'tools');
fixturesPath = fullfile(root, 'tests', 'fixtures');
addpath(toolsPath);
addpath(fixturesPath);
pathCleanup = onCleanup(@() removePaths(toolsPath, fixturesPath));

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

suite = TestSuite.fromFolder(fullfile(root, 'tests'), ...
    'IncludingSubfolders', true);
if isfield(options, 'Suite') && ~isempty(options.Suite)
    suite = options.Suite;
end
format = CoverageResult();
plugin = CodeCoveragePlugin.forFolder( ...
    {fullfile(root, 'src'), fullfile(root, 'models')}, ...
    'IncludingSubfolders', true, 'Producing', format);
runner = TestRunner.withTextOutput();
runner.addPlugin(plugin);
results = runner.run(suite);
if any([results.Failed]) || any([results.Incomplete])
    error('lmz:Coverage:TestsFailed', ...
        'Coverage is invalid because tests failed or were incomplete.');
end

coverage = format.Result;
files = repmat(emptyFile(), numel(coverage), 1);
for index = 1:numel(coverage)
    summary = coverageSummary(coverage(index), 'statement');
    path = char(coverage(index).Filename);
    files(index) = struct('Path', relativePath(root, path), ...
        'Package', packageName(root, path), 'Class', className(path), ...
        'CoveredStatements', summary(1), 'TotalStatements', summary(2), ...
        'LineRate', safeRate(summary(1), summary(2)), ...
        'SourcePreservedCompatibility', ...
        contains(path, [filesep '+legacy' filesep]));
end
packages = aggregatePackages(files);
covered = sum([files.CoveredStatements]);
total = sum([files.TotalStatements]);
report = struct('schemaVersion', '1.0.0', ...
    'frameworkVersion', lmz.util.Version.current(), ...
    'matlabRelease', version('-release'), 'matlabVersion', version, ...
    'measuredAt', lmz.compat.Timestamp.current(), ...
    'overall', struct('coveredStatements', covered, ...
    'totalStatements', total, 'lineRate', safeRate(covered, total)), ...
    'packages', packages, 'files', files, ...
    'exclusions', struct('paths', {{}}, 'rationale', ...
    ['No runtime files were excluded. Source-preserved compatibility ' ...
    'evaluators remain visible and are additionally protected by numerical ' ...
    'regression tests.']));

if isfield(options, 'CoberturaPath') && ~isempty(options.CoberturaPath)
    generateCoberturaReport(coverage, options.CoberturaPath);
end
if isfield(options, 'OutputPath') && ~isempty(options.OutputPath)
    writeJson(options.OutputPath, report);
end
if option(options, 'EnforceBaseline', false)
    enforceBaseline(root, report);
end
fprintf('LMZ_COVERAGE_OK files=%d packages=%d statements=%d/%d rate=%.4f\n', ...
    numel(files), numel(packages), covered, total, report.overall.lineRate);
clear pathCleanup
end

function packages = aggregatePackages(files)
names = unique({files.Package});
packages = repmat(struct('Name', '', 'CoveredStatements', 0, ...
    'TotalStatements', 0, 'LineRate', 0, 'FileCount', 0), numel(names), 1);
for index = 1:numel(names)
    selected = strcmp({files.Package}, names{index});
    covered = sum([files(selected).CoveredStatements]);
    total = sum([files(selected).TotalStatements]);
    packages(index) = struct('Name', names{index}, ...
        'CoveredStatements', covered, 'TotalStatements', total, ...
        'LineRate', safeRate(covered, total), ...
        'FileCount', sum(selected));
end
end

function value = packageName(root, path)
relative = relativePath(root, path);
parts = regexp(relative, regexptranslate('escape', filesep), 'split');
packageParts = {};
for index = 1:numel(parts) - 1
    if numel(parts{index}) > 1 && parts{index}(1) == '+'
        packageParts{end + 1} = parts{index}(2:end); %#ok<AGROW>
    end
end
if isempty(packageParts)
    value = '(top-level)';
else
    value = strjoin(packageParts, '.');
end
end

function value = className(path)
[~, value] = fileparts(path);
end

function value = safeRate(covered, total)
if total == 0
    value = 1;
else
    value = covered / total;
end
end

function value = emptyFile()
value = struct('Path', '', 'Package', '', 'Class', '', ...
    'CoveredStatements', 0, 'TotalStatements', 0, 'LineRate', 0, ...
    'SourcePreservedCompatibility', false);
end

function enforceBaseline(root, report)
path = fullfile(root, 'coverage', 'baseline_policy.json');
if exist(path, 'file') ~= 2
    error('lmz:Coverage:MissingBaseline', ...
        'Coverage baseline policy is missing.');
end
policy = lmz.compat.Json.read(path);
if ~isfield(policy, 'measured') || ~policy.measured
    error('lmz:Coverage:UnmeasuredBaseline', ...
        'Coverage policy is not marked as a measured baseline.');
end
items = policy.stablePackages;
if iscell(items)
    items = [items{:}];
end
for index = 1:numel(items)
    match = find(strcmp({report.packages.Name}, items(index).name), 1);
    if isempty(match)
        error('lmz:Coverage:MissingPackage', ...
            'Stable package is absent from coverage: %s', items(index).name);
    end
    actual = report.packages(match).LineRate;
    if actual + eps < items(index).minimumLineRate
        error('lmz:Coverage:Regression', ...
            ['Package %s coverage %.4f is below its measured regression ' ...
            'floor %.4f.'], items(index).name, actual, ...
            items(index).minimumLineRate);
    end
end
end

function writeJson(path, value)
path = lmz.compat.Text.character(path, 'coverage output path');
[folder, ~, ~] = fileparts(path);
if isempty(folder)
    folder = pwd;
end
if exist(folder, 'dir') ~= 7
    mkdir(folder);
end
temporary = lmz.compat.Files.temporary(folder, '.json');
cleanup = onCleanup(@() deleteIfPresent(temporary));
file = fopen(temporary, 'w');
if file < 0
    error('lmz:Coverage:Output', 'Could not open coverage output.');
end
fileCleanup = onCleanup(@() fclose(file));
fprintf(file, '%s\n', lmz.compat.Json.encode(value, true));
clear fileCleanup
lmz.compat.Files.atomicMove(temporary, path);
clear cleanup
end

function removePaths(toolsPath, fixturesPath)
if contains(path, toolsPath)
    rmpath(toolsPath);
end
if contains(path, fixturesPath)
    rmpath(fixturesPath);
end
end

function deleteIfPresent(path)
if exist(path, 'file') == 2
    delete(path);
end
end

function value = option(options, name, fallback)
if isfield(options, name)
    value = options.(name);
else
    value = fallback;
end
end

function value = relativePath(root, path)
prefix = [root filesep];
value = path;
if strncmp(path, prefix, numel(prefix))
    value = path(numel(prefix) + 1:end);
end
end
