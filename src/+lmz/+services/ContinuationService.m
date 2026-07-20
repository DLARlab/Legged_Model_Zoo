classdef ContinuationService
    %CONTINUATIONSERVICE Run and resume generic numerical continuation.
    methods
        function result=run(~,problem,pair,options,context)
            if isstruct(options),options=lmz.continuation.ContinuationOptions(options);end
            result=lmz.continuation.PseudoArclengthContinuation().run(problem,pair,options,context); context.progress(1,'Continuation complete');
        end
        function result=parameterHomotopy(~,problem,seed,parameterName,targets,options,context)
            result=lmz.continuation.ParameterHomotopy().run(problem,seed,parameterName,targets,options,context);
        end
        function report=branchFamilyScan(~,problem,seed,parameterName,targets,options,context)
            defaults=struct('SecondSeedRadius',0.03,'ContinuationOptions',lmz.continuation.ContinuationOptions(struct('MaximumPoints',6,'BothDirections',false)));
            if nargin>=7&&~isempty(options),if isfield(options,'SecondSeedRadius'),defaults.SecondSeedRadius=options.SecondSeedRadius;end;if isfield(options,'ContinuationOptions'),defaults.ContinuationOptions=lmz.continuation.ContinuationOptions(options.ContinuationOptions);end,end
            report=lmz.continuation.BranchFamilyScan().run(problem,seed,parameterName,targets,defaults,context);
        end
        function result=resumeCheckpoint(obj,problem,path,options,context)
            artifact=lmz.io.ArtifactStore.load(path);
            if ~strcmp(artifact.artifactType,'checkpoint')
                error('lmz:Continuation:CheckpointType','Artifact is not a continuation checkpoint.');
            end
            branch=lmz.data.SolutionBranch.fromArtifact(artifact);
            if branch.pointCount()<2,error('lmz:Continuation:CheckpointPoints','Checkpoint needs two accepted points.');end
            first=branch.point(branch.pointCount()-1);second=branch.point(branch.pointCount());
            metric=lmz.schema.DiagonalMetric(problem.scale(second.DecisionValues));
            radius=metric.norm(problem.difference(second.DecisionValues,first.DecisionValues));
            pair=lmz.data.SolutionPair(first,second,radius,radius,struct('CheckpointPath',path));
            base=artifact.algorithmOptions;callbackNames={'PredictionFcn','AcceptedFcn','RejectedFcn','AcceptanceFcn'};for callbackIndex=1:numel(callbackNames),base.(callbackNames{callbackIndex})=[];end
            if isfield(artifact,'checkpointState')&&isfield(artifact.checkpointState,'StepSize'),base.InitialStep=artifact.checkpointState.StepSize;end
            base.HistoryDecisionValues=branch.DecisionValues;
            if nargin>=4&&~isempty(options),names=fieldnames(options);for index=1:numel(names),base.(names{index})=options.(names{index});end,end
            base.BothDirections=false;base.CheckpointPath=path;
            target=base.MaximumPoints;base.MaximumPoints=max(2,target-branch.pointCount()+2);
            resumed=obj.run(problem,pair,base,context);
            if branch.pointCount()>2
                combined=branch.subset(1:branch.pointCount()-2).concatenate(resumed.Branch);
            else
                combined=resumed.Branch;
            end
            diagnostics=resumed.Diagnostics;diagnostics.ResumedFrom=path;diagnostics.CheckpointPointCount=branch.pointCount();
            sourcePair=struct('First',pair.First.toStruct(), ...
                'Second',pair.Second.toStruct(),'RequestedRadius',pair.RequestedRadius, ...
                'AchievedRadius',pair.AchievedRadius,'Diagnostics',pair.Diagnostics);
            provenance=resumed.Provenance;provenance.ResumedFrom=path;
            result=lmz.data.ContinuationResult(combined,resumed.Snapshots, ...
                resumed.TerminationReason,resumed.Options,diagnostics, ...
                sourcePair,context.RandomSeed,provenance);
            checkpoint=combined.toArtifact();checkpoint.artifactType='checkpoint';checkpoint.checkpointState=struct( ...
                'BranchId',combined.Id,'PointCount',combined.pointCount(),'StepSize',resumed.Diagnostics.finalStep,'SavedAt',datestr(now,30));
            checkpoint.algorithmOptions=lmz.continuation.ContinuationOptions(base).toStruct();checkpoint.terminationReason=resumed.TerminationReason;checkpoint.diagnostics=diagnostics;
            snapshotValues=cell(numel(resumed.Snapshots),1);
            for snapshotIndex=1:numel(resumed.Snapshots)
                snapshotValues{snapshotIndex}=resumed.Snapshots(snapshotIndex).toStruct();
            end
            checkpoint.continuationSnapshots=snapshotValues;
            checkpoint=lmz.io.ArtifactStore.withRunMetadata(checkpoint,struct( ...
                'Options',result.Options,'SourcePair',result.SourcePair, ...
                'RandomSeed',result.RandomSeed,'Provenance',result.Provenance, ...
                'ElapsedTime',NaN,'FunctionEvaluations',NaN, ...
                'TerminationReason',result.TerminationReason,'Warnings',{{}}));
            lmz.io.ArtifactStore.save(path,checkpoint);
        end
    end
end
