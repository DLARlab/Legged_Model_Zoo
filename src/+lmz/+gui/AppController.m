classdef AppController < handle
    %APPCONTROLLER Headless coordinator for demo and RoadMap workflows.
    properties (SetAccess=private)
        Registry
        State
        Context
        Events
    end
    properties (Access=private)
        StateListeners = {}
    end
    methods
        function obj=AppController(registry,context,eventBus)
            if nargin<1,registry=lmz.registry.ModelRegistry.discover();end
            if nargin<2,context=lmz.api.RunContext.synchronous(0);end
            if nargin<3||isempty(eventBus),eventBus=lmz.gui.PresentationEventBus();end
            obj.Registry=registry;obj.Context=context;obj.Events=eventBus;
            obj.State=lmz.gui.AppState();obj.observeState();
            ids=obj.Registry.listModels();obj.selectModel(ids{1});
        end
        function ids=modelIds(obj),ids=obj.Registry.listModels();end
        function selectModel(obj,modelId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);else,obj.Context.Pause.resume();end
            model=obj.Registry.createModel(modelId);manifest=model.getManifest();problems=model.listProblems();
            obj.State.ModelId=manifest.id;obj.State.ProblemId=problems{1};obj.State.Simulation=[];
            examples=obj.builtInExamples();
            if isempty(examples)
                obj.State.ExampleId='';
            elseif ~any(strcmp(obj.State.ExampleId,examples))
                obj.State.ExampleId=examples{1};
            end
            obj.State.CandidateSimulation=[];obj.State.Datasets={};obj.State.Selection=[];
            obj.State.LockedSelection=[];obj.State.HoverSelection=[];obj.State.WorkingSolution=[];
            obj.State.WorkingEvaluation=[];
            obj.State.SolvedSolution=[];obj.State.SolveResult=[];obj.State.SeedPair=[];
            obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            obj.State.OptimizationResult=[];obj.State.CurrentRun=[];obj.State.RecordingState=struct();
            obj.State.Status=['Selected ' manifest.id];
            switch modelId
                case 'slip_quadruped'
                    obj.loadRoadMap();
                case 'slip_biped'
                    obj.loadGaitMap();
                case 'slip_quad_load'
                    obj.loadScientificLoadDataset();
                otherwise
                    obj.initializeGenericModel(model,problems{1});
            end
        end
        function ids=problemIds(obj),ids=obj.Registry.createModel(obj.State.ModelId).listProblems();end
        function solution=selectProblem(obj,problemId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            model=obj.Registry.createModel(obj.State.ModelId);
            problemIds=model.listProblems();
            if ~any(strcmp(problemId,problemIds))
                error('lmz:GUI:UnknownProblem', ...
                    'Unknown problem %s for selected model %s.', ...
                    problemId,obj.State.ModelId);
            end
            problem=model.createProblem(problemId,struct());
            obj.invalidateDerived();
            obj.State.ProblemId=problemId;
            obj.State.HoverSelection=[];

            [dataset,index]=obj.problemDataset(problemId);
            if ~isempty(dataset)
                solution=obj.lockBranchPoint(dataset.Id,index);
                obj.State.Status=sprintf('Selected %s using %s point %d.', ...
                    problemId,dataset.Name,index);
                return
            end

            obj.State.Selection=[];
            obj.State.LockedSelection=[];
            if isa(problem,'lmz.api.SimulationProblem')
                solution=obj.makeTutorialSolution(problemId);
            else
                solution=problem.makeSolution( ...
                    problem.getDecisionSchema().defaults(), ...
                    problem.getParameterSchema().defaults(),[]);
            end
            obj.State.WorkingSolution=solution;
            obj.State.Status=sprintf('Selected %s.',problemId);
        end
        function setExample(obj,exampleId)
            obj.State.ExampleId=char(exampleId);
        end
        function setContinuationPreview(obj,value)
            obj.State.ContinuationPreview=value;
        end
        function examples=builtInExamples(obj)
            try
                examples=lmz.services.DataService().listBuiltInExamples(obj.State.ModelId);
            catch
                examples={};
            end
        end
        function value=canSimulateDemo(obj)
            value=~isempty(obj.simulationProblemIds());
        end
        function result=simulate(obj,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            [problem,defaultOptions]=obj.demoProblem();
            if nargin<2||isempty(options)|| ...
                    (isstruct(options)&&isempty(fieldnames(options)))
                options=defaultOptions;
            end
            result=lmz.services.SimulationService().simulate(problem,struct(),options,obj.Context);
            obj.State.Simulation=result;
            obj.State.Status=sprintf('%s demonstration simulation complete.', ...
                problem.Id);
        end
        function capabilities=capabilities(obj)
            capabilities=obj.problemCapabilities();
        end
        function capabilities=problemCapabilities(obj,problemId)
            if nargin<2||isempty(problemId),problemId=obj.State.ProblemId;end
            descriptor=obj.Registry.getProblemDescriptor(obj.State.ModelId,problemId);
            capabilities=descriptor.capabilities;
        end
        function names=homotopyParameterNames(obj)
            solution=obj.State.WorkingSolution;
            if isempty(solution),names={};return,end
            schema=solution.ParameterSchema;
            selectable=arrayfun(@(spec)strcmp(spec.Activity,'active'),schema.Specs);
            names=schema.names();names=names(selectable);
        end

        function dataset=loadBuiltInBranch(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            branch=lmz.services.BranchService().loadBuiltInBranch(obj.Registry,obj.State.ModelId);
            dataset=lmz.data.BranchDataset([obj.State.ModelId ' built-in'],branch,'ReadOnly',true);
            obj.State.Datasets={dataset};obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=loadGaitMap(obj,file)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~strcmp(obj.State.ModelId,'slip_biped')
                error('lmz:GUI:GaitMapModel','GaitMap is available for slip_biped.');
            end
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            obj.State.RoadMapCatalog=catalog;
            if nargin<2||isempty(file),file=catalog.defaultBranchPath();end
            problem=obj.problem('periodic_apex');
            branch=lmz.services.BranchService().loadGaitMapBranch(problem,file);
            record=catalog.record(file);index=catalog.recommendedSeedIndex(file);
            gait=branch.Classifications{index};style=struct('Color',gait.Color, ...
                'LineStyle',gait.LineStyle,'Marker','none');
            metadata=struct('PointCount',branch.pointCount(), ...
                'ParameterSummary','offset_left/offset_right', ...
                'GaitSummary',record.gait,'SourceHash',record.sha256, ...
                'NativePath',catalog.nativePath(file),'Status','built-in/read-only');
            dataset=lmz.data.BranchDataset(record.name,branch,'SourcePath',file, ...
                'ReadOnly',true,'DisplayStyle',style,'Metadata',metadata);
            retained=obj.writableDatasets();obj.State.Datasets=[{dataset} retained];
            obj.State.ActiveDatasetId=dataset.Id;obj.State.AxisVariables={'dx','alphaL','y'};
            obj.lockBranchPoint(dataset.Id,index);
            obj.State.Status=sprintf('Biped GaitMap loaded: %s (%d points)', ...
                dataset.Name,branch.pointCount());
        end
        function datasets=loadAllGaitMapBranches(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~strcmp(obj.State.ModelId,'slip_biped')
                error('lmz:GUI:GaitMapModel','GaitMap is available for slip_biped.');
            end
            datasets=lmz.services.BranchService().loadAllGaitMapBranches( ...
                obj.problem('periodic_apex'));
            obj.State.Datasets=[datasets obj.writableDatasets()];
            obj.State.ActiveDatasetId=datasets{1}.Id;obj.State.AxisVariables={'dx','alphaL','y'};
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            obj.lockBranchPoint(datasets{1}.Id, ...
                catalog.recommendedSeedIndex(datasets{1}.SourcePath));
            obj.State.Status=sprintf('All %d biped GaitMap branches loaded.',numel(datasets));
        end
        function dataset=loadScientificLoadDataset(obj,file)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~strcmp(obj.State.ModelId,'slip_quad_load')
                error('lmz:GUI:LoadDatasetModel', ...
                    'Scientific load datasets are available for slip_quad_load.');
            end
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            obj.State.RoadMapCatalog=catalog;
            if nargin<2||isempty(file),file=catalog.defaultMultiPath();end
            problem=obj.problem('multi_stride_fit');
            [branch,source]=lmz.services.BranchService().loadQuadLoadDataset(problem,file);
            record=catalog.record(source.Name);style=struct('Color',[0.15 0.45 0.72], ...
                'LineStyle','-','Marker','o');
            metadata=struct('PointCount',1,'ParameterSummary', ...
                sprintf('%d strides, 44+13(N-1) layout',source.StrideCount), ...
                'GaitSummary',source.Kind,'SourceHash',record.sha256, ...
                'NativePath',catalog.nativePath(record.id),'Status','built-in/read-only');
            dataset=lmz.data.BranchDataset(source.Name,branch,'SourcePath',file, ...
                'ReadOnly',true,'DisplayStyle',style,'Metadata',metadata);
            retained=obj.writableDatasets();obj.State.Datasets=[{dataset} retained];
            obj.State.ActiveDatasetId=dataset.Id;
            obj.State.AxisVariables={'quad_dx','tAPEX','tugline_stiffness'};
            obj.lockBranchPoint(dataset.Id,1);
            obj.State.Status=sprintf('Scientific load dataset loaded: %s (%d strides)', ...
                source.Name,source.StrideCount);
        end
        function datasets=loadAllScientificLoadDatasets(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~strcmp(obj.State.ModelId,'slip_quad_load')
                error('lmz:GUI:LoadDatasetModel', ...
                    'Scientific load datasets are available for slip_quad_load.');
            end
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            records=catalog.records();datasets=cell(1,numel(records));
            problem=obj.problem('multi_stride_fit');service=lmz.services.BranchService();
            for index=1:numel(records)
                file=catalog.pathFor(records(index).id);[branch,source]= ...
                    service.loadQuadLoadDataset(problem,file);
                style=struct('Color',linesColor(index),'LineStyle','-', ...
                    'Marker','o');
                metadata=struct('PointCount',1,'ParameterSummary', ...
                    sprintf('%d strides, 44+13(N-1) layout',source.StrideCount), ...
                    'GaitSummary',source.Kind,'SourceHash',records(index).sha256, ...
                    'NativePath',catalog.nativePath(records(index).id), ...
                    'Status','built-in/read-only');
                datasets{index}=lmz.data.BranchDataset(source.Name,branch, ...
                    'SourcePath',file,'ReadOnly',true,'DisplayStyle',style, ...
                    'Metadata',metadata);
            end
            obj.State.Datasets=[datasets obj.writableDatasets()];
            obj.State.ActiveDatasetId=datasets{1}.Id;
            obj.State.AxisVariables={'quad_dx','tAPEX','tugline_stiffness'};
            obj.lockBranchPoint(datasets{1}.Id,1);
            obj.State.Status=sprintf('All %d scientific load datasets loaded.',numel(datasets));
        end
        function dataset=loadRoadMap(obj,file)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~strcmp(obj.State.ModelId,'slip_quadruped')
                error('lmz:GUI:RoadMapModel','RoadMap is available for slip_quadruped.');
            end
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();obj.State.RoadMapCatalog=catalog;
            if nargin<2||isempty(file),file=catalog.defaultBranchPath();end
            problem=obj.problem('periodic_apex');service=lmz.services.BranchService();
            branch=service.loadRoadMapBranch(problem,file);record=catalog.record(file);
            gait=branch.Classifications{catalog.recommendedSeedIndex(file)};
            style=struct('Color',gait.Color,'LineStyle',gait.LineStyle,'Marker','none');
            metadata=struct('PointCount',branch.pointCount(),'ParameterSummary',record.parameterSummary, ...
                'GaitSummary',record.inferredGaitSummary,'SourceHash',record.sha256, ...
                'NativePath',catalog.nativePath(file),'Status','built-in/read-only');
            [~,name,extension]=fileparts(file);
            dataset=lmz.data.BranchDataset([name extension],branch,'SourcePath',file, ...
                'ReadOnly',true,'DisplayStyle',style,'Metadata',metadata);
            retained=obj.writableDatasets();obj.State.Datasets=[{dataset} retained];obj.State.ActiveDatasetId=dataset.Id;
            view=catalog.Manifest.defaultView;
            obj.State.AxisVariables={view.x,view.y,view.z};
            obj.lockBranchPoint(dataset.Id,catalog.recommendedSeedIndex(file));
            obj.State.Status=sprintf('RoadMap loaded: %s (%d points)',dataset.Name,branch.pointCount());
        end
        function datasets=loadAllRoadMapBranches(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();obj.State.RoadMapCatalog=catalog;
            datasets=lmz.services.BranchService().loadAllRoadMapBranches(obj.problem('periodic_apex'));
            obj.State.Datasets=[datasets obj.writableDatasets()];obj.State.ActiveDatasetId=datasets{1}.Id;
            obj.lockBranchPoint(datasets{1}.Id,catalog.recommendedSeedIndex(datasets{1}.SourcePath));
            obj.State.Status=sprintf('All %d RoadMap branches loaded.',numel(datasets));
        end
        function dataset=openBranch(obj,path)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            variables=whos('-file',path);names={variables.name};service=lmz.services.BranchService();
            if numel(names)==1&&strcmp(names{1},'artifact')
                branch=service.loadNativeBranch(path);readOnly=false;
            elseif any(strcmp(names,'results'))
                resultInfo=variables(strcmp(names,'results'));
                if resultInfo.size(1)==14&&strcmp(obj.State.ModelId,'slip_biped')
                    branch=lmzmodels.slip_biped.Results14Adapter.loadBranch( ...
                        path,obj.problem('periodic_apex'));readOnly=true;
                elseif resultInfo.size(1)==29&&strcmp(obj.State.ModelId,'slip_quadruped')
                    branch=lmzmodels.slip_quadruped.Results29Adapter.loadBranch( ...
                        path,obj.problem('periodic_apex'));readOnly=true;
                else
                    error('lmz:GUI:BranchModel', ...
                        'The Results matrix does not match the selected model.');
                end
            elseif any(strcmp(names,'X_accum'))&&strcmp(obj.State.ModelId,'slip_quad_load')
                [branch,~]=service.loadQuadLoadDataset( ...
                    obj.problem('multi_stride_fit'),path);readOnly=true;
            else,error('lmz:GUI:BranchFile', ...
                    'MAT file is not a native, Results14/29, or X_accum dataset.');end
            if ~strcmp(branch.ModelId,obj.State.ModelId)
                error('lmz:GUI:BranchModel', ...
                    'The branch belongs to %s, not selected model %s.', ...
                    branch.ModelId,obj.State.ModelId);
            end
            [~,name,extension]=fileparts(path);style=struct();classification=branch.Classifications{1};if isfield(classification,'Color'),style.Color=classification.Color;end;if isfield(classification,'LineStyle'),style.LineStyle=classification.LineStyle;end
            dataset=lmz.data.BranchDataset([name extension],branch,'SourcePath',path,'ReadOnly',readOnly,'DisplayStyle',style,'Metadata',struct('Status','user-loaded','PointCount',branch.pointCount()));
            obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function datasets=openBranchFolder(obj,folder)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            entries=dir(fullfile(folder,'*.mat'));datasets={};errors={};
            for index=1:numel(entries)
                path=fullfile(entries(index).folder,entries(index).name);
                try
                    datasets{end+1}=obj.openBranch(path); %#ok<AGROW>
                catch exception
                    errors{end+1}=sprintf('%s: %s',entries(index).name,exception.message); %#ok<AGROW>
                end
            end
            if isempty(datasets)
                if isempty(errors),message='No MAT files were found.';else,message=strjoin(errors,newline);end
                error('lmz:GUI:BranchFolder','No supported branches loaded from %s. %s',folder,message);
            end
            obj.State.Status=sprintf('Loaded %d branch datasets from %s.',numel(datasets),folder);
        end
        function dataset=reloadActiveDataset(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.activeDataset();path=dataset.SourcePath;
            if isempty(path)||exist(path,'file')~=2,error('lmz:GUI:ReloadPath','The active dataset has no reloadable source file.');end
            variables=whos('-file',path);names={variables.name};service=lmz.services.BranchService();
            if any(strcmp(names,'results'))||any(strcmp(names,'X_accum'))
                branch=service.reloadLegacySource(obj.problem(dataset.Branch.ProblemId),path);
            elseif numel(names)==1&&strcmp(names{1},'artifact')
                branch=service.loadNativeBranch(path);
            else
                error('lmz:GUI:ReloadType','The active dataset source is not a supported branch file.');
            end
            oldIndex=1;if ~isempty(obj.State.LockedSelection)&&strcmp(obj.State.LockedSelection.DatasetId,dataset.Id),oldIndex=obj.State.LockedSelection.PointIndex;end
            dataset.Branch=branch;dataset.Metadata.PointCount=branch.pointCount();
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','dataset-reloaded','DatasetId',dataset.Id));
            obj.lockBranchPoint(dataset.Id,min(oldIndex,branch.pointCount()));
            obj.State.Status=sprintf('Reloaded %s from disk.',dataset.Name);
        end
        function removeDataset(obj,datasetId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            keep=true(1,numel(obj.State.Datasets));for index=1:numel(obj.State.Datasets),if strcmp(obj.State.Datasets{index}.Id,datasetId),keep(index)=false;end,end
            obj.State.Datasets=obj.State.Datasets(keep);
            if isempty(obj.State.Datasets),obj.State.ActiveDatasetId='';obj.State.LockedSelection=[];obj.State.Selection=[];obj.State.WorkingSolution=[];obj.invalidateDerived();return,end
            obj.State.ActiveDatasetId=obj.State.Datasets{1}.Id;obj.lockBranchPoint(obj.State.ActiveDatasetId,1);
        end
        function setDatasetVisibility(obj,datasetId,visible)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.findDataset(datasetId);dataset.Visible=logical(visible);
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','visibility','DatasetId',dataset.Id));
            obj.State.Status=sprintf('%s visibility: %s.',dataset.Name,onOff(dataset.Visible));
        end
        function setAllDatasetsVisible(obj,visible)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            for index=1:numel(obj.State.Datasets)
                obj.State.Datasets{index}.Visible=logical(visible);
            end
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','visibility-all'));
            obj.State.Status=sprintf('All dataset visibility: %s.',onOff(visible));
        end
        function showOnlyActiveDataset(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            for index=1:numel(obj.State.Datasets)
                obj.State.Datasets{index}.Visible=strcmp( ...
                    obj.State.Datasets{index}.Id,obj.State.ActiveDatasetId);
            end
            obj.Events.publish(lmz.gui.PresentationEvents.DatasetsChanged, ...
                struct('Reason','visibility-active-only'));
            obj.State.Status='Only the active dataset is visible.';
        end
        function dataset=plotDataset(obj,datasetId,visible),if nargin<3,visible=true;end;dataset=obj.findDataset(datasetId);obj.setDatasetVisibility(datasetId,visible);end
        function dataset=addWorkingSolutionToDataset(obj,name)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            solution=obj.State.WorkingSolution;
            if isempty(solution),error('lmz:GUI:NoWorkingSolution','No working solution is available.');end
            branch=lmz.data.SolutionBranch.fromSolutions(solution);dataset=lmz.data.BranchDataset(name,branch,'ReadOnly',false,'Metadata',struct('Status','working/user'));obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=addBranchDataset(obj,name,branch)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if ~isa(branch,'lmz.data.SolutionBranch'),error('lmz:GUI:BranchType','A native SolutionBranch is required.');end
            dataset=lmz.data.BranchDataset(name,branch,'ReadOnly',false,'Metadata',struct('Status','generated/user','PointCount',branch.pointCount()));
            obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=activeDataset(obj),dataset=obj.findDataset(obj.State.ActiveDatasetId);end
        function solution=lockedSolution(obj)
            if isempty(obj.State.LockedSelection),solution=[];return,end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            solution=dataset.Branch.point(obj.State.LockedSelection.PointIndex);
        end
        function setActiveDataset(obj,datasetId)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.findDataset(datasetId);obj.State.ActiveDatasetId=dataset.Id;
            index=1;if ~isempty(obj.State.LockedSelection)&&strcmp(obj.State.LockedSelection.DatasetId,dataset.Id),index=obj.State.LockedSelection.PointIndex;end
            obj.lockBranchPoint(dataset.Id,index);
        end
        function setAxisVariables(obj,x,y,z)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.activeDataset();known=dataset.Branch.coordinateNames();
            values={x,y};if nargin>=4&&~isempty(z),values{3}=z;else,values{3}='';end
            for index=1:2+(~isempty(values{3})),if ~any(strcmp(values{index},known)),error('lmz:GUI:AxisVariable','Unknown coordinate %s.',values{index});end,end
            if isequal(obj.State.AxisVariables,values),return,end
            obj.State.AxisVariables=values;
        end
        function values=axisValues(obj,datasetId)
            if nargin<2||isempty(datasetId),dataset=obj.activeDataset();else,dataset=obj.findDataset(datasetId);end
            names=obj.State.AxisVariables;values=struct('X',dataset.Branch.coordinate(names{1}), ...
                'Y',dataset.Branch.coordinate(names{2}),'Z',[]);
            if numel(names)>=3&&~isempty(names{3}),values.Z=dataset.Branch.coordinate(names{3});end
        end
        function selection=hoverNearestPoint(obj,datasetId,coordinates,target)
            dataset=obj.findDataset(datasetId);index=dataset.Branch.nearestPoint(coordinates,target);
            solution=dataset.Branch.point(index);selection=lmz.data.Selection(dataset.Id,index,solution.Id,'hover');
            obj.State.HoverSelection=selection;
        end
        function [selection,details]=hoverNearestVisiblePoint(obj,coordinates,target)
            visible={};
            for index=1:numel(obj.State.Datasets),if obj.State.Datasets{index}.Visible,visible{end+1}=obj.State.Datasets{index};end,end %#ok<AGROW>
            if isempty(visible),error('lmz:GUI:NoVisibleDataset','No visible dataset is available.');end
            dimensions=numel(coordinates);target=target(1:dimensions);ranges=zeros(dimensions,2);
            for axisIndex=1:dimensions
                allValues=[];for datasetIndex=1:numel(visible),allValues=[allValues visible{datasetIndex}.Branch.coordinate(coordinates{axisIndex})];end %#ok<AGROW>
                ranges(axisIndex,:)=[min(allValues) max(allValues)];
            end
            scales=max(ranges(:,2)-ranges(:,1),sqrt(eps));best=Inf;bestDataset=[];bestIndex=1;
            for datasetIndex=1:numel(visible)
                count=visible{datasetIndex}.Branch.pointCount();matrix=zeros(dimensions,count);
                for axisIndex=1:dimensions,matrix(axisIndex,:)=visible{datasetIndex}.Branch.coordinate(coordinates{axisIndex});end
                distances=sqrt(sum(((matrix-target(:))./scales).^2,1));[distance,index]=min(distances);
                if distance<best,best=distance;bestDataset=visible{datasetIndex};bestIndex=index;end
            end
            solution=bestDataset.Branch.point(bestIndex);selection=lmz.data.Selection(bestDataset.Id,bestIndex,solution.Id,'hover');obj.State.HoverSelection=selection;
            coordinateValues=arrayfun(@(axisIndex)bestDataset.Branch.coordinate(coordinates{axisIndex}),1:dimensions,'UniformOutput',false);
            details=struct('Dataset',bestDataset,'Solution',solution,'Coordinates',{coordinates}, ...
                'Values',{coordinateValues}, ...
                'NormalizedDistance',best);
            for axisIndex=1:dimensions,details.Values{axisIndex}=details.Values{axisIndex}(bestIndex);end
        end
        function solution=lockBranchPoint(obj,datasetId,index)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            dataset=obj.findDataset(datasetId);selection=lmz.services.BranchService().selectPoint(dataset,index);
            solution=dataset.Branch.point(index);obj.State.ActiveDatasetId=dataset.Id;
            obj.invalidateDerived();
            obj.State.Selection=selection;obj.State.LockedSelection=selection;obj.State.WorkingSolution=solution;
            obj.State.ProblemId=solution.ProblemId;
            obj.State.OscillatorIndex=index;obj.State.Status=sprintf('Locked %s point %d.',dataset.Name,index);
        end
        function solution=selectBranchPoint(obj,index),solution=obj.lockBranchPoint(obj.State.ActiveDatasetId,index);end
        function solution=selectByIndex(obj,index),solution=obj.selectBranchPoint(round(index));end
        function solution=selectByPercentage(obj,percentage)
            dataset=obj.activeDataset();percentage=max(0,min(100,percentage));
            index=1+round(percentage/100*(dataset.Branch.pointCount()-1));solution=obj.selectBranchPoint(index);
        end
        function solution=workingSolution(obj),solution=obj.State.WorkingSolution;end
        function comparison=compareSolutions(obj,first,second),comparison=lmz.services.SolutionService().compare(obj.problem(first.ProblemId),first,second);end
        function solution=editWorkingValue(obj,name,value)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            solution=obj.State.WorkingSolution;
            if any(strcmp(name,solution.DecisionSchema.names()))
                values=solution.DecisionValues;values(solution.DecisionSchema.indexOf(name))=value;solution=solution.withDecisionValues(values);
            elseif any(strcmp(name,solution.ParameterSchema.names()))
                values=solution.ParameterValues;values(solution.ParameterSchema.indexOf(name))=value;solution=solution.withParameterValues(values);
            else,error('lmz:GUI:WorkingValue','Unknown working value %s.',name);end
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
        end
        function solution=restoreWorkingSolution(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if isempty(obj.State.LockedSelection),error('lmz:GUI:NoSelection','No locked branch point.');end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            solution=dataset.Branch.point(obj.State.LockedSelection.PointIndex);obj.invalidateDerived();obj.State.WorkingSolution=solution;
        end
        function evaluation=evaluateWorkingSolution(obj,includeSimulation)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<2,includeSimulation=false;end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            if isa(problem,'lmz.api.OptimizationProblem')
                solution=obj.State.WorkingSolution;
                [objective,terms,diagnostics]=problem.evaluateObjective( ...
                    solution.DecisionValues,solution.ParameterValues,obj.Context);
                values=objectiveValues(terms);blocks=lmz.data.ResidualBlock( ...
                    'objective_terms',values,ones(size(values)));
                diagnostics.Objective=objective;diagnostics.ObjectiveTerms=terms;
                simulation=[];
                if includeSimulation&&ismethod(problem,'simulateDecision')
                    simulation=problem.simulateDecision(solution.DecisionValues,obj.Context);
                end
                evaluation=lmz.data.ProblemEvaluation(blocks,'Simulation',simulation, ...
                    'Diagnostics',diagnostics,'Feasibility',struct('Valid',true));
            else
                evaluation=lmz.services.EvaluationService().evaluate( ...
                    problem,obj.State.WorkingSolution,includeSimulation,obj.Context);
            end
            obj.State.WorkingEvaluation=evaluation;obj.applyEvaluation(problem,evaluation);
            if includeSimulation,obj.State.CandidateSimulation=evaluation.Simulation;obj.State.Simulation=evaluation.Simulation;end
        end
        function simulation=simulateWorkingSolution(obj)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            solution=obj.State.WorkingSolution;
            if isempty(solution)||~strcmp(solution.ProblemId,obj.State.ProblemId)
                error('lmz:GUI:WorkingProblemMismatch', ...
                    'The working solution does not match selected problem %s.', ...
                    obj.State.ProblemId);
            end
            problem=obj.problem(obj.State.ProblemId);
            if isa(problem,'lmz.api.SimulationProblem')
                options=obj.simulationOptions(problem.Id);
                simulation=lmz.services.SimulationService().simulate( ...
                    problem,struct(),options,obj.Context);
            else
                simulation=lmz.services.SolutionService().simulate( ...
                    problem,solution,obj.Context);
            end
            obj.State.CandidateSimulation=simulation;
            obj.State.Simulation=simulation;
            obj.State.Status=sprintf('%s simulation complete.',obj.State.ProblemId);
        end
        function [solution,diagnostics]=projectWorkingSolution(obj,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<2,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            [solution,diagnostics]=lmz.services.SeedService().project(problem,obj.State.WorkingSolution,options,obj.Context);
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
        end
        function result=solveWorkingSolution(obj,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            obj.State.SeedPair=[];obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            result=lmz.services.SolveService().solve(problem,obj.State.WorkingSolution,options,obj.Context);
            obj.State.SolveResult=result;obj.State.SolvedSolution=result.Solution;obj.State.WorkingSolution=result.Solution;obj.State.WorkingEvaluation=result.Evaluation;obj.State.Status='Solve complete';
        end
        function solution=perturbWorkingSolution(obj,magnitude,mode,seed)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<3||isempty(mode),mode='schema-scaled';end;if nargin<4,seed=0;end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            solution=lmz.services.SeedService().perturb(problem,obj.State.WorkingSolution,magnitude,mode,seed);
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
            obj.State.Status=sprintf('Applied reproducible %s noise (seed %d).',mode,seed);
        end
        function pair=makeAdjacentSeedPair(obj,direction,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<2,direction=1;end;if nargin<3,options=struct();end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            problem=obj.problem(dataset.Branch.ProblemId);
            pair=lmz.services.SeedService().adjacentBranchPair(problem,dataset.Branch, ...
                obj.State.LockedSelection.PointIndex,direction,options,obj.Context);
            obj.State.SeedPair=pair;obj.State.Status='Adjacent RoadMap seed pair ready';
        end
        function pair=makeManualSeedPair(obj,firstIndex,secondIndex,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<4,options=struct();end
            dataset=obj.activeDataset();problem=obj.problem(dataset.Branch.ProblemId);
            pair=lmz.services.SeedService().branchPair(problem,dataset.Branch,firstIndex,secondIndex,options,obj.Context);
            obj.State.SeedPair=pair;obj.State.Status=sprintf('Manual RoadMap seed pair %d to %d ready.',firstIndex,secondIndex);
        end
        function pair=makeSecondSeed(obj,radius)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            pair=lmz.services.SeedService().makeSecondSeed(problem,obj.State.WorkingSolution,radius,struct(),obj.Context);obj.State.SeedPair=pair;
        end
        function result=runContinuation(obj,options)
            if isempty(obj.State.SeedPair),obj.makeAdjacentSeedPair(1,struct());end
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);end
            options=obj.wrapContinuationCallbacks(options);
            obj.Context.Pause.resume();problem=obj.problem(obj.State.SeedPair.First.ProblemId);obj.State.CurrentRun=struct('Kind','continuation','Context',obj.Context);
            cleanup=onCleanup(@()obj.finishCurrentRun());
            result=lmz.services.ContinuationService().run(problem,obj.State.SeedPair,options,obj.Context);
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.ContinuationResult=result;obj.State.Status='Continuation complete';clear cleanup
        end
        function pauseCurrentRun(obj)
            if isempty(obj.State.CurrentRun),return,end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.CurrentRun.Context.Pause.pause();
            obj.Events.publish(lmz.gui.PresentationEvents.RunStateChanged, ...
                struct('Busy',true,'Paused',true,'Kind',obj.State.CurrentRun.Kind));
            obj.State.Status='Run paused';
        end
        function resumeCurrentRun(obj)
            if isempty(obj.State.CurrentRun),return,end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.CurrentRun.Context.Pause.resume();
            obj.Events.publish(lmz.gui.PresentationEvents.RunStateChanged, ...
                struct('Busy',true,'Paused',false,'Kind',obj.State.CurrentRun.Kind));
            obj.State.Status='Run resumed';
        end
        function stopCurrentRun(obj)
            if isempty(obj.State.CurrentRun),return,end
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.CurrentRun.Context.Cancellation.cancel();
            obj.Events.publish(lmz.gui.PresentationEvents.RunStateChanged, ...
                struct('Busy',true,'CancellationRequested',true, ...
                'Kind',obj.State.CurrentRun.Kind));
            obj.State.Status='Stop requested';
        end
        function result=resumeCheckpoint(obj,path,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<3,options=struct();end
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);end
            problem=obj.problem('periodic_apex');result=lmz.services.ContinuationService().resumeCheckpoint(problem,path,options,obj.Context);
            obj.State.ContinuationResult=result;obj.State.Status='Checkpoint resumed';
        end
        function result=runParameterHomotopy(obj,parameterName,targets,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<4,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            result=lmz.services.ContinuationService().parameterHomotopy(problem,obj.State.WorkingSolution,parameterName,targets,options,obj.Context);
            obj.State.ContinuationResult=result;obj.State.Status='Parameter homotopy complete';
        end
        function report=runBranchFamilyScan(obj,parameterName,targets,options)
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            if nargin<4,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            report=lmz.services.ContinuationService().branchFamilyScan(problem,obj.State.WorkingSolution,parameterName,targets,options,obj.Context);
            obj.State.Status='Branch-family scan complete';
        end
        function result=runOptimization(obj,options)
            if nargin<2,options=struct();end
            id=obj.State.ProblemId;
            capabilities=obj.problemCapabilities(id);
            if ~capabilities.optimize
                error('lmz:GUI:UnsupportedOptimization', ...
                    'Selected problem %s does not support optimization.',id);
            end
            model=obj.Registry.createModel(obj.State.ModelId);
            if strcmp(id,'trajectory_fit')
                problem=model.createProblem(id,struct('EnforceConstraints',false));
                if isempty(fieldnames(options)),options=struct('Algorithm','sqp', ...
                        'MaxIterations',3,'MaxFunctionEvaluations',150, ...
                        'ConstraintTolerance',0.2,'OptimalityTolerance',1e-3, ...
                        'StepTolerance',1e-3);end
            elseif strcmp(id,'multi_stride_fit')
                problem=model.createProblem(id,struct());
                if isempty(fieldnames(options)),options=struct('Algorithm','sqp', ...
                        'MaxIterations',1,'MaxFunctionEvaluations',30, ...
                        'OptimalityTolerance',1e-5,'StepTolerance',1e-5);end
            else
                problem=model.createProblem(id,struct());
            end
            seed=obj.State.WorkingSolution;
            if isempty(seed)||~strcmp(seed.ProblemId,id)
                seed=problem.makeSolution(problem.getDecisionSchema().defaults(), ...
                    problem.getParameterSchema().defaults(),[]);
            end
            if obj.Context.Cancellation.IsCancellationRequested
                obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);
            end
            obj.Context.Pause.resume();obj.State.CurrentRun=struct('Kind','optimization','Context',obj.Context);
            cleanup=onCleanup(@()obj.finishCurrentRun());
            result=lmz.services.OptimizationService().run(problem,seed,options,obj.Context);
            presentationUpdate=obj.Events.beginTransaction(); %#ok<NASGU>
            obj.State.OptimizationResult=result;obj.State.WorkingSolution=result.Solution;
            obj.State.ProblemId=id;obj.State.Status='Optimization complete';clear cleanup
        end
        function saveBranch(~,path,branch),lmz.services.BranchService().saveNativeBranch(path,branch);end
        function exportLegacyBranch(~,path,branch),lmz.services.BranchService().exportLegacyBranch(path,branch);end
        function saveWorkingSolution(obj,path),lmz.io.ArtifactStore.save(path,obj.State.WorkingSolution.toArtifact());obj.State.Status=sprintf('Saved solution to %s.',path);end
        function recordAnimation(obj,format,path,renderer,options)
            if nargin<5,options=struct();end
            service=lmz.services.RecorderService();recordContext=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);
            obj.State.RecordingState=struct('Active',true,'Format',format,'Path',path,'Context',recordContext);
            cleanup=onCleanup(@()obj.finishRecording());
            switch lower(format)
                case 'gif',service.recordGif(renderer,path,options,recordContext);
                case {'mp4','mpeg-4'},service.recordMP4(renderer,path,options,recordContext);
                case 'keyframes',service.exportKeyframes(renderer,path, ...
                        fieldOr(options,'NormalizedTimes',[0 .25 .5 .75 1]), ...
                        recordContext,fieldOr(options,'Metadata',struct()), ...
                        fieldOr(options,'DPI',150),options);
                otherwise,error('lmz:GUI:RecordingFormat','Unknown recording format %s.',format);
            end
            clear cleanup
        end
        function recordAxesGif(obj,axesHandle,frameFcn,path,options)
            if nargin<5,options=struct();end
            recordContext=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);obj.State.RecordingState=struct('Active',true,'Format','axes-gif','Path',path,'Context',recordContext);
            cleanup=onCleanup(@()obj.finishRecording());lmz.services.RecorderService().recordAxesGif(axesHandle,frameFcn,path,options,recordContext);clear cleanup
        end
        function exportPlot(~,axesHandle,path,options)
            if nargin<4,options=struct();end
            lmz.services.RecorderService().exportPlot(axesHandle,path,options);
        end
        function stopRecording(obj),if isstruct(obj.State.RecordingState)&&isfield(obj.State.RecordingState,'Active')&&obj.State.RecordingState.Active&&isfield(obj.State.RecordingState,'Context'),obj.State.RecordingState.Context.Cancellation.cancel();end,end
        function names=bodyTrajectoryNames(obj)
            if isempty(obj.State.Simulation),names={};return,end
            available=obj.State.Simulation.StateSchema.names();candidates={{'x','y'},{'quad_x','quad_y'}};names={};
            for index=1:numel(candidates),pair=candidates{index};if all(ismember(pair,available)),names=pair;return,end,end
        end
    end
    methods (Access=private)
        function observeState(obj)
            mappings={ ...
                'ModelId',lmz.gui.PresentationEvents.ModelChanged; ...
                'ProblemId',lmz.gui.PresentationEvents.ProblemChanged; ...
                'ExampleId',lmz.gui.PresentationEvents.ExampleChanged; ...
                'RoadMapCatalog',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'Datasets',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'ActiveDatasetId',lmz.gui.PresentationEvents.DatasetsChanged; ...
                'HoverSelection',lmz.gui.PresentationEvents.HoverChanged; ...
                'LockedSelection',lmz.gui.PresentationEvents.SelectionChanged; ...
                'Selection',lmz.gui.PresentationEvents.SelectionChanged; ...
                'WorkingSolution',lmz.gui.PresentationEvents.WorkingSolutionChanged; ...
                'WorkingEvaluation',lmz.gui.PresentationEvents.WorkingSolutionChanged; ...
                'Simulation',lmz.gui.PresentationEvents.SimulationChanged; ...
                'CandidateSimulation',lmz.gui.PresentationEvents.SimulationChanged; ...
                'SolvedSolution',lmz.gui.PresentationEvents.SolveResultChanged; ...
                'SolveResult',lmz.gui.PresentationEvents.SolveResultChanged; ...
                'SeedPair',lmz.gui.PresentationEvents.SeedPairChanged; ...
                'ContinuationPreview',lmz.gui.PresentationEvents.ContinuationChanged; ...
                'ContinuationResult',lmz.gui.PresentationEvents.ContinuationChanged; ...
                'OptimizationResult',lmz.gui.PresentationEvents.OptimizationChanged; ...
                'AxisVariables',lmz.gui.PresentationEvents.BranchViewChanged; ...
                'OscillatorIndex',lmz.gui.PresentationEvents.SelectionChanged; ...
                'CurrentRun',lmz.gui.PresentationEvents.RunStateChanged; ...
                'RecordingState',lmz.gui.PresentationEvents.RunStateChanged; ...
                'Status',lmz.gui.PresentationEvents.StatusChanged; ...
                'StatusMessages',lmz.gui.PresentationEvents.StatusChanged};
            bus=obj.Events;
            for index=1:size(mappings,1)
                propertyName=mappings{index,1};topic=mappings{index,2};
                listener=addlistener(obj.State,propertyName,'PostSet', ...
                    @(~,~)bus.publish(topic,struct('Property',propertyName)));
                obj.StateListeners{end+1}=listener;
            end
        end

        function initializeGenericModel(obj,model,problemId)
            problem=model.createProblem(problemId,struct());
            obj.State.RoadMapCatalog=[];obj.State.Datasets={};
            obj.State.ActiveDatasetId='';obj.State.Selection=[];
            obj.State.LockedSelection=[];obj.State.HoverSelection=[];
            if isa(problem,'lmz.api.SimulationProblem')
                obj.State.WorkingSolution=obj.makeTutorialSolution(problemId);
            else
                obj.State.WorkingSolution=problem.makeSolution( ...
                    problem.getDecisionSchema().defaults(), ...
                    problem.getParameterSchema().defaults(),[]);
            end
            obj.State.Status=sprintf('Selected %s; no built-in branch dataset.', ...
                obj.State.ModelId);
        end

        function [problem,options]=demoProblem(obj)
            problemIds=obj.simulationProblemIds();
            if isempty(problemIds)
                error('lmz:GUI:DemoUnavailable', ...
                    ['The selected model does not provide an implemented ' ...
                    'simulation problem.']);
            end
            examples=obj.builtInExamples();
            if isempty(examples)
                problemId=problemIds{1};
                if any(strcmp(obj.State.ProblemId,problemIds))
                    problemId=obj.State.ProblemId;
                end
                options=struct();
            else
                example=lmz.services.DataService().loadBuiltInExample( ...
                    obj.State.ModelId,obj.State.ExampleId);
                problemId=char(example.problemId);
                options=example.options;
                if ~any(strcmp(problemId,problemIds))
                    error('lmz:GUI:InvalidDemoProblem', ...
                        ['Built-in example %s targets %s, which is not an ' ...
                        'implemented simulation problem for %s.'], ...
                        obj.State.ExampleId,problemId,obj.State.ModelId);
                end
            end
            model=obj.Registry.createModel(obj.State.ModelId);
            problem=model.createProblem(problemId,struct());
            if ~isa(problem,'lmz.api.SimulationProblem')
                error('lmz:GUI:InvalidDemoProblem', ...
                    ['Problem %s is declared as a simulation but does not ' ...
                    'implement lmz.api.SimulationProblem.'],problemId);
            end
        end

        function options=simulationOptions(obj,problemId)
            options=struct();
            examples=obj.builtInExamples();
            if isempty(examples),return,end
            example=lmz.services.DataService().loadBuiltInExample( ...
                obj.State.ModelId,obj.State.ExampleId);
            if strcmp(char(example.problemId),problemId)
                options=example.options;
            end
        end

        function ids=simulationProblemIds(obj)
            candidates=obj.problemIds();
            selected=false(size(candidates));
            for index=1:numel(candidates)
                descriptor=obj.Registry.getProblemDescriptor( ...
                    obj.State.ModelId,candidates{index});
                selected(index)=strcmp(descriptor.kind,'simulation')&& ...
                    descriptor.implemented&&descriptor.capabilities.simulate;
            end
            ids=candidates(selected);
        end

        function options=wrapContinuationCallbacks(obj,options)
            if nargin<2||isempty(options),options=struct();end
            prediction=fieldOr(options,'PredictionFcn',[]);
            accepted=fieldOr(options,'AcceptedFcn',[]);
            rejected=fieldOr(options,'RejectedFcn',[]);
            options.PredictionFcn=@(state)obj.continuationProgress( ...
                'prediction',state,prediction);
            options.AcceptedFcn=@(state)obj.continuationProgress( ...
                'accepted',state,accepted);
            options.RejectedFcn=@(state)obj.continuationProgress( ...
                'rejected',state,rejected);
        end

        function continuationProgress(obj,phase,state,userCallback)
            obj.State.ContinuationPreview=struct('Phase',phase,'State',state);
            if isa(userCallback,'function_handle'),userCallback(state);end
        end

        function invalidateDerived(obj)
            obj.State.WorkingEvaluation=[];obj.State.CandidateSimulation=[];obj.State.Simulation=[];
            obj.State.SolvedSolution=[];obj.State.SolveResult=[];obj.State.SeedPair=[];
            obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];obj.State.OptimizationResult=[];
        end
        function applyEvaluation(obj,problem,evaluation)
            original=obj.State.WorkingSolution;
            evaluated=problem.makeSolution(original.DecisionValues,original.ParameterValues,evaluation);
            value=evaluated.toStruct();value.Provenance=original.Provenance;value.Lineage=original.Lineage;
            obj.State.WorkingSolution=lmz.data.Solution.fromStruct(value);
        end
        function finishCurrentRun(obj)
            wasCancelled=obj.Context.Cancellation.IsCancellationRequested;seed=obj.Context.RandomSeed;obj.State.CurrentRun=[];
            if wasCancelled,obj.Context=lmz.api.RunContext.synchronous(seed);end
        end
        function finishRecording(obj),obj.State.RecordingState=struct('Active',false);end
        function dataset=findDataset(obj,id)
            dataset=[];for index=1:numel(obj.State.Datasets),if strcmp(obj.State.Datasets{index}.Id,id),dataset=obj.State.Datasets{index};break,end,end
            if isempty(dataset),error('lmz:GUI:DatasetMissing','Dataset is missing.');end
        end
        function problem=problem(obj,id),problem=obj.Registry.createModel(obj.State.ModelId).createProblem(id,struct());end
        function [dataset,index]=problemDataset(obj,problemId)
            dataset=[];index=1;
            if ~isempty(obj.State.LockedSelection)
                try
                    candidate=obj.findDataset(obj.State.LockedSelection.DatasetId);
                    if strcmp(candidate.Branch.ProblemId,problemId)
                        dataset=candidate;
                        index=min(obj.State.LockedSelection.PointIndex, ...
                            candidate.Branch.pointCount());
                        return
                    end
                catch
                end
            end
            order=1:numel(obj.State.Datasets);
            if ~isempty(obj.State.ActiveDatasetId)
                active=find(cellfun(@(item)strcmp(item.Id, ...
                    obj.State.ActiveDatasetId),obj.State.Datasets),1);
                if ~isempty(active),order=[active order(order~=active)];end
            end
            for candidateIndex=order
                candidate=obj.State.Datasets{candidateIndex};
                if strcmp(candidate.Branch.ModelId,obj.State.ModelId)&& ...
                        strcmp(candidate.Branch.ProblemId,problemId)
                    dataset=candidate;break
                end
            end
            if isempty(dataset),return,end
            if ~isempty(dataset.SourcePath)&&~isempty(obj.State.RoadMapCatalog)&& ...
                    ismethod(obj.State.RoadMapCatalog,'recommendedSeedIndex')
                try
                    index=obj.State.RoadMapCatalog.recommendedSeedIndex( ...
                        dataset.SourcePath);
                catch
                    index=1;
                end
            end
            index=max(1,min(index,dataset.Branch.pointCount()));
        end
        function solution=makeTutorialSolution(obj,problemId)
            schema=lmz.schema.VariableSchema();
            manifest=obj.Registry.getManifest(obj.State.ModelId);
            value=struct('Id',lmz.util.Ids.new('solution'), ...
                'ModelId',obj.State.ModelId,'ModelVersion',manifest.version, ...
                'ProblemId',problemId,'ProblemVersion','1.0.0', ...
                'DecisionSchema',schema,'ParameterSchema',schema, ...
                'DecisionValues',zeros(0,1),'ParameterValues',zeros(0,1), ...
                'Observables',struct(), ...
                'ResidualBlocks',lmz.data.ResidualBlock.empty(0,1), ...
                'Diagnostics',struct('Status','tutorial'), ...
                'Classification',struct(),'Feasibility',struct('Valid',true), ...
                'Lineage',struct(), ...
                'Provenance',struct('source','built-in-tutorial'), ...
                'CreatedAt',datestr(now,30));
            solution=lmz.data.Solution(value);
        end
        function datasets=writableDatasets(obj)
            datasets={};for index=1:numel(obj.State.Datasets),if ~obj.State.Datasets{index}.ReadOnly,datasets{end+1}=obj.State.Datasets{index};end,end %#ok<AGROW>
        end
    end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=onOff(condition),if condition,value='on';else,value='off';end,end
function value=linesColor(index)
colors=[0.0000 0.4470 0.7410;0.8500 0.3250 0.0980; ...
    0.9290 0.6940 0.1250;0.4940 0.1840 0.5560; ...
    0.4660 0.6740 0.1880;0.3010 0.7450 0.9330];
value=colors(1+mod(index-1,size(colors,1)),:);
end
function values=objectiveValues(terms)
names=fieldnames(terms);values=zeros(numel(names),1);
for index=1:numel(names)
    item=terms.(names{index});
    if isnumeric(item)&&isscalar(item)
        values(index)=item;
    elseif isstruct(item)&&isfield(item,'Value')&&isscalar(item.Value)
        if isfield(item,'Weight'),values(index)=item.Value*item.Weight; ...
        else,values(index)=item.Value;end
    else
        values(index)=0;
    end
end
end
