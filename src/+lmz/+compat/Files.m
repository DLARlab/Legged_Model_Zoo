classdef Files
    %FILES Cross-release discovery and atomic file operations.
    methods (Static)
        function files = recursive(folder, extension, forceFallback)
            if nargin < 2 || isempty(extension)
                extension = '*';
            end
            if nargin < 3
                forceFallback = false;
            end
            folder = lmz.compat.Text.character(folder, 'folder');
            extension = lmz.compat.Text.character(extension, 'extension');
            if exist(folder, 'dir') ~= 7
                files = struct('name', {}, 'folder', {}, 'date', {}, ...
                    'bytes', {}, 'isdir', {}, 'datenum', {});
                return
            end
            if ~forceFallback
                try
                    files = dir(fullfile(folder, '**', extension));
                    files = files(~[files.isdir]);
                    return
                catch
                    % Fall through to the recursive implementation.
                end
            end
            files = lmz.compat.Files.walk(folder, extension);
        end

        function path = temporary(folder, extension)
            if nargin < 1 || isempty(folder)
                folder = tempdir;
            end
            if nargin < 2
                extension = '';
            end
            if exist(folder, 'dir') ~= 7
                error('lmz:Compatibility:MissingFolder', ...
                    'Temporary-file folder does not exist: %s', folder);
            end
            path = [tempname(folder) extension];
        end

        function atomicMove(source, target, forceFallback)
            if nargin < 3
                forceFallback = false;
            end
            source = lmz.compat.Text.character(source, 'source');
            target = lmz.compat.Text.character(target, 'target');
            if exist(source, 'file') ~= 2
                error('lmz:Compatibility:MissingTemporaryFile', ...
                    'Temporary file does not exist: %s', source);
            end
            if ~forceFallback
                [ok, message] = movefile(source, target, 'f');
            else
                if exist(target, 'file') == 2
                    delete(target);
                end
                [ok, message] = movefile(source, target);
            end
            if ~ok
                error('lmz:Compatibility:AtomicMove', ...
                    'Could not finalize %s: %s', target, message);
            end
        end
    end

    methods (Static, Access = private)
        function files = walk(folder, extension)
            entries = dir(folder);
            files = entries([]);
            for index = 1:numel(entries)
                entry = entries(index);
                if entry.isdir
                    if strcmp(entry.name, '.') || strcmp(entry.name, '..')
                        continue
                    end
                    child = lmz.compat.Files.walk( ...
                        fullfile(folder, entry.name), extension);
                    files = [files; child(:)]; %#ok<AGROW>
                elseif lmz.compat.Files.matches(entry.name, extension)
                    entry.folder = folder;
                    files = [files; entry]; %#ok<AGROW>
                end
            end
        end

        function tf = matches(name, pattern)
            if strcmp(pattern, '*')
                tf = true;
                return
            end
            expression = regexptranslate('wildcard', pattern);
            tf = ~isempty(regexp(name, ['^' expression '$'], 'once'));
        end
    end
end
