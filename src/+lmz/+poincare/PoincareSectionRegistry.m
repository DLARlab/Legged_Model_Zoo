classdef PoincareSectionRegistry
    %POINCARESECTIONREGISTRY Validated catalog of declarative sections.
    properties (SetAccess = private)
        ModelId = ''
        SchemaVersion = ''
        DefaultSectionByProblem = struct()
        Descriptors = {}
        Sections = {}
        CatalogPath = ''
        CatalogHash = ''
        StateSchema = []
        TrustedCodeRoot = ''
        TrustedNamespace = ''
    end

    methods (Static)
        function obj = fromJson(path, varargin)
            parser = inputParser;
            addRequired(parser, 'path', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'ModelId', '', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'StateSchema', [], @(x) isempty(x) || ...
                isa(x, 'lmz.schema.VariableSchema'));
            addParameter(parser, 'TrustedCodeRoot', '', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            addParameter(parser, 'TrustedNamespace', '', @(x) ischar(x) || ...
                (isstring(x) && isscalar(x)));
            parse(parser, path, varargin{:});
            values = parser.Results;
            canonicalPath = lmz.util.PathGuard.canonical(char(values.path), true);
            catalogDirectory = fileparts(canonicalPath);
            data = lmz.io.SafeJson.read(canonicalPath, ...
                'Root', catalogDirectory, 'MaximumItems', 20000);
            modelId = char(values.ModelId);
            if isempty(modelId)
                [~, modelId] = fileparts(catalogDirectory);
            end
            obj = lmz.poincare.PoincareSectionRegistry(data, ...
                'ModelId', modelId, 'StateSchema', values.StateSchema, ...
                'TrustedCodeRoot', char(values.TrustedCodeRoot), ...
                'TrustedNamespace', char(values.TrustedNamespace), ...
                'CatalogPath', canonicalPath);
        end
    end

    methods
        function obj = PoincareSectionRegistry(data, varargin)
            if nargin == 0
                return
            end
            parser = inputParser;
            addRequired(parser, 'data', @(x) isstruct(x) && isscalar(x));
            addParameter(parser, 'ModelId', '', @ischar);
            addParameter(parser, 'StateSchema', [], @(x) isempty(x) || ...
                isa(x, 'lmz.schema.VariableSchema'));
            addParameter(parser, 'TrustedCodeRoot', '', @ischar);
            addParameter(parser, 'TrustedNamespace', '', @ischar);
            addParameter(parser, 'CatalogPath', '', @ischar);
            parse(parser, data, varargin{:});
            options = parser.Results;
            allowedRoot = {'schemaVersion','defaultSectionByProblem','sections'};
            names = fieldnames(data);
            if ~all(ismember(names, allowedRoot)) || ...
                    ~all(isfield(data, allowedRoot))
                error('lmz:Poincare:CatalogFields', ...
                    ['Poincare catalog must contain only schemaVersion, ' ...
                    'defaultSectionByProblem, and sections.']);
            end
            if ~ischar(data.schemaVersion) || ...
                    ~strcmp(data.schemaVersion, '1.0.0')
                error('lmz:Poincare:CatalogVersion', ...
                    'Unsupported Poincare catalog schema version.');
            end
            if ~isempty(options.ModelId) && isempty(regexp(options.ModelId, ...
                    '^[a-z][a-z0-9_]*$', 'once'))
                error('lmz:Poincare:CatalogModelId', ...
                    'Poincare catalog model ID is invalid.');
            end
            if ~isempty(options.TrustedCodeRoot)
                options.TrustedCodeRoot = lmz.util.PathGuard.canonical( ...
                    options.TrustedCodeRoot, true);
            end
            if ~isempty(options.TrustedNamespace) && isempty(regexp( ...
                    options.TrustedNamespace, ...
                    '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$', ...
                    'once'))
                error('lmz:Poincare:TrustedNamespace', ...
                    'Trusted Poincare namespace is invalid.');
            end
            sectionData = localStructList(data.sections, 'sections');
            if isempty(sectionData) || numel(sectionData) > 128
                error('lmz:Poincare:CatalogSectionCount', ...
                    'Poincare catalog must contain between 1 and 128 sections.');
            end
            descriptors = cell(1, numel(sectionData));
            ids = cell(1, numel(sectionData));
            for index = 1:numel(sectionData)
                localRequireCatalogFields(sectionData{index});
                descriptor = lmz.poincare.PoincareSectionDescriptor( ...
                    sectionData{index});
                if ~isempty(options.StateSchema)
                    coordinateNames = descriptor.CoordinateNames;
                    for coordinateIndex = 1:numel(coordinateNames)
                        options.StateSchema.indexOf( ...
                            coordinateNames{coordinateIndex});
                    end
                end
                descriptors{index} = descriptor;
                ids{index} = descriptor.Id;
            end
            if numel(unique(ids)) ~= numel(ids)
                error('lmz:Poincare:DuplicateSectionId', ...
                    'Poincare section IDs must be unique.');
            end
            defaults = localDefaults(data.defaultSectionByProblem, ids);

            obj.ModelId = options.ModelId;
            obj.SchemaVersion = data.schemaVersion;
            obj.DefaultSectionByProblem = defaults;
            obj.Descriptors = descriptors;
            obj.StateSchema = options.StateSchema;
            obj.TrustedCodeRoot = options.TrustedCodeRoot;
            obj.TrustedNamespace = options.TrustedNamespace;
            obj.CatalogPath = options.CatalogPath;
            if ~isempty(obj.CatalogPath)
                obj.CatalogHash = lmz.util.FileHash.sha256(obj.CatalogPath);
            else
                obj.CatalogHash = localDigest(lmz.compat.Json.encode(data));
            end

            sections = cell(1, numel(descriptors));
            deferred = false(1, numel(descriptors));
            for index = 1:numel(descriptors)
                if strcmp(descriptors{index}.Kind, 'composite') && ...
                        isempty(descriptors{index}.ImplementationClass)
                    deferred(index) = true;
                else
                    sections{index} = obj.instantiate(descriptors{index});
                end
            end
            for index = find(deferred)
                primaryId = descriptors{index}.Parameters.primarySectionId;
                primaryIndex = find(strcmp(primaryId, ids), 1);
                if isempty(primaryIndex) || deferred(primaryIndex)
                    error('lmz:Poincare:CompositePrimary', ...
                        'Composite primary must name a non-composite section.');
                end
                conditions = localCompositeConditions( ...
                    descriptors{index}.Parameters, obj.StateSchema);
                sections{index} = lmz.poincare.CompositeSection( ...
                    descriptors{index}, sections{primaryIndex}, conditions);
            end
            obj.Sections = sections;
        end

        function ids = listSections(obj)
            ids = cellfun(@(x) x.Id, obj.Descriptors, ...
                'UniformOutput', false);
        end

        function valid = hasSection(obj, sectionId)
            valid = any(strcmp(sectionId, obj.listSections()));
        end

        function value = descriptor(obj, sectionId)
            index = obj.indexOf(sectionId);
            value = obj.Descriptors{index};
        end

        function value = section(obj, sectionId)
            index = obj.indexOf(sectionId);
            value = obj.Sections{index};
        end

        function value = defaultSection(obj, problemId)
            if ~ischar(problemId) || isempty(regexp(problemId, ...
                    '^[a-z][a-z0-9_]*$', 'once')) || ...
                    ~isfield(obj.DefaultSectionByProblem, problemId)
                error('lmz:Poincare:DefaultSection', ...
                    'No default Poincare section exists for problem %s.', problemId);
            end
            value = obj.section(obj.DefaultSectionByProblem.(problemId));
        end

        function value = symmetryFor(obj, sectionId)
            descriptor = obj.descriptor(sectionId);
            className = descriptor.SymmetryClass;
            parameters = descriptor.SymmetryParameters;
            if strcmp(className, 'lmz.poincare.IdentitySymmetry')
                id = localField(parameters, 'id', 'identity');
                value = lmz.poincare.IdentitySymmetry(id);
            elseif strcmp(className, ...
                    'lmz.poincare.PlanarTranslationSymmetry')
                id = localField(parameters, 'id', 'planar_translation');
                names = localField(parameters, 'positionStateNames', {'x'});
                value = lmz.poincare.PlanarTranslationSymmetry(id, names);
            else
                obj.assertTrustedClass(className);
                constructor = str2func(className);
                value = constructor(localField(parameters, 'id', ...
                    'custom_symmetry'), parameters, obj.StateSchema);
                if ~isa(value, 'lmz.poincare.StateSymmetry')
                    error('lmz:Poincare:SymmetryImplementation', ...
                        '%s does not implement StateSymmetry.', className);
                end
            end
            if ~isempty(obj.StateSchema) && ...
                    isa(value, 'lmz.poincare.PlanarTranslationSymmetry')
                for index = 1:numel(value.PositionStateNames)
                    obj.StateSchema.indexOf(value.PositionStateNames{index});
                end
            end
        end

        function value = toStruct(obj)
            sections = cell(1, numel(obj.Descriptors));
            for index = 1:numel(sections)
                sections{index} = obj.Descriptors{index}.toStruct();
            end
            value = struct('schemaVersion', obj.SchemaVersion, ...
                'defaultSectionByProblem', obj.DefaultSectionByProblem, ...
                'sections', {sections});
        end

        function value = fingerprint(obj)
            value = obj.CatalogHash;
        end
    end

    methods (Access = private)
        function index = indexOf(obj, sectionId)
            if isstring(sectionId) && isscalar(sectionId)
                sectionId = char(sectionId);
            end
            ids = obj.listSections();
            index = find(strcmp(sectionId, ids), 1);
            if isempty(index)
                error('lmz:Poincare:UnknownSection', ...
                    'Unknown Poincare section: %s', sectionId);
            end
        end

        function value = instantiate(obj, descriptor)
            if ~isempty(descriptor.ImplementationClass)
                obj.assertTrustedClass(descriptor.ImplementationClass);
                constructor = str2func(descriptor.ImplementationClass);
                value = constructor(descriptor, obj.StateSchema);
                if ~isa(value, 'lmz.poincare.PoincareSection')
                    error('lmz:Poincare:SectionImplementation', ...
                        '%s does not implement PoincareSection.', ...
                        descriptor.ImplementationClass);
                end
                return
            end
            switch descriptor.Kind
                case 'named_event'
                    value = lmz.poincare.NamedEventSection(descriptor);
                case 'state_plane'
                    if isempty(obj.StateSchema)
                        error('lmz:Poincare:StateSchema', ...
                            ['A state schema is required to construct ' ...
                            'declarative state-plane sections.']);
                    end
                    value = lmz.poincare.StateFunctionSection( ...
                        descriptor, obj.StateSchema);
                otherwise
                    error('lmz:Poincare:SectionImplementation', ...
                        'Section kind %s requires an implementation.', ...
                        descriptor.Kind);
            end
        end

        function assertTrustedClass(obj, className)
            frameworkPrefix = 'lmz.poincare.';
            if strncmp(className, frameworkPrefix, numel(frameworkPrefix))
                root = lmz.util.ProjectPaths.src();
            else
                if isempty(obj.TrustedCodeRoot) || ...
                        isempty(obj.TrustedNamespace)
                    error('lmz:Poincare:UntrustedClass', ...
                        'Custom Poincare classes require a trusted code root.');
                end
                prefix = [obj.TrustedNamespace '.'];
                if ~strncmp(className, prefix, numel(prefix))
                    error('lmz:Poincare:UntrustedClass', ...
                        'Poincare class is outside its trusted namespace.');
                end
                root = obj.TrustedCodeRoot;
            end
            matches = which(className, '-all');
            if isempty(matches)
                error('lmz:Poincare:MissingClass', ...
                    'Poincare class is unavailable: %s', className);
            end
            if ischar(matches)
                matches = {matches};
            end
            canonical = cell(size(matches));
            for index = 1:numel(matches)
                canonical{index} = lmz.util.PathGuard.canonical(matches{index}, true);
            end
            canonical = unique(canonical);
            if numel(canonical) ~= 1
                error('lmz:Poincare:AmbiguousClass', ...
                    'Poincare class is shadowed: %s', className);
            end
            if ~lmz.util.PathGuard.isWithin(root, canonical{1})
                error('lmz:Poincare:ClassOutsideRoot', ...
                    'Poincare class resolves outside its trusted root.');
            end
        end
    end
end

function values = localStructList(value, description)
if iscell(value) && all(cellfun(@(x) isstruct(x) && isscalar(x), value))
    values = reshape(value, 1, []);
elseif isstruct(value)
    values = cell(1, numel(value));
    for index = 1:numel(value)
        values{index} = value(index);
    end
else
    error('lmz:Poincare:CatalogList', ...
        '%s must be a list of objects.', description);
end
end

function localRequireCatalogFields(value)
required = {'id','label','kind','stateSide','minimumReturnTime', ...
    'requiredEventSequence','returnOccurrence','coordinateNames', ...
    'symmetryClass','maturities','validationStatus'};
if ~all(isfield(value, required)) || ...
        ~(isfield(value, 'crossingDirection') || isfield(value, 'direction'))
    error('lmz:Poincare:CatalogSectionFields', ...
        'Poincare catalog section is missing required metadata.');
end
end

function value = localDefaults(source, ids)
if ~isstruct(source) || ~isscalar(source) || isempty(fieldnames(source))
    error('lmz:Poincare:CatalogDefaults', ...
        'defaultSectionByProblem must be a nonempty object.');
end
names = fieldnames(source);
value = struct();
for index = 1:numel(names)
    problemId = names{index};
    sectionId = source.(problemId);
    if isempty(regexp(problemId, '^[a-z][a-z0-9_]*$', 'once')) || ...
            ~ischar(sectionId) || ~any(strcmp(sectionId, ids))
        error('lmz:Poincare:CatalogDefaults', ...
            'Poincare default section mapping is invalid.');
    end
    value.(problemId) = sectionId;
end
end

function value = localField(source, name, fallback)
if isfield(source, name), value = source.(name); else, value = fallback; end
end

function conditions = localCompositeConditions(parameters, stateSchema)
if ~isfield(parameters, 'conditions')
    error('lmz:Poincare:CompositeConditions', ...
        'A declarative composite section requires conditions.');
end
items = localStructList(parameters.conditions, 'composite conditions');
if isempty(items)
    error('lmz:Poincare:CompositeConditions', ...
        'A declarative composite section requires at least one condition.');
end
conditions = cell(1, numel(items));
for index = 1:numel(items)
    conditions{index} = lmz.poincare.CompositeAcceptanceCondition( ...
        items{index}, stateSchema);
end
end

function value = localDigest(text)
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(text, 'UTF-8'));
bytes = typecast(digest.digest(), 'uint8');
value = lower(reshape(dec2hex(bytes, 2).', 1, []));
end
