classdef ArtifactStore
    %ARTIFACTSTORE Versioned plain-struct MAT artifact persistence.
    properties (Constant, Access=private)
        SupportedTypes = {'solution', 'branch', 'simulation', 'solve-run', ...
            'continuation-run', 'optimization-run', 'checkpoint', ...
            'branch-family-report', 'contact-timing-run', ...
            'section-transfer-run', 'stride-plan', ...
            'stride-plan-completion-run', 'n-stride-simulation-run', ...
            'n-stride-periodic-run'}
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

            temporaryPath = lmz.compat.Files.temporary(folder, '.mat');
            cleanup = onCleanup(@() ...
                lmz.io.ArtifactStore.removeTemporary(temporaryPath));
            save(temporaryPath, 'artifact');

            check = lmz.io.SafeMat.loadVariables(temporaryPath, {'artifact'}, ...
                'ExactVariables', true);
            lmz.io.ArtifactStore.validate(check.artifact);
            lmz.compat.Files.atomicMove(temporaryPath, path);
            clear cleanup
        end

        function artifact = load(path)
            if exist(path, 'file') ~= 2
                error('lmz:Artifact:MissingFile', ...
                    'Artifact does not exist: %s', path);
            end
            loaded = lmz.io.SafeMat.loadVariables(path, {'artifact'}, ...
                'ExactVariables', true);
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
                    lmz.util.Version.artifactSchemaVersion())
                error('lmz:Artifact:UnsupportedVersion', ...
                    'Unsupported artifact schema version: %s', ...
                    artifact.schemaVersion);
            end
            versionFields = {'artifactSchemaVersion', 'frameworkVersion', ...
                'minimumMatlabRelease'};
            present = cellfun(@(name)isfield(artifact,name), versionFields);
            if any(present) && ~all(present)
                error('lmz:Artifact:IncompleteVersionMetadata', ...
                    'New artifact version metadata must be recorded together.');
            end
            if all(present)
                if ~ischar(artifact.artifactSchemaVersion) || ...
                        ~strcmp(artifact.artifactSchemaVersion,artifact.schemaVersion)
                    error('lmz:Artifact:SchemaVersionMismatch', ...
                        'artifactSchemaVersion must match schemaVersion.');
                end
                lmz.util.Version.parse(artifact.frameworkVersion);
                if ~ischar(artifact.minimumMatlabRelease) || ...
                        isempty(regexp(artifact.minimumMatlabRelease, ...
                        '^R[0-9]{4}[ab]$', 'once'))
                    error('lmz:Artifact:InvalidMinimumMatlabRelease', ...
                        'minimumMatlabRelease must have the form RYYYYa or RYYYYb.');
                end
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
            hasMaturity=isfield(artifact,'problemMaturity');
            hasValidation=isfield(artifact,'validationStatus');
            if hasMaturity||hasValidation
                if ~(hasMaturity&&hasValidation)
                    error('lmz:Artifact:IncompleteProblemMetadata', ...
                        ['Problem maturity and validation status must be ' ...
                        'recorded together.']);
                end
                maturities={'tutorial','compatibility','validated','experimental'};
                statuses={'untested','tested','source-equivalent'};
                if ~ischar(artifact.problemMaturity)|| ...
                        ~any(strcmp(artifact.problemMaturity,maturities))
                    error('lmz:Artifact:InvalidProblemMaturity', ...
                        'Artifact problem maturity is invalid.');
                end
                if ~ischar(artifact.validationStatus)|| ...
                        ~any(strcmp(artifact.validationStatus,statuses))
                    error('lmz:Artifact:InvalidValidationStatus', ...
                        'Artifact validation status is invalid.');
                end
                if isfield(artifact,'problemMetadata')
                    metadata=artifact.problemMetadata;
                    if ~isstruct(metadata)||~isscalar(metadata)|| ...
                            ~isfield(metadata,'maturity')|| ...
                            ~isfield(metadata,'validationStatus')|| ...
                            ~strcmp(metadata.maturity,artifact.problemMaturity)|| ...
                            ~strcmp(metadata.validationStatus,artifact.validationStatus)
                        error('lmz:Artifact:ProblemMetadataMismatch', ...
                            'Artifact problem metadata is inconsistent.');
                    end
                end
            end
            if strcmp(artifact.artifactType, 'checkpoint')
                lmz.io.ArtifactStore.requireFields(artifact, ...
                    {'checkpointState', 'algorithmOptions', 'terminationReason'});
            end
            recordedRunTypes={'solve-run','continuation-run', ...
                'optimization-run','checkpoint','contact-timing-run', ...
                'section-transfer-run','stride-plan-completion-run', ...
                'n-stride-simulation-run','n-stride-periodic-run'};
            if any(strcmp(artifact.artifactType,recordedRunTypes))
                runFields={'options','sourceSeed','sourcePair', ...
                    'sourceArtifactId','runProvenance','matlabRelease', ...
                    'toolboxes','elapsedTime','functionEvaluations', ...
                    'terminationReason','warnings','sourceDataHashes'};
                lmz.io.ArtifactStore.requireFields(artifact,runFields);
                if ~isstruct(artifact.options)||~isscalar(artifact.options)|| ...
                        ~isstruct(artifact.sourcePair)|| ...
                        ~isstruct(artifact.runProvenance)|| ...
                        ~isstruct(artifact.toolboxes)|| ...
                        ~isstruct(artifact.sourceDataHashes)|| ...
                        ~ischar(artifact.sourceArtifactId)|| ...
                        ~ischar(artifact.matlabRelease)|| ...
                        ~ischar(artifact.terminationReason)|| ...
                        isempty(artifact.terminationReason)|| ...
                        ~iscell(artifact.warnings)
                    error('lmz:Artifact:InvalidRunMetadata', ...
                        'Run reproducibility metadata is malformed.');
                end
                numericFields={'elapsedTime','functionEvaluations'};
                for numericIndex=1:numel(numericFields)
                    item=artifact.(numericFields{numericIndex});
                    if ~isnumeric(item)||~isscalar(item)|| ...
                            ~(isnan(item)||(isfinite(item)&&item>=0))
                        error('lmz:Artifact:InvalidRunMetadata', ...
                            '%s must be nonnegative or explicitly unavailable.', ...
                            numericFields{numericIndex});
                    end
                end
            end
            lmz.io.ArtifactStore.validateWorkflowPayload(artifact);
        end

        function artifact=withRunMetadata(artifact,details)
            %WITHRUNMETADATA Normalize reproducibility fields for run records.
            defaults=struct('Options',struct(),'SourceSeed',[], ...
                'SourcePair',struct(),'RandomSeed',0,'Provenance',struct(), ...
                'ElapsedTime',NaN,'FunctionEvaluations',NaN, ...
                'TerminationReason','','Warnings',{{}}, ...
                'SourceDataHashes',struct(),'SourceCommitSHAs',struct());
            names=fieldnames(details);
            for index=1:numel(names),defaults.(names{index})=details.(names{index});end
            artifact.randomSeed=defaults.RandomSeed;
            artifact.options=defaults.Options;
            artifact.sourceSeed=defaults.SourceSeed;
            artifact.sourcePair=defaults.SourcePair;
            artifact.sourceArtifactId=lmz.io.ArtifactStore.sourceId( ...
                defaults.SourceSeed,defaults.SourcePair);
            artifact.runProvenance=defaults.Provenance;
            artifact.matlabRelease=version('-release');
            artifact.toolboxes=lmz.io.ArtifactStore.toolboxSnapshot();
            artifact.elapsedTime=defaults.ElapsedTime;
            artifact.functionEvaluations=defaults.FunctionEvaluations;
            artifact.terminationReason=defaults.TerminationReason;
            artifact.warnings=defaults.Warnings;
            sources={defaults.SourceSeed,defaults.SourcePair, ...
                defaults.Provenance,artifact.diagnostics,artifact.lineage};
            dataHashes=struct();commits=struct();
            if isfield(artifact,'sourceDataHashes'),dataHashes=artifact.sourceDataHashes;end
            if isfield(artifact,'sourceCommitSHAs'),commits=artifact.sourceCommitSHAs;end
            for sourceIndex=1:numel(sources)
                dataHashes=lmz.io.ArtifactStore.collectMetadata( ...
                    sources{sourceIndex},'hash',['source' num2str(sourceIndex)],dataHashes);
                dataHashes=lmz.io.ArtifactStore.collectPathHashes( ...
                    sources{sourceIndex},['source' num2str(sourceIndex)],dataHashes);
                commits=lmz.io.ArtifactStore.collectMetadata( ...
                    sources{sourceIndex},'commit',['source' num2str(sourceIndex)],commits);
            end
            artifact.sourceDataHashes=lmz.io.ArtifactStore.mergeStructs( ...
                dataHashes,defaults.SourceDataHashes);
            artifact.sourceCommitSHAs=lmz.io.ArtifactStore.mergeStructs( ...
                commits,defaults.SourceCommitSHAs);
            if isstruct(defaults.Provenance)&&isscalar(defaults.Provenance)&& ...
                    isfield(defaults.Provenance,'problemMetadata')
                metadata=defaults.Provenance.problemMetadata;
                if isstruct(metadata)&&isscalar(metadata)&& ...
                        isfield(metadata,'maturity')&& ...
                        isfield(metadata,'validationStatus')
                    artifact.problemMetadata=metadata;
                    artifact.problemMaturity=metadata.maturity;
                    artifact.validationStatus=metadata.validationStatus;
                end
            end
        end

        function artifact=workflowBase(modelId,problemId)
            %WORKFLOWBASE Construct the common plain-data artifact envelope.
            modelId=char(modelId);problemId=char(problemId);
            registry=lmz.registry.ModelRegistry.discover();
            manifest=registry.getManifest(modelId);
            problemVersion='1.0.0';problemMetadata=struct( ...
                'id',problemId,'maturity','experimental', ...
                'validationStatus','untested','configuration',struct());
            try
                descriptor=registry.getProblemDescriptor(modelId,problemId);
                problemMetadata=descriptor;
                problemMetadata.configuration=struct();
                problem=registry.createModel(modelId).createProblem( ...
                    problemId,struct());
                problemVersion=problem.Version;
            catch
                % A partially completed plan may name an intentionally
                % unavailable problem.  Its identity remains explicit.
            end
            schema=lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec.empty(0,1),'1.0.0').toStruct();
            artifactSchemaVersion=lmz.util.Version.artifactSchemaVersion();
            artifact=struct('schemaVersion',artifactSchemaVersion, ...
                'artifactSchemaVersion',artifactSchemaVersion, ...
                'frameworkVersion',lmz.util.Version.current(), ...
                'minimumMatlabRelease',lmz.util.Version.minimumMatlabRelease(), ...
                'artifactType','stride-plan','modelId',modelId, ...
                'modelVersion',manifest.version,'problemId',problemId, ...
                'problemVersion',problemVersion,'decisionSchema',schema, ...
                'parameterSchema',schema,'decisionValues',zeros(0,1), ...
                'parameterValues',zeros(0,1),'diagnostics',struct(), ...
                'lineage',struct(),'randomSeed',0, ...
                'sourceCommitSHAs',struct(),'sourceDataHashes',struct(), ...
                'createdAt',lmz.compat.Timestamp.current(), ...
                'matlabVersion',version, ...
                'codeVersion',lmz.util.Version.current(), ...
                'problemMaturity',problemMetadata.maturity, ...
                'validationStatus',problemMetadata.validationStatus, ...
                'problemMetadata',problemMetadata);
        end

        function metadata=sectionMetadata(modelId,sectionIds)
            %SECTIONMETADATA Resolve trusted catalog IDs into inert records.
            if ischar(sectionIds),sectionIds={sectionIds};end
            sectionIds=unique(sectionIds(:).','stable');
            registry=lmz.registry.ModelRegistry.discover();
            catalog=registry.getPoincareSectionRegistry(char(modelId));
            records=cell(numel(sectionIds),1);
            for index=1:numel(sectionIds)
                descriptor=catalog.descriptor(char(sectionIds{index}));
                records{index}=struct('SectionId',descriptor.Id, ...
                    'Descriptor',descriptor.toStruct(), ...
                    'DescriptorHash',descriptor.fingerprint());
            end
            relativePath='';root=lmz.util.ProjectPaths.root();
            prefix=[root filesep];
            if strncmp(catalog.CatalogPath,prefix,numel(prefix))
                relativePath=strrep(catalog.CatalogPath(numel(prefix)+1:end), ...
                    filesep,'/');
            end
            metadata=struct('CatalogSchemaVersion',catalog.SchemaVersion, ...
                'CatalogHash',catalog.CatalogHash, ...
                'CatalogRelativePath',relativePath, ...
                'Sections',{records});
        end

        function metadata=strideDefinitionMetadata(modelId,startId,stopId)
            %STRIDEDEFINITIONMETADATA Resolve trusted IDs into inert data.
            registry=lmz.registry.ModelRegistry.discover();
            catalog=registry.getPoincareSectionRegistry(char(modelId));
            start=catalog.section(char(startId));
            stop=catalog.section(char(stopId));
            definition=lmz.poincare.StrideDefinition.fromSections( ...
                start,stop,catalog.symmetryFor(char(stopId)).Id);
            metadata=struct('Record',definition.toStruct(), ...
                'Hash',definition.fingerprint());
        end

        function value=dataHash(data)
            %DATAHASH SHA-256 digest of plain JSON-compatible data.
            lmz.io.ArtifactStore.assertPlainData(data,'hashInput');
            encoded=lmz.compat.Json.encode(data);
            digest=java.security.MessageDigest.getInstance('SHA-256');
            digest.update(unicode2native(encoded,'UTF-8'));
            bytes=typecast(digest.digest(),'uint8');
            value=lower(reshape(dec2hex(bytes,2).',1,[]));
        end
    end

    methods (Static, Access=private)
        function artifact = dispatch(artifact)
            if ~isstruct(artifact) || ~isfield(artifact, 'schemaVersion')
                error('lmz:Artifact:MissingVersion', ...
                    'Artifact schemaVersion is required for dispatch.');
            end
            if strcmp(artifact.schemaVersion, ...
                    lmz.util.Version.artifactSchemaVersion())
                if isfield(artifact, 'modelId')
                    canonical = lmz.registry.ModelRegistry.canonicalModelId( ...
                        artifact.modelId);
                    artifact.modelId = canonical;
                end
                artifact=lmz.io.ArtifactStore.applyActivityMigration(artifact);
                artifact=lmz.io.ArtifactStore.applyWorkflowMigration(artifact);
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

        function artifact=applyActivityMigration(artifact)
            if ~isfield(artifact,'modelId')|| ...
                    ~strcmp(artifact.modelId,'slip_quadruped')
                return
            end
            if isfield(artifact,'parameterSchema')
                artifact.parameterSchema= ...
                    lmz.io.ArtifactStore.markQuadrupedActivities( ...
                    artifact.parameterSchema);
            end
            if isfield(artifact,'solution')&& ...
                    isfield(artifact.solution,'ParameterSchema')
                artifact.solution.ParameterSchema= ...
                    lmz.io.ArtifactStore.markQuadrupedActivities( ...
                    artifact.solution.ParameterSchema);
            end
            if isfield(artifact,'branch')&& ...
                    isfield(artifact.branch,'ParameterSchema')
                artifact.branch.ParameterSchema= ...
                    lmz.io.ArtifactStore.markQuadrupedActivities( ...
                    artifact.branch.ParameterSchema);
            end
        end

        function artifact=applyWorkflowMigration(artifact)
            types={'section-transfer-run','n-stride-periodic-run'};
            if ~isfield(artifact,'artifactType')|| ...
                    ~any(strcmp(artifact.artifactType,types))
                return
            end
            if ~isfield(artifact,'strideDefinition')|| ...
                    ~isfield(artifact,'strideDefinitionHash')
                definition=lmz.io.ArtifactStore.legacyStrideDefinition(artifact);
                artifact.strideDefinition=definition.toStruct();
                artifact.strideDefinitionHash=definition.fingerprint();
            end
            if strcmp(artifact.artifactType,'n-stride-periodic-run')
                if isfield(artifact,'stridePlan')&& ...
                        isfield(artifact,'problemMetadata')&& ...
                        isstruct(artifact.problemMetadata)&& ...
                        isfield(artifact.problemMetadata,'configuration')&& ...
                        isstruct(artifact.problemMetadata.configuration)&& ...
                        ~isfield(artifact.problemMetadata.configuration, ...
                        'StridePlan')
                    artifact.problemMetadata.configuration.StridePlan= ...
                        artifact.stridePlan;
                end
                if ~isfield(artifact,'stridePlanHash')&& ...
                        isfield(artifact,'stridePlan')
                    artifact.stridePlanHash= ...
                        lmz.io.ArtifactStore.dataHash(artifact.stridePlan);
                end
                if ~isfield(artifact,'problemConfigurationHash')&& ...
                        isfield(artifact,'problemMetadata')&& ...
                        isfield(artifact.problemMetadata,'configuration')
                    artifact.problemConfigurationHash= ...
                        lmz.io.ArtifactStore.dataHash( ...
                        artifact.problemMetadata.configuration);
                end
            end
        end

        function definition=legacyStrideDefinition(artifact)
            metadata=artifact.poincareMetadata;
            sections=metadata.Sections;
            if isstruct(sections),sections=num2cell(sections);end
            startId='';stopId='';
            if strcmp(artifact.artifactType,'section-transfer-run')
                lineage=artifact.lineage;
                if isfield(lineage,'SourceSectionId')
                    startId=lineage.SourceSectionId;
                end
                if isfield(lineage,'TargetSectionId')
                    stopId=lineage.TargetSectionId;
                elseif isfield(artifact,'targetSectionId')
                    stopId=artifact.targetSectionId;
                end
            elseif isfield(artifact,'stridePlan')&& ...
                    isfield(artifact.stridePlan,'StrideSpecs')&& ...
                    ~isempty(artifact.stridePlan.StrideSpecs)
                specs=artifact.stridePlan.StrideSpecs;
                if iscell(specs)
                    first=specs{1};last=specs{end};
                else
                    first=specs(1);last=specs(end);
                end
                startId=first.StartSectionId;stopId=last.StopSectionId;
            end
            if isempty(startId)&&~isempty(sections)
                startId=sections{1}.SectionId;
            end
            if isempty(stopId)&&~isempty(sections)
                stopId=sections{end}.SectionId;
            end
            start=lmz.io.ArtifactStore.sectionRecord(sections,startId);
            stop=lmz.io.ArtifactStore.sectionRecord(sections,stopId);
            if isempty(start)||isempty(stop)
                error('lmz:Artifact:StrideDefinitionMigration', ...
                    'Legacy artifact cannot resolve stride-definition endpoints.');
            end
            startDescriptor=start.Descriptor;
            stopDescriptor=stop.Descriptor;
            symmetryId='identity';
            if isfield(stopDescriptor,'symmetryParameters')&& ...
                    isstruct(stopDescriptor.symmetryParameters)&& ...
                    isfield(stopDescriptor.symmetryParameters,'id')
                symmetryId=stopDescriptor.symmetryParameters.id;
            end
            value=struct('StartSectionId',startId, ...
                'StartStateSide',lmz.io.ArtifactStore.storedField( ...
                startDescriptor,'stateSide','post'), ...
                'StopSectionId',stopId, ...
                'StopStateSide',lmz.io.ArtifactStore.storedField( ...
                stopDescriptor,'stateSide','post'), ...
                'CrossingDirection',lmz.io.ArtifactStore.storedField( ...
                stopDescriptor,'crossingDirection',0), ...
                'MinimumReturnTime',lmz.io.ArtifactStore.storedField( ...
                stopDescriptor,'minimumReturnTime',0), ...
                'RequiredEventSequence',{lmz.io.ArtifactStore.storedField( ...
                stopDescriptor,'requiredEventSequence',{})}, ...
                'ReturnOccurrence',lmz.io.ArtifactStore.storedField( ...
                stopDescriptor,'returnOccurrence',1), ...
                'SymmetryId',symmetryId, ...
                'StartSectionHash',start.DescriptorHash, ...
                'StopSectionHash',stop.DescriptorHash);
            definition=lmz.poincare.StrideDefinition(value);
        end

        function value=sectionRecord(sections,sectionId)
            value=[];
            if isstruct(sections),sections=num2cell(sections);end
            for index=1:numel(sections)
                if strcmp(sections{index}.SectionId,sectionId)
                    value=sections{index};return
                end
            end
        end

        function value=storedField(source,name,fallback)
            if isstruct(source)&&isfield(source,name)
                value=source.(name);
            else
                value=fallback;
            end
        end

        function schema=markQuadrupedActivities(schema)
            if ~isstruct(schema)||~isfield(schema,'variables')
                return
            end
            for index=1:numel(schema.variables)
                if iscell(schema.variables)
                    variable=schema.variables{index};
                else
                    variable=schema.variables(index);
                end
                activity='active';
                if isfield(variable,'Name')&&strcmp(variable.Name,'phi_neutral')
                    activity='inactive';
                end
                variable.Activity=activity;
                if iscell(schema.variables)
                    schema.variables{index}=variable;
                else
                    schema.variables(index)=variable;
                end
            end
        end


        function value=sourceId(seed,pair)
            value='';
            if isstruct(seed)&&isscalar(seed)
                if isfield(seed,'Id'),value=seed.Id;elseif isfield(seed,'id'),value=seed.id;end
            end
            if isempty(value)&&isstruct(pair)&&isscalar(pair)
                if isfield(pair,'First')&&isstruct(pair.First)&&isfield(pair.First,'Id')
                    second='';if isfield(pair,'Second')&&isstruct(pair.Second)&&isfield(pair.Second,'Id'),second=pair.Second.Id;end
                    value=[pair.First.Id ':' second];
                end
            end
        end

        function values=toolboxSnapshot()
            installed=ver;values=repmat(struct('Name','','Version','','Release',''),numel(installed),1);
            for index=1:numel(installed)
                values(index).Name=installed(index).Name;
                values(index).Version=installed(index).Version;
                if isfield(installed,'Release'),values(index).Release=installed(index).Release;end
            end
        end

        function output=collectMetadata(value,kind,prefix,output)
            if iscell(value)
                for index=1:numel(value)
                    output=lmz.io.ArtifactStore.collectMetadata(value{index}, ...
                        kind,[prefix '_' num2str(index)],output);
                end
                return
            end
            if ~isstruct(value),return,end
            for valueIndex=1:numel(value)
                names=fieldnames(value(valueIndex));
                for index=1:numel(names)
                    name=names{index};item=value(valueIndex).(name);
                    key=sprintf('%s_%s',prefix,name);
                    if numel(value)>1,key=sprintf('%s_%d',key,valueIndex);end
                    if isstruct(item)||iscell(item)
                        output=lmz.io.ArtifactStore.collectMetadata(item,kind,key,output);
                    elseif (ischar(item)||(isstring(item)&&isscalar(item)))
                        lowerName=lower(name);
                        matches=strcmp(kind,'commit')&&contains(lowerName,'commit');
                        matches=matches||(strcmp(kind,'hash')&& ...
                            (contains(lowerName,'hash')||contains(lowerName,'sha'))&& ...
                            ~contains(lowerName,'commit'));
                        if matches,output.(matlab.lang.makeValidName(key))=char(item);end
                    end
                end
            end
        end

        function output=collectPathHashes(value,prefix,output)
            if iscell(value)
                for index=1:numel(value)
                    output=lmz.io.ArtifactStore.collectPathHashes(value{index}, ...
                        [prefix '_' num2str(index)],output);
                end
                return
            end
            if ~isstruct(value),return,end
            for valueIndex=1:numel(value)
                names=fieldnames(value(valueIndex));
                for index=1:numel(names)
                    name=names{index};item=value(valueIndex).(name);
                    key=sprintf('%s_%s',prefix,name);
                    if numel(value)>1,key=sprintf('%s_%d',key,valueIndex);end
                    if isstruct(item)||iscell(item)
                        output=lmz.io.ArtifactStore.collectPathHashes(item,key,output);
                    elseif contains(lower(name),'path')&& ...
                            (ischar(item)||(isstring(item)&&isscalar(item)))&& ...
                            exist(char(item),'file')==2
                        absolute=lmz.util.PathGuard.canonical(char(item),true);
                        root=lmz.util.PathGuard.canonical( ...
                            lmz.util.ProjectPaths.root(),true);
                        rootPrefix=[root filesep];relative='';
                        if strncmp(absolute,rootPrefix,numel(rootPrefix))
                            relative=strrep(absolute(numel(rootPrefix)+1:end), ...
                                filesep,'/');
                        end
                        output.(matlab.lang.makeValidName([key '_SHA256']))= ...
                            struct('relativePath',relative,'sha256', ...
                            lmz.util.FileHash.sha256(absolute));
                    end
                end
            end
        end

        function output=mergeStructs(first,second)
            output=first;if ~isstruct(output)||~isscalar(output),output=struct();end
            if ~isstruct(second)||~isscalar(second),return,end
            names=fieldnames(second);
            for index=1:numel(names),output.(names{index})=second.(names{index});end
        end

        function validateWorkflowPayload(artifact)
            type=artifact.artifactType;
            switch type
                case 'contact-timing-run'
                    fields={'contactTimingResult','poincareMetadata'};
                case 'section-transfer-run'
                    fields={'sectionTransferResult','targetSectionId', ...
                        'poincareMetadata','strideDefinition', ...
                        'strideDefinitionHash'};
                case 'stride-plan'
                    fields={'stridePlan','poincareMetadata'};
                case {'stride-plan-completion-run','n-stride-simulation-run'}
                    fields={'multiStrideResult','stridePlan','request', ...
                        'poincareMetadata'};
                case 'n-stride-periodic-run'
                    fields={'nStridePeriodicResult','stridePlan', ...
                        'poincareMetadata','strideDefinition', ...
                        'strideDefinitionHash','stridePlanHash', ...
                        'problemConfigurationHash'};
                otherwise
                    return
            end
            lmz.io.ArtifactStore.requireFields(artifact,fields);
            payloadFields=fields;
            for index=1:numel(payloadFields)
                lmz.io.ArtifactStore.assertPlainData( ...
                    artifact.(payloadFields{index}),payloadFields{index});
            end
            metadata=artifact.poincareMetadata;
            required={'CatalogSchemaVersion','CatalogHash', ...
                'CatalogRelativePath','Sections'};
            if ~isstruct(metadata)||~isscalar(metadata)|| ...
                    ~all(isfield(metadata,required))|| ...
                    ~ischar(metadata.CatalogHash)|| ...
                    isempty(regexp(metadata.CatalogHash,'^[0-9a-fA-F]{64}$','once'))
                error('lmz:Artifact:PoincareMetadata', ...
                    'Poincare catalog metadata is incomplete or malformed.');
            end
            sections=metadata.Sections;
            if isstruct(sections),sections=num2cell(sections);end
            if ~iscell(sections)
                error('lmz:Artifact:PoincareMetadata', ...
                    'Poincare section metadata must be a plain record list.');
            end
            for index=1:numel(sections)
                record=sections{index};
                if ~isstruct(record)||~isscalar(record)|| ...
                        ~all(isfield(record,{'SectionId','Descriptor', ...
                        'DescriptorHash'}))||~ischar(record.DescriptorHash)|| ...
                        isempty(regexp(record.DescriptorHash, ...
                        '^[0-9a-fA-F]{64}$','once'))
                    error('lmz:Artifact:PoincareMetadata', ...
                        'Stored section descriptor metadata is malformed.');
                end
                descriptor=lmz.poincare.PoincareSectionDescriptor( ...
                    record.Descriptor);
                if ~strcmp(record.SectionId,descriptor.Id)|| ...
                        ~strcmpi(record.DescriptorHash, ...
                        descriptor.fingerprint())
                    error('lmz:Artifact:PoincareDescriptorHash', ...
                        ['Stored Poincare section descriptor identity or ' ...
                        'hash does not match its payload.']);
                end
            end
            if isfield(artifact,'strideDefinition')
                lmz.io.ArtifactStore.validateStrideDefinition( ...
                    artifact,sections);
            end
            if strcmp(type,'n-stride-periodic-run')
                if ~ischar(artifact.stridePlanHash)|| ...
                        isempty(regexp(artifact.stridePlanHash, ...
                        '^[0-9a-fA-F]{64}$','once'))|| ...
                        ~strcmpi(artifact.stridePlanHash, ...
                        lmz.io.ArtifactStore.dataHash(artifact.stridePlan))
                    error('lmz:Artifact:StridePlanHash', ...
                        'Stored stride-plan hash does not match its payload.');
                end
                if ~isfield(artifact,'problemMetadata')|| ...
                        ~isstruct(artifact.problemMetadata)|| ...
                        ~isscalar(artifact.problemMetadata)|| ...
                        ~isfield(artifact.problemMetadata,'configuration')|| ...
                        ~isstruct(artifact.problemMetadata.configuration)|| ...
                        ~isscalar(artifact.problemMetadata.configuration)
                    error('lmz:Artifact:ProblemConfiguration', ...
                        'Stored periodic problem configuration is malformed.');
                end
                configuration=artifact.problemMetadata.configuration;
                if ~ischar(artifact.problemConfigurationHash)|| ...
                        isempty(regexp(artifact.problemConfigurationHash, ...
                        '^[0-9a-fA-F]{64}$','once'))|| ...
                        ~strcmpi(artifact.problemConfigurationHash, ...
                        lmz.io.ArtifactStore.dataHash(configuration))
                    error('lmz:Artifact:ProblemConfigurationHash', ...
                        ['Stored problem-configuration hash does not match ' ...
                        'its payload.']);
                end
                if ~isfield(configuration,'StridePlan')|| ...
                        ~strcmpi(lmz.io.ArtifactStore.dataHash( ...
                        configuration.StridePlan),artifact.stridePlanHash)
                    error('lmz:Artifact:StridePlanConfiguration', ...
                        ['Stored problem configuration and top-level ' ...
                        'stride plan do not match.']);
                end
            end
        end

        function validateStrideDefinition(artifact,sections)
            definition=lmz.poincare.StrideDefinition( ...
                artifact.strideDefinition);
            expected=definition.fingerprint();
            if ~ischar(artifact.strideDefinitionHash)|| ...
                    isempty(regexp(artifact.strideDefinitionHash, ...
                    '^[0-9a-fA-F]{64}$','once'))|| ...
                    ~strcmpi(artifact.strideDefinitionHash,expected)
                error('lmz:Artifact:StrideDefinitionHash', ...
                    ['Stored stride-definition hash does not match its ' ...
                    'plain-data record.']);
            end
            start=lmz.io.ArtifactStore.sectionRecord( ...
                sections,definition.StartSectionId);
            stop=lmz.io.ArtifactStore.sectionRecord( ...
                sections,definition.StopSectionId);
            if isempty(start)||isempty(stop)|| ...
                    (~isempty(definition.StartSectionHash)&& ...
                    ~strcmpi(definition.StartSectionHash, ...
                    start.DescriptorHash))|| ...
                    (~isempty(definition.StopSectionHash)&& ...
                    ~strcmpi(definition.StopSectionHash,stop.DescriptorHash))
                error('lmz:Artifact:StrideDefinitionSection', ...
                    ['Stride-definition endpoints or descriptor hashes do ' ...
                    'not match Poincare metadata.']);
            end
        end

        function assertPlainData(value,path)
            if isa(value,'function_handle')||isobject(value)
                error('lmz:Artifact:ExecutableWorkflowData', ...
                    'Workflow payload %s must contain plain inert data.',path);
            end
            if isstruct(value)
                names=fieldnames(value);
                for itemIndex=1:numel(value)
                    for fieldIndex=1:numel(names)
                        name=names{fieldIndex};
                        lmz.io.ArtifactStore.assertPlainData( ...
                            value(itemIndex).(name),[path '.' name]);
                    end
                end
            elseif iscell(value)
                for index=1:numel(value)
                    lmz.io.ArtifactStore.assertPlainData( ...
                        value{index},sprintf('%s{%d}',path,index));
                end
            end
        end
    end
end
