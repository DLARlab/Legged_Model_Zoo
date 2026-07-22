classdef WorkflowRegistry < handle
    %WORKFLOWREGISTRY Discover validated data/workbench/workflow contributions.
    properties (SetAccess=private)
        ModelRegistry
        DataSources
        Workbenches
        Workflows
    end
    methods (Static)
        function obj=fromModelRegistry(registry)
            if ~isa(registry,'lmz.registry.ModelRegistry')
                error('lmz:Workflow:ModelRegistry', ...
                    'Workflow discovery requires a ModelRegistry.');
            end
            obj=lmz.workflow.WorkflowRegistry(registry);
        end
    end
    methods
        function obj=WorkflowRegistry(registry)
            obj.ModelRegistry=registry;
            obj.DataSources=lmz.workflow.DataSourceDescriptor.empty(0,1);
            obj.Workbenches=lmz.workflow.WorkbenchContribution.empty(0,1);
            obj.Workflows=lmz.workflow.WorkflowDescriptor.empty(0,1);
            modelIds=registry.listModels();
            for modelIndex=1:numel(modelIds)
                modelId=modelIds{modelIndex};manifest=registry.getManifest(modelId);
                obj.loadDataSources(modelId,manifest);
                obj.loadWorkbench(modelId,manifest);
            end
            for modelIndex=1:numel(modelIds)
                modelId=modelIds{modelIndex};manifest=registry.getManifest(modelId);
                obj.loadWorkflows(modelId,manifest);
            end
            obj.assertUniqueKeys();
        end

        function ids=list(obj,modelId)
            selected=true(size(obj.Workflows));
            if nargin>=2&&~isempty(modelId)
                selected=arrayfun(@(item)strcmp(item.ModelId,modelId), ...
                    obj.Workflows);
            end
            ids=arrayfun(@(item)item.Id,obj.Workflows(selected), ...
                'UniformOutput',false);
            ids=reshape(sort(ids),1,[]);
        end

        function descriptor=get(obj,modelId,workflowId)
            selected=arrayfun(@(item)strcmp(item.ModelId,modelId)&& ...
                strcmp(item.Id,workflowId),obj.Workflows);
            index=find(selected,1);
            if isempty(index)
                error('lmz:Workflow:UnknownWorkflow', ...
                    'Unknown workflow %s for model %s.',workflowId,modelId);
            end
            descriptor=obj.Workflows(index);
        end

        function values=listDataSources(obj,modelId)
            selected=arrayfun(@(item)strcmp(item.ModelId,modelId), ...
                obj.DataSources);
            values=obj.DataSources(selected);
        end

        function descriptor=getDataSource(obj,modelId,dataSourceId)
            selected=arrayfun(@(item)strcmp(item.ModelId,modelId)&& ...
                strcmp(item.Id,dataSourceId),obj.DataSources);
            index=find(selected,1);
            if isempty(index)
                error('lmz:Workflow:UnknownDataSource', ...
                    'Unknown data source %s for model %s.',dataSourceId,modelId);
            end
            descriptor=obj.DataSources(index);
        end

        function descriptor=defaultDataSource(obj,modelId)
            values=obj.listDataSources(modelId);
            if isempty(values)
                error('lmz:Workflow:MissingDataSource', ...
                    'Model %s does not register a data source.',modelId);
            end
            descriptor=values(1);
        end

        function provider=createDataSourceProvider(obj,modelId,dataSourceId)
            provider=obj.getDataSource(modelId,dataSourceId).createProvider();
        end

        function contribution=getWorkbench(obj,modelId)
            selected=arrayfun(@(item)strcmp(item.ModelId,modelId), ...
                obj.Workbenches);
            index=find(selected,1);
            if isempty(index)
                contribution=lmz.workflow.WorkbenchContribution.generic(modelId);
            else
                contribution=obj.Workbenches(index);
            end
        end

        function [modelId,descriptor]=findDataSource(obj,dataSourceId)
            selected=arrayfun(@(item)strcmp(item.Id,dataSourceId), ...
                obj.DataSources);
            indices=find(selected);
            if numel(indices)~=1
                error('lmz:Workflow:AmbiguousDataSource', ...
                    'Data-source ID %s is absent or ambiguous.',dataSourceId);
            end
            descriptor=obj.DataSources(indices);modelId=descriptor.ModelId;
        end
    end
    methods (Access=private)
        function loadDataSources(obj,modelId,manifest)
            if isempty(manifest.dataSourcesPath),return,end
            assertHash(manifest.dataSourcesPath,manifest.dataSourcesHash, ...
                'lmz:Workflow:DataSourceChanged');
            value=lmz.io.SafeJson.read(manifest.dataSourcesPath, ...
                'Root',manifest.catalogDirectory);
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~isfield(value,'schemaVersion')|| ...
                    ~strcmp(value.schemaVersion,'1.0.0')|| ...
                    ~isfield(value,'dataSources')
                error('lmz:Workflow:DataSourceCatalog', ...
                    'Data-source catalog must use schema 1.0.0.');
            end
            records=objectCells(value.dataSources,'dataSources');
            for index=1:numel(records)
                record=records{index};
                if ~isfield(record,'schemaVersion')
                    record.schemaVersion=value.schemaVersion;
                end
                descriptor=lmz.workflow.DataSourceDescriptor(record, ...
                    'Registry',obj.ModelRegistry, ...
                    'SourcePath',manifest.dataSourcesPath, ...
                    'SourceHash',manifest.dataSourcesHash);
                if ~strcmp(descriptor.ModelId,modelId)
                    error('lmz:Workflow:DataSourceModel', ...
                        'Data source is registered under the wrong model.');
                end
                obj.ModelRegistry.getProblemDescriptor(modelId, ...
                    descriptor.ProblemId);
                % Resolve the inert class name through the registry trust
                % boundary during discovery, not only on first data load.
                descriptor.createProvider();
                obj.DataSources(end+1,1)=descriptor;
            end
        end

        function loadWorkbench(obj,modelId,manifest)
            if isempty(manifest.workbenchPath)
                obj.Workbenches(end+1,1)= ...
                    lmz.workflow.WorkbenchContribution.generic(modelId);
                return
            end
            assertHash(manifest.workbenchPath,manifest.workbenchHash, ...
                'lmz:Workflow:WorkbenchChanged');
            value=lmz.io.SafeJson.read(manifest.workbenchPath, ...
                'Root',manifest.catalogDirectory);
            contribution=lmz.workflow.WorkbenchContribution(value,modelId, ...
                'SourcePath',manifest.workbenchPath, ...
                'SourceHash',manifest.workbenchHash);
            if ~strcmp(contribution.ModelId,modelId)
                error('lmz:Workflow:WorkbenchModel', ...
                    'Workbench contribution is registered under the wrong model.');
            end
            obj.Workbenches(end+1,1)=contribution;
        end

        function loadWorkflows(obj,modelId,manifest)
            for index=1:numel(manifest.workflowPaths)
                path=manifest.workflowPaths{index};hash=manifest.workflowHashes{index};
                assertHash(path,hash,'lmz:Workflow:DescriptorChanged');
                value=lmz.io.SafeJson.read(path,'Root',manifest.catalogDirectory);
                if ~isstruct(value)||~isscalar(value)|| ...
                        ~isfield(value,'modelId')||~strcmp(value.modelId,modelId)
                    error('lmz:Workflow:DescriptorModel', ...
                        'Workflow descriptor is registered under the wrong model.');
                end
                obj.ModelRegistry.getProblemDescriptor(modelId,value.problemId);
                source=obj.getDataSource(modelId,value.dataSourceId);
                workbench=obj.getWorkbench(modelId);
                if ~workbench.hasAxisPreset(value.axisPresetId)
                    error('lmz:Workflow:UnknownAxisPreset', ...
                        'Workflow %s refers to an unknown axis preset.',value.id);
                end
                axisPreset=workbench.axisPreset(value.axisPresetId);
                if ~strcmp(value.layoutProfileId,workbench.LayoutProfileId)&& ...
                        ~any(strcmp(value.layoutProfileId, ...
                        {'classic_tabs','scientific_workbench'}))
                    error('lmz:Workflow:LayoutProfile', ...
                        'Workflow layout profile is not registered.');
                end
                graphics=obj.ModelRegistry.getGraphicsConfig(modelId);
                graphics.getProfile(value.visualizationProfileId);
                descriptor=lmz.workflow.WorkflowDescriptor(value, ...
                    'Registry',obj.ModelRegistry,'DataSource',source, ...
                    'AxisPreset',axisPreset,'Workbench',workbench, ...
                    'SourcePath',path,'SourceHash',hash);
                obj.validateWorkflowCapabilities(descriptor);
                obj.Workflows(end+1,1)=descriptor;
            end
        end

        function validateWorkflowCapabilities(obj,descriptor)
            problem=obj.ModelRegistry.getProblemDescriptor( ...
                descriptor.ModelId,descriptor.ProblemId);
            mappings={{'solve'},'solve'; ...
                {'continuation','continue'},'continue'; ...
                {'parameter_homotopy','homotopy'},'parameterHomotopy'; ...
                {'branch_family','family_scan'},'branchFamilyScan'; ...
                {'simulate','simulation'},'simulate'};
            for index=1:size(mappings,1)
                aliases=mappings{index,1};capability=mappings{index,2};
                if any(ismember(descriptor.AllowedSteps,aliases))&& ...
                        (~isfield(problem.capabilities,capability)|| ...
                        ~problem.capabilities.(capability))
                    error('lmz:Workflow:UnsupportedStep', ...
                        'Workflow step %s is unsupported by %s.', ...
                        aliases{1},descriptor.ProblemId);
                end
            end
        end

        function assertUniqueKeys(obj)
            sourceKeys=arrayfun(@(item)[item.ModelId '/' item.Id], ...
                obj.DataSources,'UniformOutput',false);
            workflowKeys=arrayfun(@(item)[item.ModelId '/' item.Id], ...
                obj.Workflows,'UniformOutput',false);
            workbenchIds=arrayfun(@(item)item.ModelId,obj.Workbenches, ...
                'UniformOutput',false);
            if numel(unique(sourceKeys))~=numel(sourceKeys)|| ...
                    numel(unique(workflowKeys))~=numel(workflowKeys)|| ...
                    numel(unique(workbenchIds))~=numel(workbenchIds)
                error('lmz:Workflow:DuplicateRegistration', ...
                    'Workflow registration keys must be unique.');
            end
        end
    end
end

function assertHash(path,expected,identifier)
if ~strcmpi(lmz.util.FileHash.sha256(path),expected)
    error(identifier,'Registered workflow catalog changed after discovery.');
end
end
function values=objectCells(value,name)
if isempty(value),values={};elseif iscell(value),values=value(:)'; ...
elseif isstruct(value),values=num2cell(value(:)');else
    error('lmz:Workflow:CatalogObjects','%s must be an object list.',name);
end
end
