classdef AppController < handle
    %APPCONTROLLER Headless coordinator for demo and RoadMap workflows.
    properties (SetAccess=private)
        Registry
        State
        Context
    end
    methods
        function obj=AppController(registry,context)
            if nargin<1,registry=lmz.registry.ModelRegistry.discover();end
            if nargin<2,context=lmz.api.RunContext.synchronous(0);end
            obj.Registry=registry;obj.Context=context;obj.State=lmz.gui.AppState();
            ids=obj.Registry.listModels();obj.selectModel(ids{1});
        end
        function ids=modelIds(obj),ids=obj.Registry.listModels();end
        function selectModel(obj,modelId)
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);else,obj.Context.Pause.resume();end
            model=obj.Registry.createModel(modelId);manifest=model.getManifest();problems=model.listProblems();
            obj.State.ModelId=manifest.id;obj.State.ProblemId=problems{1};obj.State.Simulation=[];
            obj.State.CandidateSimulation=[];obj.State.Datasets={};obj.State.Selection=[];
            obj.State.LockedSelection=[];obj.State.HoverSelection=[];obj.State.WorkingSolution=[];
            obj.State.WorkingEvaluation=[];
            obj.State.SolvedSolution=[];obj.State.SolveResult=[];obj.State.SeedPair=[];
            obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            obj.State.OptimizationResult=[];obj.State.CurrentRun=[];obj.State.RecordingState=struct();
            obj.State.Status=['Selected ' manifest.id];
            if strcmp(modelId,'slip_quadruped'),obj.loadRoadMap();else,obj.loadBuiltInBranch();end
        end
        function ids=problemIds(obj),ids=obj.Registry.createModel(obj.State.ModelId).listProblems();end
        function examples=builtInExamples(obj),examples=lmz.services.DataService().listBuiltInExamples(obj.State.ModelId);end
        function result=simulate(obj,options)
            dataService=lmz.services.DataService();example=dataService.loadBuiltInExample(obj.State.ModelId,obj.State.ExampleId);
            if nargin<2||isempty(fieldnames(options)),options=example.options;end
            model=obj.Registry.createModel(obj.State.ModelId);problem=model.createProblem('demo_stride',struct());
            result=lmz.services.SimulationService().simulate(problem,struct(),options,obj.Context);
            obj.State.Simulation=result;obj.State.Status='Demonstration simulation complete';
        end
        function capabilities=capabilities(obj),capabilities=obj.Registry.createModel(obj.State.ModelId).getCapabilities();end

        function dataset=loadBuiltInBranch(obj)
            branch=lmz.services.BranchService().loadBuiltInBranch(obj.Registry,obj.State.ModelId);
            dataset=lmz.data.BranchDataset([obj.State.ModelId ' built-in'],branch,'ReadOnly',true);
            obj.State.Datasets={dataset};obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=loadRoadMap(obj,file)
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
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();obj.State.RoadMapCatalog=catalog;
            datasets=lmz.services.BranchService().loadAllRoadMapBranches(obj.problem('periodic_apex'));
            obj.State.Datasets=[datasets obj.writableDatasets()];obj.State.ActiveDatasetId=datasets{1}.Id;
            obj.lockBranchPoint(datasets{1}.Id,catalog.recommendedSeedIndex(datasets{1}.SourcePath));
            obj.State.Status=sprintf('All %d RoadMap branches loaded.',numel(datasets));
        end
        function dataset=openBranch(obj,path)
            variables=whos('-file',path);names={variables.name};service=lmz.services.BranchService();
            if numel(names)==1&&strcmp(names{1},'artifact')
                branch=service.loadNativeBranch(path);readOnly=false;
            elseif any(strcmp(names,'results'))
                branch=lmzmodels.slip_quadruped.Results29Adapter.loadBranch(path,obj.problem('periodic_apex'));readOnly=true;
            else,error('lmz:GUI:BranchFile','MAT file is neither a native artifact nor Results29 branch.');end
            [~,name,extension]=fileparts(path);style=struct();classification=branch.Classifications{1};if isfield(classification,'Color'),style.Color=classification.Color;end;if isfield(classification,'LineStyle'),style.LineStyle=classification.LineStyle;end
            dataset=lmz.data.BranchDataset([name extension],branch,'SourcePath',path,'ReadOnly',readOnly,'DisplayStyle',style,'Metadata',struct('Status','user-loaded','PointCount',branch.pointCount()));
            obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function datasets=openBranchFolder(obj,folder)
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
            dataset=obj.activeDataset();path=dataset.SourcePath;
            if isempty(path)||exist(path,'file')~=2,error('lmz:GUI:ReloadPath','The active dataset has no reloadable source file.');end
            variables=whos('-file',path);names={variables.name};service=lmz.services.BranchService();
            if any(strcmp(names,'results'))
                branch=service.reloadLegacySource(obj.problem('periodic_apex'),path);
            elseif numel(names)==1&&strcmp(names{1},'artifact')
                branch=service.loadNativeBranch(path);
            else
                error('lmz:GUI:ReloadType','The active dataset source is not a supported branch file.');
            end
            oldIndex=1;if ~isempty(obj.State.LockedSelection)&&strcmp(obj.State.LockedSelection.DatasetId,dataset.Id),oldIndex=obj.State.LockedSelection.PointIndex;end
            dataset.Branch=branch;dataset.Metadata.PointCount=branch.pointCount();
            obj.lockBranchPoint(dataset.Id,min(oldIndex,branch.pointCount()));
            obj.State.Status=sprintf('Reloaded %s from disk.',dataset.Name);
        end
        function removeDataset(obj,datasetId)
            keep=true(1,numel(obj.State.Datasets));for index=1:numel(obj.State.Datasets),if strcmp(obj.State.Datasets{index}.Id,datasetId),keep(index)=false;end,end
            obj.State.Datasets=obj.State.Datasets(keep);
            if isempty(obj.State.Datasets),obj.State.ActiveDatasetId='';obj.State.LockedSelection=[];obj.State.Selection=[];obj.State.WorkingSolution=[];obj.invalidateDerived();return,end
            obj.State.ActiveDatasetId=obj.State.Datasets{1}.Id;obj.lockBranchPoint(obj.State.ActiveDatasetId,1);
        end
        function setDatasetVisibility(obj,datasetId,visible),dataset=obj.findDataset(datasetId);dataset.Visible=logical(visible);obj.State.Status=sprintf('%s visibility: %s.',dataset.Name,onOff(dataset.Visible));end
        function dataset=plotDataset(obj,datasetId,visible),if nargin<3,visible=true;end;dataset=obj.findDataset(datasetId);obj.setDatasetVisibility(datasetId,visible);end
        function dataset=addWorkingSolutionToDataset(obj,name)
            solution=obj.State.WorkingSolution;
            if isempty(solution),error('lmz:GUI:NoWorkingSolution','No working solution is available.');end
            branch=lmz.data.SolutionBranch.fromSolutions(solution);dataset=lmz.data.BranchDataset(name,branch,'ReadOnly',false,'Metadata',struct('Status','working/user'));obj.State.Datasets{end+1}=dataset;obj.State.ActiveDatasetId=dataset.Id;obj.lockBranchPoint(dataset.Id,1);
        end
        function dataset=addBranchDataset(obj,name,branch)
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
            dataset=obj.findDataset(datasetId);obj.State.ActiveDatasetId=dataset.Id;
            index=1;if ~isempty(obj.State.LockedSelection)&&strcmp(obj.State.LockedSelection.DatasetId,dataset.Id),index=obj.State.LockedSelection.PointIndex;end
            obj.lockBranchPoint(dataset.Id,index);
        end
        function setAxisVariables(obj,x,y,z)
            dataset=obj.activeDataset();known=dataset.Branch.coordinateNames();
            values={x,y};if nargin>=4&&~isempty(z),values{3}=z;else,values{3}='';end
            for index=1:2+(~isempty(values{3})),if ~any(strcmp(values{index},known)),error('lmz:GUI:AxisVariable','Unknown coordinate %s.',values{index});end,end
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
            solution=obj.State.WorkingSolution;
            if any(strcmp(name,solution.DecisionSchema.names()))
                values=solution.DecisionValues;values(solution.DecisionSchema.indexOf(name))=value;solution=solution.withDecisionValues(values);
            elseif any(strcmp(name,solution.ParameterSchema.names()))
                values=solution.ParameterValues;values(solution.ParameterSchema.indexOf(name))=value;solution=solution.withParameterValues(values);
            else,error('lmz:GUI:WorkingValue','Unknown working value %s.',name);end
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
        end
        function solution=restoreWorkingSolution(obj)
            if isempty(obj.State.LockedSelection),error('lmz:GUI:NoSelection','No locked branch point.');end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            solution=dataset.Branch.point(obj.State.LockedSelection.PointIndex);obj.invalidateDerived();obj.State.WorkingSolution=solution;
        end
        function evaluation=evaluateWorkingSolution(obj,includeSimulation)
            if nargin<2,includeSimulation=false;end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            evaluation=lmz.services.EvaluationService().evaluate(problem,obj.State.WorkingSolution,includeSimulation,obj.Context);
            obj.State.WorkingEvaluation=evaluation;obj.applyEvaluation(problem,evaluation);
            if includeSimulation,obj.State.CandidateSimulation=evaluation.Simulation;obj.State.Simulation=evaluation.Simulation;end
        end
        function simulation=simulateWorkingSolution(obj)
            solution=obj.State.WorkingSolution;problem=obj.problem(solution.ProblemId);
            simulation=lmz.services.SolutionService().simulate(problem,solution,obj.Context);
            obj.State.CandidateSimulation=simulation;obj.State.Simulation=simulation;obj.State.Status='Selected RoadMap point simulated';
        end
        function [solution,diagnostics]=projectWorkingSolution(obj,options)
            if nargin<2,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            [solution,diagnostics]=lmz.services.SeedService().project(problem,obj.State.WorkingSolution,options,obj.Context);
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
        end
        function result=solveWorkingSolution(obj,options)
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            obj.State.SeedPair=[];obj.State.ContinuationPreview=[];obj.State.ContinuationResult=[];
            result=lmz.services.SolveService().solve(problem,obj.State.WorkingSolution,options,obj.Context);
            obj.State.SolveResult=result;obj.State.SolvedSolution=result.Solution;obj.State.WorkingSolution=result.Solution;obj.State.WorkingEvaluation=result.Evaluation;obj.State.Status='Solve complete';
        end
        function solution=perturbWorkingSolution(obj,magnitude,mode,seed)
            if nargin<3||isempty(mode),mode='schema-scaled';end;if nargin<4,seed=0;end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            solution=lmz.services.SeedService().perturb(problem,obj.State.WorkingSolution,magnitude,mode,seed);
            obj.invalidateDerived();obj.State.WorkingSolution=solution.withoutDerivedData();
            obj.State.Status=sprintf('Applied reproducible %s noise (seed %d).',mode,seed);
        end
        function pair=makeAdjacentSeedPair(obj,direction,options)
            if nargin<2,direction=1;end;if nargin<3,options=struct();end
            dataset=obj.findDataset(obj.State.LockedSelection.DatasetId);
            problem=obj.problem(dataset.Branch.ProblemId);
            pair=lmz.services.SeedService().adjacentBranchPair(problem,dataset.Branch, ...
                obj.State.LockedSelection.PointIndex,direction,options,obj.Context);
            obj.State.SeedPair=pair;obj.State.Status='Adjacent RoadMap seed pair ready';
        end
        function pair=makeManualSeedPair(obj,firstIndex,secondIndex,options)
            if nargin<4,options=struct();end
            dataset=obj.activeDataset();problem=obj.problem(dataset.Branch.ProblemId);
            pair=lmz.services.SeedService().branchPair(problem,dataset.Branch,firstIndex,secondIndex,options,obj.Context);
            obj.State.SeedPair=pair;obj.State.Status=sprintf('Manual RoadMap seed pair %d to %d ready.',firstIndex,secondIndex);
        end
        function pair=makeSecondSeed(obj,radius)
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            pair=lmz.services.SeedService().makeSecondSeed(problem,obj.State.WorkingSolution,radius,struct(),obj.Context);obj.State.SeedPair=pair;
        end
        function result=runContinuation(obj,options)
            if isempty(obj.State.SeedPair),obj.makeAdjacentSeedPair(1,struct());end
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);end
            obj.Context.Pause.resume();problem=obj.problem(obj.State.SeedPair.First.ProblemId);obj.State.CurrentRun=struct('Kind','continuation','Context',obj.Context);
            cleanup=onCleanup(@()obj.finishCurrentRun());
            result=lmz.services.ContinuationService().run(problem,obj.State.SeedPair,options,obj.Context);
            obj.State.ContinuationResult=result;obj.State.Status='Continuation complete';clear cleanup
        end
        function pauseCurrentRun(obj),if ~isempty(obj.State.CurrentRun),obj.State.CurrentRun.Context.Pause.pause();obj.State.Status='Run paused';end,end
        function resumeCurrentRun(obj),if ~isempty(obj.State.CurrentRun),obj.State.CurrentRun.Context.Pause.resume();obj.State.Status='Run resumed';end,end
        function stopCurrentRun(obj),if ~isempty(obj.State.CurrentRun),obj.State.CurrentRun.Context.Cancellation.cancel();obj.State.Status='Stop requested';end,end
        function result=resumeCheckpoint(obj,path,options)
            if nargin<3,options=struct();end
            if obj.Context.Cancellation.IsCancellationRequested,obj.Context=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);end
            problem=obj.problem('periodic_apex');result=lmz.services.ContinuationService().resumeCheckpoint(problem,path,options,obj.Context);
            obj.State.ContinuationResult=result;obj.State.Status='Checkpoint resumed';
        end
        function result=runParameterHomotopy(obj,parameterName,targets,options)
            if nargin<4,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            result=lmz.services.ContinuationService().parameterHomotopy(problem,obj.State.WorkingSolution,parameterName,targets,options,obj.Context);
            obj.State.ContinuationResult=result;obj.State.Status='Parameter homotopy complete';
        end
        function report=runBranchFamilyScan(obj,parameterName,targets,options)
            if nargin<4,options=struct();end
            problem=obj.problem(obj.State.WorkingSolution.ProblemId);
            report=lmz.services.ContinuationService().branchFamilyScan(problem,obj.State.WorkingSolution,parameterName,targets,options,obj.Context);
            obj.State.Status='Branch-family scan complete';
        end
        function result=runOptimization(obj,options)
            model=obj.Registry.createModel(obj.State.ModelId);problems=model.listProblems();if any(strcmp(problems,'trajectory_fit')),id='trajectory_fit';else,id='multi_stride_fit';end
            problem=model.createProblem(id,struct());seed=problem.makeSolution(problem.getDecisionSchema().defaults(),[],[]);
            result=lmz.services.OptimizationService().run(problem,seed,options,obj.Context);obj.State.OptimizationResult=result;obj.State.WorkingSolution=result.Solution;obj.State.Status='Optimization complete';
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
                case 'keyframes',service.exportKeyframes(renderer,path,fieldOr(options,'NormalizedTimes',[0 .25 .5 .75 1]),recordContext);
                otherwise,error('lmz:GUI:RecordingFormat','Unknown recording format %s.',format);
            end
            clear cleanup
        end
        function recordAxesGif(obj,axesHandle,frameFcn,path,options)
            if nargin<5,options=struct();end
            recordContext=lmz.api.RunContext.synchronous(obj.Context.RandomSeed);obj.State.RecordingState=struct('Active',true,'Format','axes-gif','Path',path,'Context',recordContext);
            cleanup=onCleanup(@()obj.finishRecording());lmz.services.RecorderService().recordAxesGif(axesHandle,frameFcn,path,options,recordContext);clear cleanup
        end
        function exportPlot(~,axesHandle,path),lmz.services.RecorderService().exportPlot(axesHandle,path);end
        function stopRecording(obj),if isstruct(obj.State.RecordingState)&&isfield(obj.State.RecordingState,'Active')&&obj.State.RecordingState.Active&&isfield(obj.State.RecordingState,'Context'),obj.State.RecordingState.Context.Cancellation.cancel();end,end
        function names=bodyTrajectoryNames(obj)
            if isempty(obj.State.Simulation),names={};return,end
            available=obj.State.Simulation.StateSchema.names();candidates={{'x','y'},{'quad_x','quad_y'}};names={};
            for index=1:numel(candidates),pair=candidates{index};if all(ismember(pair,available)),names=pair;return,end,end
        end
    end
    methods (Access=private)
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
        function datasets=writableDatasets(obj)
            datasets={};for index=1:numel(obj.State.Datasets),if ~obj.State.Datasets{index}.ReadOnly,datasets{end+1}=obj.State.Datasets{index};end,end %#ok<AGROW>
        end
    end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=onOff(condition),if condition,value='on';else,value='off';end,end
