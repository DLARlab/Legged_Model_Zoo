classdef PathGuard
    %PATHGUARD Canonical path containment checks for untrusted input.
    methods (Static)
        function value = canonical(value, mustExist)
            if nargin < 2
                mustExist = true;
            end
            value = lmz.compat.Text.character(value, 'path');
            if isempty(value) || any(value == char(0))
                error('lmz:Path:Invalid', 'Path must be nonempty text without NUL bytes.');
            end
            if mustExist && exist(value, 'file') ~= 2 && exist(value, 'dir') ~= 7
                error('lmz:Path:Missing', 'Path does not exist: %s', value);
            end
            try
                value = char(java.io.File(value).getCanonicalPath());
            catch
                if mustExist
                    [ok, attributes] = fileattrib(value);
                    if ~ok
                        error('lmz:Path:Canonical', ...
                            'Could not canonicalize path: %s', value);
                    end
                    value = attributes.Name;
                else
                    parent = fileparts(value);
                    if isempty(parent)
                        parent = pwd;
                    end
                    [~, name, extension] = fileparts(value);
                    parent = lmz.util.PathGuard.canonical(parent, true);
                    value = fullfile(parent, [name extension]);
                end
            end
        end

        function value = resolveWithin(root, relativePath, mustExist)
            if nargin < 3
                mustExist = true;
            end
            root = lmz.util.PathGuard.canonical(root, true);
            relativePath = lmz.compat.Text.character(relativePath, 'relative path');
            lmz.util.PathGuard.validateRelative(relativePath);
            value = lmz.util.PathGuard.canonical( ...
                fullfile(root, relativePath), mustExist);
            lmz.util.PathGuard.assertWithin(root, value);
        end

        function assertWithin(root, candidate)
            root = lmz.util.PathGuard.canonical(root, true);
            candidate = lmz.util.PathGuard.canonical(candidate, ...
                exist(candidate, 'file') == 2 || exist(candidate, 'dir') == 7);
            rootPrefix = [root filesep];
            if strcmp(candidate, root)
                return
            end
            if ispc
                inside = strncmpi(candidate, rootPrefix, numel(rootPrefix));
            else
                inside = strncmp(candidate, rootPrefix, numel(rootPrefix));
            end
            if ~inside
                error('lmz:Path:Traversal', ...
                    'Resolved path escapes its approved root: %s', candidate);
            end
        end

        function tf = isWithin(root, candidate)
            try
                lmz.util.PathGuard.assertWithin(root, candidate);
                tf = true;
            catch
                tf = false;
            end
        end

        function validateRelative(value)
            value = lmz.compat.Text.character(value, 'relative path');
            if isempty(value) || any(value == char(0)) || ...
                    value(1) == '/' || value(1) == char(92) || ...
                    ~isempty(regexp(value, '^[A-Za-z]:', 'once')) || ...
                    ~isempty(regexp(value, '^(//|\\\\)', 'once'))
                error('lmz:Path:Absolute', ...
                    'Only a nonempty relative path is allowed: %s', value);
            end
            parts = regexp(strrep(value, char(92), '/'), '/', 'split');
            if any(strcmp(parts, '..')) || any(strcmp(parts, '.')) || ...
                    any(cellfun(@isempty, parts))
                error('lmz:Path:Traversal', ...
                    'Relative path contains a traversal segment: %s', value);
            end
        end
    end
end
