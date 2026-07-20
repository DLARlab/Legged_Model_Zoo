function installations = find_matlab_installations
%FIND_MATLAB_INSTALLATIONS Inspect standard roots without downloading MATLAB.
patterns = {};
if ismac
    patterns = {'/Applications/MATLAB_R*.app'};
elseif ispc
    programFiles = getenv('ProgramFiles');
    patterns = {fullfile(programFiles, 'MATLAB', 'R*')};
else
    patterns = {'/usr/local/MATLAB/R*', '/opt/MATLAB/R*'};
end
installations = struct('Path', {}, 'Release', {}, 'CurrentProcess', {});
for patternIndex = 1:numel(patterns)
    entries = dir(patterns{patternIndex});
    for entryIndex = 1:numel(entries)
        if ~entries(entryIndex).isdir
            continue
        end
        path = fullfile(entries(entryIndex).folder, entries(entryIndex).name);
        token = regexp(entries(entryIndex).name, 'R(\d{4}[ab])', ...
            'tokens', 'once');
        if isempty(token)
            release = 'unknown';
        else
            release = ['R' token{1}];
        end
        installations(end + 1) = struct('Path', path, ... %#ok<AGROW>
            'Release', release, 'CurrentProcess', ...
            strcmpi(release, ['R' version('-release')]));
    end
end
if isempty(installations)
    fprintf('LMZ_MATLAB_INSTALLATIONS none-found-in-standard-roots\n');
else
    [~, order] = sort({installations.Release});
    installations = installations(order);
    for index = 1:numel(installations)
        fprintf('LMZ_MATLAB_INSTALLATION release=%s current=%d path=%s\n', ...
            installations(index).Release, ...
            installations(index).CurrentProcess, installations(index).Path);
    end
end
end
