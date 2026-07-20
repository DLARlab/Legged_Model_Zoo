classdef ModelRegistry < handle
    %MODELREGISTRY Discover validated built-in and explicitly trusted models.
    properties (SetAccess = private)
        Entries
        CatalogRoot
        CatalogRoots
    end
    properties (Access = private)
        PluginRegistrations = {}
    end

    methods (Static)
        function registry = discover(catalogRoot)
            if nargin < 1
                catalogRoot = lmz.util.ProjectPaths.catalog();
            end
            information = struct('CatalogRoot', ...
                lmz.util.PathGuard.canonical(catalogRoot, true), ...
                'CodeRoot', lmz.util.PathGuard.canonical( ...
                lmz.util.ProjectPaths.models(), true), ...
                'Namespace', 'lmzmodels', 'External', false);
            registry = lmz.registry.ModelRegistry(information, {});
        end

        function registry = discoverWithPlugins(pluginRoots, varargin)
            parser = inputParser;
            addRequired(parser, 'pluginRoots');
            addParameter(parser, 'IncludeBuiltIns', true, ...
                @(x) islogical(x) && isscalar(x));
            parse(parser, pluginRoots, varargin{:});
            roots = pluginRoots;
            if ischar(roots) || (isstring(roots) && isscalar(roots))
                roots = {lmz.compat.Text.character(roots, 'plugin root')};
            elseif isstring(roots)
                roots = cellstr(roots(:));
            end
            if ~iscell(roots) || ~all(cellfun(@(x) ischar(x) || ...
                    (isstring(x) && isscalar(x)), roots))
                error('lmz:Registry:PluginRoots', ...
                    'Plugin roots must be a text value or cell array of text.');
            end
            registrations = cell(1, numel(roots));
            try
                for index = 1:numel(roots)
                    registrations{index} = ...
                        lmz.registry.PluginRegistration.trust(roots{index});
                end
                information = struct('CatalogRoot', {}, 'CodeRoot', {}, ...
                    'Namespace', {}, 'External', {});
                if parser.Results.IncludeBuiltIns
                    information(end + 1) = struct('CatalogRoot', ...
                        lmz.util.PathGuard.canonical( ...
                        lmz.util.ProjectPaths.catalog(), true), ...
                        'CodeRoot', lmz.util.PathGuard.canonical( ...
                        lmz.util.ProjectPaths.models(), true), ...
                        'Namespace', 'lmzmodels', 'External', false);
                end
                for index = 1:numel(registrations)
                    registration = registrations{index};
                    information(end + 1) = struct( ...
                        'CatalogRoot', registration.CatalogRoot, ...
                        'CodeRoot', registration.CodeRoot, ...
                        'Namespace', registration.Namespace, ...
                        'External', true); %#ok<AGROW>
                end
                lmz.registry.ModelRegistry.assertUniqueCatalogIds( ...
                    information);
                registry = lmz.registry.ModelRegistry(information, registrations);
            catch exception
                for index = 1:numel(registrations)
                    if ~isempty(registrations{index})
                        delete(registrations{index});
                    end
                end
                rethrow(exception);
            end
        end
    end

    methods
        function obj = ModelRegistry(rootInformation, registrations)
            if nargin < 2
                registrations = {};
            end
            if ischar(rootInformation)
                rootInformation = struct('CatalogRoot', ...
                    lmz.util.PathGuard.canonical(rootInformation, true), ...
                    'CodeRoot', lmz.util.PathGuard.canonical( ...
                    lmz.util.ProjectPaths.models(), true), ...
                    'Namespace', 'lmzmodels', 'External', false);
            end
            if isempty(rootInformation)
                error('lmz:Registry:EmptyCatalog', ...
                    'At least one catalog root is required.');
            end
            obj.PluginRegistrations = registrations;
            obj.CatalogRoots = {rootInformation.CatalogRoot};
            obj.CatalogRoot = obj.CatalogRoots{1};
            entries = struct([]);
            modelIds = {};
            for rootIndex = 1:numel(rootInformation)
                info = rootInformation(rootIndex);
                catalogRoot = lmz.util.PathGuard.canonical( ...
                    info.CatalogRoot, true);
                files = dir(fullfile(catalogRoot, '*', 'manifest.json'));
                for index = 1:numel(files)
                    manifestPath = lmz.util.PathGuard.canonical( ...
                        fullfile(files(index).folder, files(index).name), true);
                    lmz.util.PathGuard.assertWithin(catalogRoot, manifestPath);
                    manifest = lmz.io.SafeJson.read(manifestPath, ...
                        'Root', catalogRoot);
                    % Reject a duplicate identity before resolving executable
                    % classes from the second trusted root. Two plugins may
                    % deliberately use the same namespace, in which case
                    % MATLAB path precedence would otherwise obscure the
                    % intended duplicate-ID diagnostic.
                    if isstruct(manifest) && isscalar(manifest) && ...
                            isfield(manifest, 'id') && ischar(manifest.id) && ...
                            any(strcmp(manifest.id, modelIds))
                        error('lmz:Registry:DuplicateModelId', ...
                            'Duplicate model ID: %s', manifest.id);
                    end
                    manifest = lmz.registry.ModelRegistry.validateManifest( ...
                        manifest, files(index).folder, info);
                    if any(strcmp(manifest.id, modelIds))
                        error('lmz:Registry:DuplicateModelId', ...
                            'Duplicate model ID: %s', manifest.id);
                    end
                    modelIds{end + 1} = manifest.id; %#ok<AGROW>
                    manifest.catalogDirectory = files(index).folder;
                    manifest.trustedCodeRoot = info.CodeRoot;
                    manifest.trustedNamespace = info.Namespace;
                    manifest.external = logical(info.External);
                    if isempty(entries)
                        entries = manifest;
                    else
                        entries(end + 1, 1) = manifest; %#ok<AGROW>
                    end
                end
            end
            if isempty(entries)
                error('lmz:Registry:EmptyCatalog', ...
                    'No model manifests were found under the catalog roots.');
            end
            obj.Entries = entries;
        end

        function delete(obj)
            registrations = obj.PluginRegistrations;
            obj.PluginRegistrations = {};
            for index = 1:numel(registrations)
                if ~isempty(registrations{index}) && isvalid(registrations{index})
                    delete(registrations{index});
                end
            end
        end

        function ids = listModels(obj)
            ids = arrayfun(@(entry) entry.id, obj.Entries, ...
                'UniformOutput', false);
            ids = reshape(sort(ids), 1, []);
        end

        function manifest = getManifest(obj, modelId)
            modelId = lmz.registry.ModelRegistry.canonicalModelId(modelId);
            ids = arrayfun(@(entry) entry.id, obj.Entries, ...
                'UniformOutput', false);
            index = find(strcmp(modelId, ids), 1);
            if isempty(index)
                error('lmz:Registry:UnknownModel', ...
                    'Unknown model ID: %s', modelId);
            end
            manifest = obj.Entries(index);
        end

        function descriptor = getProblemDescriptor(obj, modelId, problemId)
            manifest = obj.getManifest(modelId);
            context = lmz.registry.RegistryEntryContext(manifest, ...
                manifest.catalogDirectory, manifest.trustedCodeRoot, ...
                manifest.external);
            descriptor = context.problemDescriptor(problemId);
        end

        function capabilities = getCapabilities(obj, modelId)
            capabilities = obj.getManifest(modelId).capabilities;
        end

        function config = getGraphicsConfig(obj, modelId)
            manifest = obj.getManifest(modelId);
            if isfield(manifest, 'graphicsConfigPath') && ...
                    ~isempty(manifest.graphicsConfigPath)
                config = lmz.viz.GraphicsConfig.fromJson( ...
                    manifest.graphicsConfigPath, manifest.catalogDirectory, ...
                    manifest.trustedCodeRoot, manifest.trustedNamespace);
            else
                config = lmz.viz.GraphicsConfig.cleanGeneric( ...
                    manifest.catalogDirectory, manifest.trustedCodeRoot, ...
                    manifest.trustedNamespace);
            end
            contract = manifest.visualizationContract;
            config.validateContract(contract.frames,contract.parameters);
        end

        function model = createModel(obj, modelId)
            modelId = lmz.registry.ModelRegistry.canonicalModelId(modelId);
            manifest = obj.getManifest(modelId);
            lmz.registry.ModelRegistry.assertResolvedClass( ...
                manifest.implementationClass, manifest.trustedCodeRoot);
            constructor = str2func(manifest.implementationClass);
            model = constructor();
            if ~isa(model, 'lmz.api.LeggedModel')
                error('lmz:Registry:InvalidImplementation', ...
                    '%s does not implement lmz.api.LeggedModel.', ...
                    manifest.implementationClass);
            end
            actualManifest = model.getManifest();
            if ~isstruct(actualManifest) || ~isfield(actualManifest, 'id') || ...
                    ~isfield(actualManifest, 'version') || ...
                    ~strcmp(actualManifest.id, manifest.id) || ...
                    ~strcmp(actualManifest.version, manifest.version)
                error('lmz:Registry:ImplementationIdentity', ...
                    ['Implementation identity/version does not match ' ...
                    'catalog model %s.'], modelId);
            end
            context = lmz.registry.RegistryEntryContext(manifest, ...
                manifest.catalogDirectory, manifest.trustedCodeRoot, ...
                manifest.external);
            model.bindRegistryContext(context);
            actualCapabilities = model.getCapabilities();
            expectedNames = fieldnames(manifest.capabilities);
            for index = 1:numel(expectedNames)
                name = expectedNames{index};
                if ~isfield(actualCapabilities, name) || ...
                        actualCapabilities.(name) ~= manifest.capabilities.(name)
                    error('lmz:Registry:CapabilityMismatch', ...
                        'Capability %s for %s does not match its manifest.', ...
                        name, modelId);
                end
            end
        end
    end

    methods (Static, Access = private)
        function assertUniqueCatalogIds(rootInformation)
            % Preflight identities before MATLAB path precedence is used to
            % resolve any executable plugin class. This gives an explicit
            % duplicate-ID failure even when two roots share a namespace.
            modelIds = {};
            for rootIndex = 1:numel(rootInformation)
                catalogRoot = rootInformation(rootIndex).CatalogRoot;
                files = dir(fullfile(catalogRoot, '*', 'manifest.json'));
                for index = 1:numel(files)
                    manifestPath = lmz.util.PathGuard.canonical(fullfile( ...
                        files(index).folder, files(index).name), true);
                    lmz.util.PathGuard.assertWithin(catalogRoot, manifestPath);
                    manifest = lmz.io.SafeJson.read(manifestPath, ...
                        'Root', catalogRoot);
                    if ~isstruct(manifest) || ~isscalar(manifest) || ...
                            ~isfield(manifest, 'id') || ~ischar(manifest.id)
                        continue
                    end
                    if any(strcmp(manifest.id, modelIds))
                        error('lmz:Registry:DuplicateModelId', ...
                            'Duplicate model ID: %s', manifest.id);
                    end
                    modelIds{end + 1} = manifest.id; %#ok<AGROW>
                end
            end
        end

        function manifest = validateManifest(manifest, catalogDirectory, info)
            required = {'schemaVersion','id','version','name', ...
                'implementationClass','problems'};
            lmz.registry.ModelRegistry.requireFields(manifest, required, 'manifest');
            if ~isstruct(manifest) || ~isscalar(manifest)
                error('lmz:Registry:ManifestType', ...
                    'A model manifest must be one JSON object.');
            end
            if ~strcmp(manifest.schemaVersion, '1.0.0')
                error('lmz:Registry:UnsupportedManifestVersion', ...
                    'Unsupported manifest schema version: %s', manifest.schemaVersion);
            end
            lmz.registry.ModelRegistry.validateId(manifest.id, 'model');
            [~, folderId] = fileparts(catalogDirectory);
            if ~strcmp(folderId, manifest.id)
                error('lmz:Registry:CatalogIdMismatch', ...
                    'Catalog directory %s does not match model ID %s.', ...
                    folderId, manifest.id);
            end
            if ~ischar(manifest.name) || isempty(strtrim(manifest.name))
                error('lmz:Registry:InvalidName', 'Model name must be nonempty text.');
            end
            if isempty(regexp(manifest.version, ...
                    '^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$', 'once'))
                error('lmz:Registry:InvalidSemanticVersion', ...
                    'Model version is not semantic: %s', manifest.version);
            end
            if info.External
                prefix = [info.Namespace '.'];
                allowed = strncmp(manifest.implementationClass, ...
                    prefix, numel(prefix));
            else
                allowed = ~isempty(regexp(manifest.implementationClass, ...
                    '^lmzmodels\.[A-Za-z][A-Za-z0-9_.]*$', 'once'));
            end
            if ~allowed
                error('lmz:Registry:UnsafeImplementation', ...
                    'Implementation class is outside its approved namespace.');
            end
            lmz.registry.ModelRegistry.assertResolvedClass( ...
                manifest.implementationClass, info.CodeRoot);

            problemIds = lmz.registry.ModelRegistry.cellstrValue( ...
                manifest.problems, 'problems');
            if isempty(problemIds) || numel(unique(problemIds)) ~= numel(problemIds)
                error('lmz:Registry:DuplicateProblemId', ...
                    'Manifest %s has empty or duplicate problem IDs.', manifest.id);
            end
            descriptors = cell(numel(problemIds), 1);
            for index = 1:numel(problemIds)
                lmz.registry.ModelRegistry.validateId(problemIds{index}, 'problem');
                relative = fullfile('problems', [problemIds{index} '.json']);
                descriptorPath = lmz.util.PathGuard.resolveWithin( ...
                    catalogDirectory, relative, false);
                if exist(descriptorPath, 'file') ~= 2
                    error('lmz:Registry:MissingProblemDescriptor', ...
                        'Problem descriptor is missing: %s', relative);
                end
                descriptor = lmz.io.SafeJson.read(descriptorPath, ...
                    'Root', catalogDirectory);
                descriptors{index} = ...
                    lmz.registry.ModelRegistry.validateProblem( ...
                    descriptor, problemIds{index});
            end
            manifest.problemDescriptors = descriptors;
            if isfield(manifest, 'capabilities')
                manifest.declaredCapabilities = manifest.capabilities;
            else
                manifest.declaredCapabilities = struct();
            end
            manifest.capabilities = ...
                lmz.registry.ModelRegistry.deriveCapabilities(descriptors);
            if manifest.capabilities.visualize
                scenePath = lmz.util.PathGuard.resolveWithin( ...
                    catalogDirectory, 'scene.lmz.json', true);
                scene = lmz.viz.SceneSpec.fromJson(scenePath, catalogDirectory);
                graphicsPath = fullfile(catalogDirectory, 'graphics.lmz.json');
                if exist(graphicsPath, 'file') == 2
                    graphicsPath = lmz.util.PathGuard.canonical(graphicsPath, true);
                    lmz.util.PathGuard.assertWithin(catalogDirectory, graphicsPath);
                    if ~isfield(manifest,'visualizationContract')
                        error('lmz:Registry:MissingVisualizationContract', ...
                            ['A model with graphics.lmz.json must declare ' ...
                            'visualizationContract in its manifest.']);
                    end
                    contract=lmz.registry.ModelRegistry. ...
                        validateVisualizationContract(manifest.visualizationContract);
                    config=lmz.viz.GraphicsConfig.fromJson(graphicsPath, ...
                        catalogDirectory, info.CodeRoot, info.Namespace);
                    config.validateContract(contract.frames,contract.parameters);
                    manifest.visualizationContract=contract;
                    manifest.graphicsConfigPath = graphicsPath;
                else
                    if isfield(manifest,'visualizationContract')
                        contract=lmz.registry.ModelRegistry. ...
                            validateVisualizationContract(manifest.visualizationContract);
                        if ~all(ismember(contract.frames,scene.Frames))
                            error('lmz:Registry:VisualizationContractScene', ...
                                ['visualizationContract declares a frame ' ...
                                'absent from scene.lmz.json.']);
                        end
                    else
                        contract=struct('frames',{reshape(scene.Frames,1,[])}, ...
                            'parameters',{{}});
                    end
                    manifest.visualizationContract=contract;
                    manifest.graphicsConfigPath = '';
                end
            else
                manifest.visualizationContract=struct('frames',{{}}, ...
                    'parameters',{{}});
                manifest.graphicsConfigPath = '';
            end
        end

        function descriptor = validateProblem(descriptor, expectedId)
            required = {'schemaVersion','id','kind','implementationId', ...
                'implemented','maturity','provenance','validationStatus', ...
                'capabilities'};
            lmz.registry.ModelRegistry.requireFields( ...
                descriptor, required, 'problem descriptor');
            if ~isstruct(descriptor) || ~isscalar(descriptor)
                error('lmz:Registry:ProblemType', ...
                    'A problem descriptor must be one JSON object.');
            end
            if ~strcmp(descriptor.schemaVersion, '1.0.0')
                error('lmz:Registry:UnsupportedProblemVersion', ...
                    'Unsupported problem schema version for %s.', expectedId);
            end
            if ~strcmp(descriptor.id, expectedId)
                error('lmz:Registry:ProblemIdMismatch', ...
                    'Problem filename ID and descriptor ID differ.');
            end
            if ~ischar(descriptor.implementationId) || ...
                    isempty(regexp(descriptor.implementationId, ...
                    '^[A-Za-z][A-Za-z0-9_.-]*$', 'once'))
                error('lmz:Registry:ImplementationId', ...
                    'Problem implementationId is invalid.');
            end
            supportedKinds = {'simulation','nonlinear_equation','optimization'};
            if ~any(strcmp(descriptor.kind, supportedKinds))
                error('lmz:Registry:UnsupportedProblemKind', ...
                    'Unsupported problem kind: %s', descriptor.kind);
            end
            if ~islogical(descriptor.implemented) || ~isscalar(descriptor.implemented)
                error('lmz:Registry:InvalidImplementedFlag', ...
                    'Problem implemented flag must be logical scalar.');
            end
            maturities = {'tutorial','compatibility','validated','experimental'};
            if ~ischar(descriptor.maturity) || ...
                    ~any(strcmp(descriptor.maturity, maturities))
                error('lmz:Registry:InvalidMaturity', ...
                    'Unsupported problem maturity for %s.', expectedId);
            end
            statuses = {'untested','tested','source-equivalent'};
            if ~ischar(descriptor.validationStatus) || ...
                    ~any(strcmp(descriptor.validationStatus, statuses))
                error('lmz:Registry:InvalidValidationStatus', ...
                    'Unsupported validation status for %s.', expectedId);
            end
            if ~isstruct(descriptor.provenance) || ~isscalar(descriptor.provenance)
                error('lmz:Registry:InvalidProvenance', ...
                    'Problem provenance for %s must be a scalar object.', expectedId);
            end
            descriptor.capabilities = ...
                lmz.registry.ModelRegistry.validateProblemCapabilities( ...
                descriptor.capabilities, expectedId);
            if ~descriptor.implemented
                values = struct2cell(descriptor.capabilities);
                if any([values{:}])
                    error('lmz:Registry:UnimplementedCapability', ...
                        'Unimplemented problem %s cannot advertise capabilities.', ...
                        expectedId);
                end
            end
        end

        function capabilities = validateProblemCapabilities(capabilities, problemId)
            if ~isstruct(capabilities) || ~isscalar(capabilities)
                error('lmz:Registry:InvalidProblemCapabilities', ...
                    'Capabilities for %s must be a scalar object.', problemId);
            end
            required = {'simulate','solve','continue','optimize','visualize','animate'};
            optional = {'parameterHomotopy','branchFamilyScan'};
            lmz.registry.ModelRegistry.requireFields( ...
                capabilities, required, 'problem capabilities');
            names = fieldnames(capabilities);
            if ~all(ismember(names, [required optional]))
                error('lmz:Registry:UnknownProblemCapability', ...
                    'Problem %s declares an unknown capability.', problemId);
            end
            for index = 1:numel(names)
                value = capabilities.(names{index});
                if ~islogical(value) || ~isscalar(value)
                    error('lmz:Registry:InvalidProblemCapability', ...
                        'Capability %s for %s must be a logical scalar.', ...
                        names{index}, problemId);
                end
            end
            for index = 1:numel(optional)
                if ~isfield(capabilities, optional{index})
                    capabilities.(optional{index}) = false;
                end
            end
        end

        function capabilities = deriveCapabilities(descriptors)
            names = {'simulate','solve','continue','optimize','visualize', ...
                'animate','parameterHomotopy','branchFamilyScan'};
            capabilities = struct();
            for index = 1:numel(names)
                capabilities.(names{index}) = false;
            end
            for descriptorIndex = 1:numel(descriptors)
                descriptor = descriptors{descriptorIndex};
                if ~descriptor.implemented
                    continue
                end
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    capabilities.(name) = capabilities.(name) || ...
                        descriptor.capabilities.(name);
                end
            end
        end

        function assertResolvedClass(className, codeRoot)
            matches = which(className, '-all');
            if isempty(matches)
                error('lmz:Registry:MissingImplementation', ...
                    'Implementation class is unavailable: %s', className);
            end
            if ischar(matches)
                matches = {matches};
            end
            canonicalMatches = cell(size(matches));
            for index = 1:numel(matches)
                canonicalMatches{index} = ...
                    lmz.util.PathGuard.canonical(matches{index}, true);
            end
            canonicalMatches = unique(canonicalMatches);
            if numel(canonicalMatches) ~= 1
                error('lmz:Registry:AmbiguousImplementation', ...
                    'Implementation class is shadowed or ambiguous: %s', className);
            end
            if ~lmz.util.PathGuard.isWithin(codeRoot, canonicalMatches{1})
                error('lmz:Registry:ImplementationOutsideRoot', ...
                    'Implementation %s resolves outside its trusted code root.', ...
                    className);
            end
        end

        function validateId(value, description)
            if ~ischar(value) || isempty(regexp(value, ...
                    '^[a-z][a-z0-9_]*$', 'once'))
                error('lmz:Registry:InvalidId', ...
                    '%s ID must be a lowercase identifier.', description);
            end
        end

        function requireFields(value, fields, description)
            if ~isstruct(value)
                error('lmz:Registry:InvalidObject', ...
                    '%s must be a JSON object.', description);
            end
            for index = 1:numel(fields)
                if ~isfield(value, fields{index})
                    error('lmz:Registry:MissingField', ...
                        'Missing %s field %s.', description, fields{index});
                end
            end
        end

        function values = cellstrValue(value, fieldName)
            if ischar(value)
                values = {value};
            elseif iscell(value) && all(cellfun(@ischar, value))
                values = value(:)';
            else
                error('lmz:Registry:InvalidStringList', ...
                    '%s must be a string list.', fieldName);
            end
        end

        function contract=validateVisualizationContract(value)
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~all(isfield(value,{'frames','parameters'}))|| ...
                    ~all(ismember(fieldnames(value),{'frames','parameters'}))
                error('lmz:Registry:VisualizationContract', ...
                    ['visualizationContract must contain only frames and ' ...
                    'parameters string lists.']);
            end
            frames=lmz.registry.ModelRegistry.cellstrValue(value.frames,'frames');
            if isempty(frames)
                error('lmz:Registry:VisualizationContract', ...
                    'Visualization contract frames cannot be empty.');
            end
            if isempty(value.parameters)
                parameters={};
            else
                parameters=lmz.registry.ModelRegistry.cellstrValue( ...
                    value.parameters,'parameters');
            end
            values=[frames parameters];
            if numel(unique(frames))~=numel(frames)|| ...
                    numel(unique(parameters))~=numel(parameters)|| ...
                    any(cellfun(@(item)isempty(regexp(item, ...
                    '^[A-Za-z][A-Za-z0-9_]*$','once')),values))
                error('lmz:Registry:VisualizationContract', ...
                    'Visualization contract names must be unique identifiers.');
            end
            contract=struct('frames',{reshape(frames,1,[])}, ...
                'parameters',{reshape(parameters,1,[])});
        end
    end

    methods (Static)
        function canonical = canonicalModelId(modelId)
            aliases = struct( ...
                'old', {'jerboa.biped.offset','slip.quadruped.planar.v2', ...
                    'slip.quadruped.load'}, ...
                'canonical', {'slip_biped','slip_quadruped','slip_quad_load'});
            canonical = modelId;
            for index = 1:numel(aliases)
                if strcmp(modelId, aliases(index).old)
                    canonical = aliases(index).canonical;
                    warning('lmz:Registry:DeprecatedModelId', ...
                        'Model ID %s is deprecated; use %s.', ...
                        modelId, canonical);
                    return
                end
            end
        end
    end
end
