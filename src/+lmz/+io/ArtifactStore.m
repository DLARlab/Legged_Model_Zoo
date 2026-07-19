classdef ArtifactStore
    %ARTIFACTSTORE Versioned plain-struct MAT artifact persistence.
    properties (Constant, Access=private)
        CurrentSchemaVersion = '1.0.0'
        SupportedTypes = {'solution', 'branch', 'simulation', ...
            'optimization-run', 'checkpoint'}
    end

    methods (Static)
        function save(path, artifact)
            lmz.io.ArtifactStore.validate(artifact);
            folder = fileparts(path);
            if isempty(folder)
                folder = pwd;
            end
            if exist(folder, 'dir') ~= 7
                error('lmz:Artifact:MissingDirectory', ...
                    'Artifact directory does not exist: %s', folder);
            end

            temporaryPath = [tempname(folder) '.mat'];
            cleanup = onCleanup(@() ...
                lmz.io.ArtifactStore.removeTemporary(temporaryPath));
            save(temporaryPath, 'artifact');

            check = load(temporaryPath, 'artifact');
            lmz.io.ArtifactStore.validate(check.artifact);
            [ok, message] = movefile(temporaryPath, path, 'f');
            if ~ok
                error('lmz:Artifact:WriteFailed', '%s', message);
            end
            clear cleanup
        end

        function artifact = load(path)
            if exist(path, 'file') ~= 2
                error('lmz:Artifact:MissingFile', ...
                    'Artifact does not exist: %s', path);
            end
            loaded = load(path);
            names = fieldnames(loaded);
            if ~isequal(names, {'artifact'})
                error('lmz:Artifact:TopLevelContract', ...
                    'MAT file must contain only the top-level artifact struct.');
            end
            artifact = lmz.io.ArtifactStore.dispatch(loaded.artifact);
            lmz.io.ArtifactStore.validate(artifact);
        end

        function validate(artifact)
            if ~isstruct(artifact) || ~isscalar(artifact)
                error('lmz:Artifact:InvalidType', ...
                    'Artifact must be a scalar plain struct.');
            end
            required = {'schemaVersion', 'artifactType', 'modelId', ...
                'modelVersion', 'problemId', 'problemVersion', ...
                'decisionSchema', 'parameterSchema', 'decisionValues', ...
                'parameterValues', 'diagnostics', 'lineage', 'randomSeed', ...
                'sourceCommitSHAs', 'createdAt', 'matlabVersion', 'codeVersion'};
            lmz.io.ArtifactStore.requireFields(artifact, required);

            if ~strcmp(artifact.schemaVersion, ...
                    lmz.io.ArtifactStore.CurrentSchemaVersion)
                error('lmz:Artifact:UnsupportedVersion', ...
                    'Unsupported artifact schema version: %s', ...
                    artifact.schemaVersion);
            end
            if ~any(strcmp(artifact.artifactType, ...
                    lmz.io.ArtifactStore.SupportedTypes))
                error('lmz:Artifact:UnsupportedType', ...
                    'Unsupported artifact type: %s', artifact.artifactType);
            end
            identityFields = {'modelId', 'modelVersion', 'problemId', ...
                'problemVersion', 'createdAt', 'matlabVersion', 'codeVersion'};
            for index = 1:numel(identityFields)
                value = artifact.(identityFields{index});
                if ~ischar(value) || isempty(value)
                    error('lmz:Artifact:InvalidIdentity', ...
                        '%s must be nonempty text.', identityFields{index});
                end
            end
            canonicalModelId = lmz.registry.ModelRegistry.canonicalModelId( ...
                artifact.modelId);
            if ~strcmp(canonicalModelId, artifact.modelId)
                error('lmz:Artifact:DeprecatedModelId', ...
                    'New artifacts must use canonical model ID %s.', ...
                    canonicalModelId);
            end

            decisionCount = lmz.io.ArtifactStore.validateStoredSchema( ...
                artifact.decisionSchema, 'decisionSchema');
            parameterCount = lmz.io.ArtifactStore.validateStoredSchema( ...
                artifact.parameterSchema, 'parameterSchema');
            lmz.io.ArtifactStore.validateValues(artifact.decisionValues, ...
                decisionCount, artifact.artifactType, 'decisionValues');
            lmz.io.ArtifactStore.validateValues(artifact.parameterValues, ...
                parameterCount, artifact.artifactType, 'parameterValues');

            if ~(isnumeric(artifact.randomSeed) && ...
                    isscalar(artifact.randomSeed) && ...
                    isfinite(artifact.randomSeed) && artifact.randomSeed >= 0)
                error('lmz:Artifact:InvalidRandomSeed', ...
                    'randomSeed must be a finite nonnegative scalar.');
            end
            if ~isstruct(artifact.diagnostics) || ...
                    ~isstruct(artifact.lineage) || ...
                    ~isstruct(artifact.sourceCommitSHAs)
                error('lmz:Artifact:InvalidMetadata', ...
                    'Diagnostics, lineage, and source commits must be structs.');
            end
            if strcmp(artifact.artifactType, 'checkpoint')
                lmz.io.ArtifactStore.requireFields(artifact, ...
                    {'checkpointState', 'algorithmOptions', 'terminationReason'});
            end
        end
    end

    methods (Static, Access=private)
        function artifact = dispatch(artifact)
            if ~isstruct(artifact) || ~isfield(artifact, 'schemaVersion')
                error('lmz:Artifact:MissingVersion', ...
                    'Artifact schemaVersion is required for dispatch.');
            end
            if strcmp(artifact.schemaVersion, ...
                    lmz.io.ArtifactStore.CurrentSchemaVersion)
                if isfield(artifact, 'modelId')
                    canonical = lmz.registry.ModelRegistry.canonicalModelId( ...
                        artifact.modelId);
                    artifact.modelId = canonical;
                end
                return
            end
            error('lmz:Artifact:UnsupportedVersion', ...
                'No loader is registered for schema version %s.', ...
                artifact.schemaVersion);
        end

        function count = validateStoredSchema(schema, fieldName)
            if ~isstruct(schema) || ~isscalar(schema)
                error('lmz:Artifact:InvalidSchema', ...
                    '%s must be a scalar struct.', fieldName);
            end
            required = {'version', 'orderedNames', 'variables'};
            for index = 1:numel(required)
                if ~isfield(schema, required{index})
                    error('lmz:Artifact:InvalidSchema', ...
                        '%s is missing %s.', fieldName, required{index});
                end
            end
            names = schema.orderedNames;
            if ~iscell(names) || ~all(cellfun(@ischar, names)) || ...
                    numel(unique(names)) ~= numel(names)
                error('lmz:Artifact:InvalidSchemaNames', ...
                    '%s orderedNames must be unique text names.', fieldName);
            end
            count = numel(names);
            if numel(schema.variables) ~= count
                error('lmz:Artifact:SchemaDimensionMismatch', ...
                    '%s variable metadata does not match orderedNames.', fieldName);
            end
            for index = 1:count
                if iscell(schema.variables)
                    variable = schema.variables{index};
                else
                    variable = schema.variables(index);
                end
                needed = {'Name', 'Unit', 'Topology', 'Scale'};
                for fieldIndex = 1:numel(needed)
                    if ~isfield(variable, needed{fieldIndex})
                        error('lmz:Artifact:InvalidVariableMetadata', ...
                            '%s variable %d is missing %s.', fieldName, ...
                            index, needed{fieldIndex});
                    end
                end
                if ~strcmp(variable.Name, names{index}) || ...
                        ~isfinite(variable.Scale) || variable.Scale <= 0
                    error('lmz:Artifact:InvalidVariableMetadata', ...
                        '%s variable order or scale is invalid.', fieldName);
                end
            end
        end

        function validateValues(values, expectedRows, artifactType, fieldName)
            if ~isnumeric(values) || ~isreal(values) || ...
                    any(~isfinite(values(:)))
                error('lmz:Artifact:NonfiniteValues', ...
                    '%s must contain finite real numeric values.', fieldName);
            end
            if isvector(values) && expectedRows == numel(values)
                actualRows = numel(values);
            else
                actualRows = size(values, 1);
            end
            if actualRows ~= expectedRows
                error('lmz:Artifact:ValueDimensionMismatch', ...
                    '%s has %d rows; expected %d.', ...
                    fieldName, actualRows, expectedRows);
            end
            if strcmp(artifactType, 'solution') && ...
                    expectedRows > 0 && size(values, 2) ~= 1
                error('lmz:Artifact:SolutionCardinality', ...
                    '%s for a solution must contain one column.', fieldName);
            end
        end

        function requireFields(value, fields)
            for index = 1:numel(fields)
                if ~isfield(value, fields{index})
                    error('lmz:Artifact:MissingField', ...
                        'Missing artifact field %s.', fields{index});
                end
            end
        end

        function removeTemporary(path)
            if exist(path, 'file') == 2
                delete(path);
            end
        end
    end
end
