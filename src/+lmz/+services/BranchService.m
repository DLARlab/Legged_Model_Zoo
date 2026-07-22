classdef BranchService
    %BRANCHSERVICE Provider-driven branch loading, selection, and legacy IO.
    methods
        function dataset=loadDataSource(~,workflowRegistry,modelId, ...
                dataSourceId,datasetId)
            if ~isa(workflowRegistry,'lmz.workflow.WorkflowRegistry')
                error('lmz:Branch:WorkflowRegistry', ...
                    'Branch loading requires a WorkflowRegistry.');
            end
            descriptor=workflowRegistry.getDataSource(modelId,dataSourceId);
            if nargin<5||isempty(datasetId)
                datasetId=descriptor.DefaultDatasetId;
            end
            provider=descriptor.createProvider();
            dataset=provider.load(descriptor,datasetId, ...
                workflowRegistry.ModelRegistry);
            assertDataset(dataset,modelId,descriptor.ProblemId);
        end

        function datasets=loadAllDataSource(~,workflowRegistry,modelId, ...
                dataSourceId)
            descriptor=workflowRegistry.getDataSource(modelId,dataSourceId);
            provider=descriptor.createProvider();
            datasets=provider.loadAll(descriptor,workflowRegistry.ModelRegistry);
            for index=1:numel(datasets)
                assertDataset(datasets{index},modelId,descriptor.ProblemId);
            end
        end

        function branch=loadBuiltInBranch(obj,registry,modelId)
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            descriptor=workflows.defaultDataSource(modelId);
            dataset=obj.loadDataSource(workflows,modelId,descriptor.Id, ...
                descriptor.DefaultDatasetId);
            branch=dataset.Branch;
        end

        % Compatibility wrappers retain the Round 5-10 public names while
        % routing exclusively through registered providers.
        function branch=loadGaitMapBranch(obj,problem,file)
            if nargin<3,file='';end
            dataset=obj.compatibilityLoad(problem,'gaitmap',file);
            branch=dataset.Branch;
        end

        function datasets=loadAllGaitMapBranches(obj,problem)
            datasets=obj.compatibilityLoadAll(problem,'gaitmap');
        end

        function [branch,source]=loadQuadLoadDataset(obj,problem,file)
            if nargin<3,file='';end
            dataset=obj.compatibilityLoad(problem,'scientific_load',file);
            branch=dataset.Branch;
            source=fieldOr(dataset.Metadata,'SourceDataset',dataset);
        end

        function files=listRoadMapBranches(~)
            registry=lmz.registry.ModelRegistry.discover();
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            [~,descriptor]=workflows.findDataSource('roadmap');
            provider=descriptor.createProvider();
            records=normalizeRecords(provider.list(descriptor,registry));
            files=cell(1,numel(records));
            for index=1:numel(records)
                files{index}=recordPath(records{index});
            end
        end

        function branch=loadRoadMapBranch(obj,problem,file)
            if nargin<3,file='';end
            dataset=obj.compatibilityLoad(problem,'roadmap',file);
            branch=dataset.Branch;
        end

        function datasets=loadAllRoadMapBranches(obj,problem)
            datasets=obj.compatibilityLoadAll(problem,'roadmap');
        end

        function branch=reloadLegacySource(~,problem,file)
            [workflows,modelId]=registryForProblem(problem);
            descriptors=workflows.listDataSources(modelId);
            for index=1:numel(descriptors)
                provider=descriptors(index).createProvider();
                adapter=provider.legacyAdapter(descriptors(index), ...
                    workflows.ModelRegistry);
                if isa(adapter,'lmz.workflow.LegacyDataAdapterProvider')&& ...
                        adapter.canLoad(file)
                    branch=adapter.importBranch(file,problem);
                    return
                end
            end
            error('lmz:Branch:LegacySource', ...
                'No registered legacy adapter accepts %s.',file);
        end

        function matches=filterByFixedParameters(~,branches,name,value,tolerance)
            if nargin<5,tolerance=1e-10;end
            if ~iscell(branches),branches=num2cell(branches);end
            matches=false(size(branches));
            for index=1:numel(branches)
                values=branches{index}.parameter(name);
                matches(index)=all(abs(values-value)<= ...
                    tolerance*max(1,abs(value)));
            end
        end

        function names=identifyVaryingParameter(~,branch,tolerance)
            if nargin<3,tolerance=1e-10;end
            names={};candidates=branch.ParameterSchema.names();
            for index=1:numel(candidates)
                values=branch.parameter(candidates{index});
                if max(values)-min(values)> ...
                        tolerance*max(1,max(abs(values)))
                    names{end+1}=candidates{index}; %#ok<AGROW>
                end
            end
        end

        function dataset=selectActiveDataset(~,datasets,datasetId)
            for index=1:numel(datasets)
                if strcmp(datasets{index}.Id,datasetId)|| ...
                        strcmp(datasets{index}.Name,datasetId)
                    dataset=datasets{index};return
                end
            end
            error('lmz:Branch:DatasetMissing','Active dataset is missing.');
        end

        function dataset=addDataset(~,name,branch)
            dataset=lmz.data.BranchDataset(name,branch);
        end
        function values=coordinateValues(~,dataset,name)
            values=dataset.Branch.coordinate(name);
        end
        function selection=selectPoint(~,dataset,index)
            solution=dataset.Branch.point(index);
            selection=lmz.data.Selection(dataset.Id,index,solution.Id,'branch');
        end
        function saveNativeBranch(~,path,branch)
            lmz.io.ArtifactStore.save(path,branch.toArtifact());
        end
        function branch=loadNativeBranch(~,path)
            artifact=lmz.io.ArtifactStore.load(path);
            branch=lmz.data.SolutionBranch.fromArtifact(artifact);
        end

        function exportLegacyBranch(~,path,branch)
            registry=lmz.registry.ModelRegistry.discover();
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            descriptors=workflows.listDataSources(branch.ModelId);
            for index=1:numel(descriptors)
                provider=descriptors(index).createProvider();
                adapter=provider.legacyAdapter(descriptors(index),registry);
                if isa(adapter,'lmz.workflow.LegacyDataAdapterProvider')
                    try
                        adapter.exportBranch(path,branch);
                        return
                    catch exception
                        if ~strcmp(exception.identifier, ...
                                'lmz:Workflow:LegacyUnsupported')
                            rethrow(exception)
                        end
                    end
                end
            end
            error('lmz:Branch:LegacyModel', ...
                'No legacy exporter is registered for %s.',branch.ModelId);
        end
    end
    methods (Access=private)
        function dataset=compatibilityLoad(obj,problem,dataSourceId,file)
            [workflows,modelId]=registryForProblem(problem);
            descriptor=sourceOrKind(workflows,modelId,dataSourceId);
            if isempty(file),file=descriptor.DefaultDatasetId;end
            dataset=obj.loadDataSource(workflows,modelId,descriptor.Id,file);
        end
        function datasets=compatibilityLoadAll(obj,problem,dataSourceId)
            [workflows,modelId]=registryForProblem(problem);
            descriptor=sourceOrKind(workflows,modelId,dataSourceId);
            datasets=obj.loadAllDataSource(workflows,modelId,descriptor.Id);
        end
    end
end

function [workflows,modelId]=registryForProblem(problem)
if ~isa(problem,'lmz.api.NonlinearEquationProblem')&& ...
        ~isa(problem,'lmz.api.OptimizationProblem')
    error('lmz:Branch:Problem','A registered problem is required.');
end
descriptor=problem.getDescriptor();modelId=descriptor.modelId;
registry=lmz.registry.ModelRegistry.discover();
workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
end
function descriptor=sourceOrKind(workflows,modelId,dataSourceId)
try
    descriptor=workflows.getDataSource(modelId,dataSourceId);
catch exception
    if ~strcmp(exception.identifier,'lmz:Workflow:UnknownDataSource'),rethrow(exception),end
    values=workflows.listDataSources(modelId);
    selected=arrayfun(@(item)any(strcmp(item.Kind, ...
        {'branch_catalog','scientific_dataset','single_branch'})),values);
    index=find(selected,1);
    if isempty(index),rethrow(exception),end
    descriptor=values(index);
end
end
function assertDataset(dataset,modelId,problemId)
if ~isa(dataset,'lmz.data.BranchDataset')|| ...
        ~strcmp(dataset.Branch.ModelId,modelId)|| ...
        ~strcmp(dataset.Branch.ProblemId,problemId)
    error('lmz:Branch:ProviderContract', ...
        'Registered provider returned an incompatible BranchDataset.');
end
end
function values=normalizeRecords(records)
if isempty(records),values={};elseif iscell(records),values=records(:)'; ...
elseif isstruct(records),values=num2cell(records(:)');else,values={records};end
end
function value=recordPath(record)
if ischar(record)
    value=record;
elseif isfield(record,'path')
    value=record.path;
elseif isfield(record,'Path')
    value=record.Path;
elseif isfield(record,'id')
    value=record.id;
else
    error('lmz:Branch:ProviderRecord','Provider record has no path.');
end
end
function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
