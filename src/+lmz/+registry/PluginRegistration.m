classdef PluginRegistration < handle
    %PLUGINREGISTRATION Explicit trust and scoped path lease for plugin code.
    properties (SetAccess = private)
        Root
        CodeRoot
        CatalogRoot
        Namespace
        Id
        Version
    end
    properties (Access = private)
        LeaseHeld = false
    end
    methods (Static)
        function obj = trust(root)
            obj = lmz.registry.PluginRegistration(root);
        end
    end
    methods
        function obj = PluginRegistration(root)
            obj.Root = lmz.util.PathGuard.canonical(root, true);
            descriptorPath = lmz.util.PathGuard.resolveWithin( ...
                obj.Root, 'plugin.json', true);
            descriptor = lmz.io.SafeJson.read(descriptorPath, 'Root', obj.Root);
            required = {'schemaVersion','id','version','namespace', ...
                'codeRoot','catalogRoot'};
            for index = 1:numel(required)
                if ~isfield(descriptor, required{index})
                    error('lmz:Registry:PluginField', ...
                        'Plugin descriptor is missing %s.', required{index});
                end
            end
            if ~strcmp(descriptor.schemaVersion, '1.0.0')
                error('lmz:Registry:PluginSchema', ...
                    'Unsupported plugin schema version: %s', ...
                    descriptor.schemaVersion);
            end
            lmz.registry.PluginRegistration.validateIdentifier( ...
                descriptor.id, 'plugin ID');
            if isempty(regexp(descriptor.version, ...
                    '^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$', 'once'))
                error('lmz:Registry:PluginVersion', ...
                    'Plugin version is not semantic: %s', descriptor.version);
            end
            if isempty(regexp(descriptor.namespace, ...
                    '^(lmzplugins|lmzmodels)\.[A-Za-z][A-Za-z0-9_.]*$', ...
                    'once')) || ...
                    lmz.registry.PluginRegistration.isBuiltInNamespace( ...
                    descriptor.namespace)
                error('lmz:Registry:PluginNamespace', ...
                    'Plugin namespace is not isolated and approved: %s', ...
                    descriptor.namespace);
            end
            obj.CodeRoot = lmz.util.PathGuard.resolveWithin( ...
                obj.Root, descriptor.codeRoot, true);
            obj.CatalogRoot = lmz.util.PathGuard.resolveWithin( ...
                obj.Root, descriptor.catalogRoot, true);
            if exist(obj.CodeRoot, 'dir') ~= 7 || ...
                    exist(obj.CatalogRoot, 'dir') ~= 7
                error('lmz:Registry:PluginLayout', ...
                    'Plugin codeRoot and catalogRoot must be directories.');
            end
            obj.Namespace = descriptor.namespace;
            obj.Id = descriptor.id;
            obj.Version = descriptor.version;
            lmz.registry.PluginRegistration.pathLease('acquire', obj.CodeRoot);
            obj.LeaseHeld = true;
        end

        function delete(obj)
            if obj.LeaseHeld
                lmz.registry.PluginRegistration.pathLease( ...
                    'release', obj.CodeRoot);
                obj.LeaseHeld = false;
            end
        end

        function tf = allowsClass(obj, className)
            prefix = [obj.Namespace '.'];
            tf = strncmp(className, prefix, numel(prefix));
        end
    end

    methods (Static, Access = private)
        function validateIdentifier(value, description)
            if ~ischar(value) || isempty(regexp(value, ...
                    '^[a-z][a-z0-9_]*$', 'once'))
                error('lmz:Registry:PluginId', ...
                    '%s must be a lowercase identifier.', description);
            end
        end

        function tf = isBuiltInNamespace(namespace)
            prefix = 'lmzmodels.';
            if ~strncmp(namespace, prefix, numel(prefix))
                tf = false;
                return
            end
            suffix = namespace(numel(prefix) + 1:end);
            separator = find(suffix == '.', 1);
            if ~isempty(separator)
                suffix = suffix(1:separator - 1);
            end
            packagePath = fullfile(lmz.util.ProjectPaths.models(), ...
                '+lmzmodels', ['+' suffix]);
            catalogPath = fullfile( ...
                lmz.util.ProjectPaths.catalog(), suffix);
            tf = exist(packagePath, 'dir') == 7 || ...
                exist(catalogPath, 'dir') == 7;
        end

        function pathLease(action, codeRoot)
            persistent roots counts owned
            if isempty(roots)
                roots = {};
                counts = zeros(1, 0);
                owned = false(1, 0);
            end
            index = find(strcmp(roots, codeRoot), 1);
            switch action
                case 'acquire'
                    if isempty(index)
                        pathEntries = regexp(path, pathsep, 'split');
                        alreadyPresent = any(strcmp(pathEntries, codeRoot));
                        if ~alreadyPresent
                            addpath(codeRoot, '-begin');
                        end
                        roots{end + 1} = codeRoot;
                        counts(end + 1) = 1;
                        owned(end + 1) = ~alreadyPresent;
                    else
                        counts(index) = counts(index) + 1;
                    end
                case 'release'
                    if isempty(index)
                        return
                    end
                    counts(index) = counts(index) - 1;
                    if counts(index) <= 0
                        if owned(index)
                            pathEntries = regexp(path, pathsep, 'split');
                            if any(strcmp(pathEntries, codeRoot))
                                rmpath(codeRoot);
                            end
                        end
                        roots(index) = [];
                        counts(index) = [];
                        owned(index) = [];
                    end
                otherwise
                    error('lmz:Registry:PluginLease', ...
                        'Unknown plugin path-lease action: %s', action);
            end
        end
    end
end
