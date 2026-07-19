classdef ModelRegistry
    %MODELREGISTRY Discover and validate declarative model catalogs.
    properties (SetAccess=private)
        Entries
        CatalogRoot
    end

    methods (Static)
        function registry = discover(catalogRoot)
            if nargin < 1
                catalogRoot = lmz.util.ProjectPaths.catalog();
            end
            registry = lmz.registry.ModelRegistry(catalogRoot);
        end
    end

    methods
        function obj = ModelRegistry(catalogRoot)
            obj.CatalogRoot = lmz.registry.ModelRegistry.canonical(catalogRoot);
            files = dir(fullfile(obj.CatalogRoot, '*', 'manifest.json'));
            entries = struct([]);
            modelIds = {};

            for index = 1:numel(files)
                manifestPath = fullfile(files(index).folder, files(index).name);
                manifest = jsondecode(fileread(manifestPath));
                manifest = lmz.registry.ModelRegistry.validateManifest( ...
                    manifest, files(index).folder);

                if any(strcmp(manifest.id, modelIds))
                    error('lmz:Registry:DuplicateModelId', ...
                        'Duplicate model ID: %s', manifest.id);
                end
                modelIds{end + 1} = manifest.id; %#ok<AGROW>
                manifest.catalogDirectory = files(index).folder;
                entries = [entries; manifest]; %#ok<AGROW>
            end

            if isempty(entries)
                error('lmz:Registry:EmptyCatalog', ...
                    'No model manifests were found under %s.', obj.CatalogRoot);
            end
            obj.Entries = entries;
        end

        function ids = listModels(obj)
            ids = arrayfun(@(entry) entry.id, obj.Entries, ...
                'UniformOutput', false);
            ids = reshape(sort(ids), 1, []);
        end

        function manifest = getManifest(obj, modelId)
            modelId = lmz.registry.ModelRegistry.canonicalModelId(modelId);
            index = find(strcmp(modelId, obj.listModels()), 1);
            if isempty(index)
                error('lmz:Registry:UnknownModel', ...
                    'Unknown model ID: %s', modelId);
            end
            manifest = obj.Entries(index);
        end

        function model = createModel(obj, modelId)
            modelId = lmz.registry.ModelRegistry.canonicalModelId(modelId);
            manifest = obj.getManifest(modelId);
            constructor = str2func(manifest.implementationClass);
            model = constructor();
            if ~isa(model, 'lmz.api.LeggedModel')
                error('lmz:Registry:InvalidImplementation', ...
                    '%s does not implement lmz.api.LeggedModel.', ...
                    manifest.implementationClass);
            end
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

    methods (Static, Access=private)
        function manifest = validateManifest(manifest, catalogDirectory)
            required = {'schemaVersion', 'id', 'version', 'name', ...
                'implementationClass', 'problems', 'capabilities'};
            lmz.registry.ModelRegistry.requireFields( ...
                manifest, required, 'manifest');

            if ~strcmp(manifest.schemaVersion, '1.0.0')
                error('lmz:Registry:UnsupportedManifestVersion', ...
                    'Unsupported manifest schema version: %s', ...
                    manifest.schemaVersion);
            end
            if isempty(regexp(manifest.version, ...
                    '^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$', 'once'))
                error('lmz:Registry:InvalidSemanticVersion', ...
                    'Model version is not semantic: %s', manifest.version);
            end
            if isempty(regexp(manifest.implementationClass, ...
                    '^lmzmodels\.[A-Za-z][A-Za-z0-9_.]*$', 'once'))
                error('lmz:Registry:UnsafeImplementation', ...
                    'Implementation must be in the lmzmodels namespace.');
            end
            if exist(manifest.implementationClass, 'class') ~= 8
                error('lmz:Registry:MissingImplementation', ...
                    'Implementation class is unavailable: %s', ...
                    manifest.implementationClass);
            end

            problemIds = lmz.registry.ModelRegistry.cellstrValue( ...
                manifest.problems, 'problems');
            if numel(unique(problemIds)) ~= numel(problemIds)
                error('lmz:Registry:DuplicateProblemId', ...
                    'Manifest %s declares duplicate problem IDs.', manifest.id);
            end
            descriptors = cell(numel(problemIds), 1);
            for index = 1:numel(problemIds)
                descriptorPath = fullfile(catalogDirectory, 'problems', ...
                    [problemIds{index} '.json']);
                if exist(descriptorPath, 'file') ~= 2
                    error('lmz:Registry:MissingProblemDescriptor', ...
                        'Missing descriptor for problem %s.', problemIds{index});
                end
                descriptor = jsondecode(fileread(descriptorPath));
                descriptors{index} = ...
                    lmz.registry.ModelRegistry.validateProblem( ...
                    descriptor, problemIds{index});
            end
            manifest.problemDescriptors = descriptors;

            implemented = cellfun(@(value) value.implemented, descriptors);
            kinds = cellfun(@(value) value.kind, descriptors, ...
                'UniformOutput', false);
            hasEquation = any(implemented & strcmp(kinds, 'nonlinear_equation'));
            hasOptimization = any(implemented & strcmp(kinds, 'optimization'));
            if (manifest.capabilities.solve || ...
                    manifest.capabilities.('continue')) ...
                    && ~hasEquation
                error('lmz:Registry:UnsupportedClaim', ...
                    'Solve/continue requires an implemented equation problem.');
            end
            if manifest.capabilities.optimize && ~hasOptimization
                error('lmz:Registry:UnsupportedClaim', ...
                    'Optimize requires an implemented optimization problem.');
            end
            if manifest.capabilities.simulate && ~any(implemented)
                error('lmz:Registry:UnsupportedClaim', ...
                    'Simulation cannot be claimed when no problem is implemented.');
            end

            if manifest.capabilities.visualize
                scenePath = fullfile(catalogDirectory, 'scene.lmz.json');
                if exist(scenePath, 'file') ~= 2
                    error('lmz:Registry:MissingScene', ...
                        'Visualization requires scene.lmz.json for %s.', ...
                        manifest.id);
                end
            end
        end

        function descriptor = validateProblem(descriptor, expectedId)
            required = {'schemaVersion', 'id', 'kind', ...
                'implementationId', 'implemented'};
            lmz.registry.ModelRegistry.requireFields( ...
                descriptor, required, 'problem descriptor');
            if ~strcmp(descriptor.schemaVersion, '1.0.0')
                error('lmz:Registry:UnsupportedProblemVersion', ...
                    'Unsupported problem schema version for %s.', expectedId);
            end
            if ~strcmp(descriptor.id, expectedId)
                error('lmz:Registry:ProblemIdMismatch', ...
                    'Problem filename ID and descriptor ID differ.');
            end
            supportedKinds = {'simulation', 'nonlinear_equation', 'optimization'};
            if ~any(strcmp(descriptor.kind, supportedKinds))
                error('lmz:Registry:UnsupportedProblemKind', ...
                    'Unsupported problem kind: %s', descriptor.kind);
            end
            if ~islogical(descriptor.implemented) || ~isscalar(descriptor.implemented)
                error('lmz:Registry:InvalidImplementedFlag', ...
                    'Problem implemented flag must be logical scalar.');
            end
        end

        function requireFields(value, fields, description)
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

        function path = canonical(path)
            [ok, attributes] = fileattrib(path);
            if ~ok || ~attributes.directory
                error('lmz:Registry:MissingCatalog', ...
                    'Catalog directory does not exist: %s', path);
            end
            path = attributes.Name;
        end
    end

    methods (Static)
        function canonical = canonicalModelId(modelId)
            aliases = struct( ...
                'old', {'jerboa.biped.offset', 'slip.quadruped.planar.v2', ...
                    'slip.quadruped.load'}, ...
                'canonical', {'slip_biped', 'slip_quadruped', ...
                    'slip_quad_load'});
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
