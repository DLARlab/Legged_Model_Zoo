classdef DataSourceDescriptor
    %DATASOURCEDESCRIPTOR Inert registration record for model-owned data.
    properties (SetAccess = private)
        SchemaVersion
        Id
        Label
        ModelId
        ProblemId
        Kind
        ProviderClass
        DefaultDatasetId
        Metadata
        SourcePath
        SourceHash
    end
    properties (SetAccess = private, Transient)
        Registry = []
    end
    methods
        function obj = DataSourceDescriptor(value, varargin)
            parser = inputParser;
            addRequired(parser, 'value', @(x) isstruct(x) && isscalar(x));
            addParameter(parser, 'Registry', []);
            addParameter(parser, 'SourcePath', '', @ischar);
            addParameter(parser, 'SourceHash', '', @ischar);
            parse(parser, value, varargin{:});
            required = {'schemaVersion','id','label','modelId','problemId', ...
                'kind','providerClass'};
            requireFields(value, required, 'data-source descriptor');
            if ~strcmp(value.schemaVersion, '1.0.0')
                error('lmz:Workflow:DataSourceSchema', ...
                    'Unsupported data-source schema version.');
            end
            validateId(value.id, 'data-source');
            validateId(value.modelId, 'model');
            validateId(value.problemId, 'problem');
            kinds = {'branch_catalog','single_branch','scientific_dataset', ...
                'native_artifact','legacy_mat','generated_tutorial'};
            if ~ischar(value.kind) || ~any(strcmp(value.kind, kinds))
                error('lmz:Workflow:DataSourceKind', ...
                    'Unsupported data-source kind.');
            end
            if ~ischar(value.providerClass) || isempty(regexp( ...
                    value.providerClass, '^[A-Za-z][A-Za-z0-9_.]*$', 'once'))
                error('lmz:Workflow:ProviderClass', ...
                    'Data-source providerClass is invalid.');
            end
            if ~ischar(value.label) || isempty(strtrim(value.label))
                error('lmz:Workflow:DataSourceLabel', ...
                    'Data-source label must be nonempty text.');
            end
            obj.SchemaVersion = value.schemaVersion;
            obj.Id = value.id;
            obj.Label = value.label;
            obj.ModelId = value.modelId;
            obj.ProblemId = value.problemId;
            obj.Kind = value.kind;
            obj.ProviderClass = value.providerClass;
            obj.DefaultDatasetId = fieldOr(value, 'defaultDatasetId', '');
            obj.Metadata = fieldOr(value, 'metadata', struct());
            if ~ischar(obj.DefaultDatasetId) || ~isstruct(obj.Metadata) || ...
                    ~isscalar(obj.Metadata)
                error('lmz:Workflow:DataSourceMetadata', ...
                    'Data-source defaults and metadata are invalid.');
            end
            obj.Registry = parser.Results.Registry;
            obj.SourcePath = parser.Results.SourcePath;
            obj.SourceHash = parser.Results.SourceHash;
        end

        function provider = createProvider(obj)
            if isempty(obj.Registry) || ...
                    ~isa(obj.Registry, 'lmz.registry.ModelRegistry')
                error('lmz:Workflow:UnboundDataSource', ...
                    'The data source is not bound to a model registry.');
            end
            provider = obj.Registry.createProvider(obj.ModelId, ...
                obj.ProviderClass, 'lmz.workflow.DataSourceProvider');
        end

        function value = toStruct(obj)
            value = struct('schemaVersion',obj.SchemaVersion,'id',obj.Id, ...
                'label',obj.Label,'modelId',obj.ModelId, ...
                'problemId',obj.ProblemId,'kind',obj.Kind, ...
                'providerClass',obj.ProviderClass, ...
                'defaultDatasetId',obj.DefaultDatasetId, ...
                'metadata',obj.Metadata,'sourcePath',obj.SourcePath, ...
                'sourceHash',obj.SourceHash);
        end
    end
end

function requireFields(value, names, description)
for index = 1:numel(names)
    if ~isfield(value, names{index})
        error('lmz:Workflow:MissingField', ...
            'Missing %s field %s.', description, names{index});
    end
end
end

function validateId(value, description)
if ~ischar(value) || isempty(regexp(value, '^[a-z][a-z0-9_]*$', 'once'))
    error('lmz:Workflow:InvalidId', ...
        '%s ID must be a lowercase identifier.', description);
end
end

function value = fieldOr(source, name, fallback)
if isfield(source, name), value = source.(name); else, value = fallback; end
end
