classdef PseudoArclengthContinuation
    %PSEUDOARCLENGTHCONTINUATION Adaptive, callback/checkpoint-aware tracing.
    methods
        function result=run(~,problem,pair,options,context)
            if isstruct(options),options=lmz.continuation.ContinuationOptions(options);end
            forwardCount=options.MaximumPoints;
            if options.BothDirections,forwardCount=max(2,ceil((options.MaximumPoints+2)/2));end
            [forward,forwardSnapshots,reason,stats]=trace(pair.First,pair.Second,forwardCount,+1);
            solutions=forward;snapshots=forwardSnapshots;
            if options.BothDirections&&~strcmp(reason,'controlled_stop')
                backwardCount=max(2,options.MaximumPoints-forwardCount+2);
                [backward,backSnapshots,backReason,backStats]=trace(pair.Second,pair.First,backwardCount,-1);
                if numel(backward)>2,backward=backward(end:-1:3);else,backward=lmz.data.Solution.empty(1,0);end
                solutions=[backward,forward]; %#ok<AGROW>
                snapshots=[backSnapshots;forwardSnapshots]; %#ok<AGROW>
                stats.Accepted=stats.Accepted+backStats.Accepted-1;stats.Rejected=stats.Rejected+backStats.Rejected;
                if ~strcmp(backReason,'maximum_points'),reason=['backward_' backReason];end
            end
            branch=lmz.data.SolutionBranch.fromSolutions(solutions);
            diagnostics=struct('acceptedPoints',numel(solutions),'rejectedAttempts',stats.Rejected, ...
                'finalStep',stats.FinalStep,'direction',stats.Direction, ...
                'partialBranchPreserved',true);
            result=lmz.data.ContinuationResult(branch,snapshots,reason,options.toStruct(),diagnostics);
            if ~isempty(options.CheckpointPath)
                saveCheckpoint(options.CheckpointPath,branch,options, ...
                    stats.FinalStep,reason,snapshots);
            end

            function [values,localSnapshots,termination,traceStats]=trace(first,second,count,directionSign)
                values=[first,second];step=min(options.MaximumStep,max(options.MinimumStep,options.InitialStep));
                lifted=initializeLiftedHistory(problem,first,second,options.HistoryDecisionValues);
                localSnapshots=lmz.data.ContinuationSnapshot.empty(0,1);
                seedDiagnostics=struct('Seed',true,'Direction',directionSign, ...
                    'CheckpointPath',options.CheckpointPath, ...
                    'Feasibility',first.Feasibility,'Gait',first.Classification);
                localSnapshots(1,1)=lmz.data.ContinuationSnapshot( ...
                    1,first,step,[],true,seedDiagnostics);
                seedDiagnostics.Feasibility=second.Feasibility;
                seedDiagnostics.Gait=second.Classification;
                localSnapshots(2,1)=lmz.data.ContinuationSnapshot( ...
                    2,second,step,[],true,seedDiagnostics);
                rejected=0;backtracks=0;termination='maximum_points';previousTangent=[];
                while numel(values)<count
                    try
                        context.check();
                    catch exception
                        if strcmp(exception.identifier,'lmz:Cancelled'),termination='controlled_stop';break,end
                        rethrow(exception)
                    end
                    [prediction,tangent]=lmz.continuation.SecantPredictor.predict(problem, ...
                        values(end-1).DecisionValues,values(end).DecisionValues,step);
                    preview=struct('Kind','prediction','PointIndex',numel(values)+1, ...
                        'DecisionValues',prediction,'Tangent',tangent,'StepSize',step, ...
                        'Direction',directionSign);
                    notify(options.PredictionFcn,preview);
                    accepted=false;exitFlag=-1;output=struct();residualNorm=Inf;
                    corrected=[];failure='';solution=[];
                    feasibility=struct('Status','not-evaluated');gait=struct();
                    try
                        [corrected,exitFlag,output,residualNorm]= ...
                            lmz.continuation.PseudoArclengthCorrector().correct( ...
                            problem,prediction,tangent,values(end).ParameterValues,options,context);
                        accepted=exitFlag>0&&isfinite(residualNorm)&&residualNorm<=options.CorrectorTolerance*10;
                        if ~accepted,failure='corrector';end
                    catch exception
                        if strcmp(exception.identifier,'lmz:Cancelled')
                            failure='controlled-stop';termination='controlled_stop';
                        else
                            failure=['exception:' exception.identifier];
                        end
                        output=struct('message',exception.message);
                    end
                    if accepted
                        try
                            evaluation=problem.evaluate(corrected,values(end).ParameterValues,context,false);
                            solution=problem.makeSolution(corrected,values(end).ParameterValues,evaluation);
                            feasibility=solution.Feasibility;gait=solution.Classification;
                            if options.RequireFeasible&&isstruct(solution.Feasibility)&& ...
                                    isfield(solution.Feasibility,'Valid')&&~solution.Feasibility.Valid
                                accepted=false;failure='feasibility';
                            end
                            if accepted&&~isempty(options.AcceptanceFcn)
                                accepted=logical(options.AcceptanceFcn(solution,values));
                                if ~accepted,failure='acceptance-policy';end
                            end
                            if accepted&&isprop(problem,'Continuation')&&~isempty(problem.Continuation)
                                [accepted,policyReason]=problem.Continuation.accepts(values(end),solution);
                                if ~accepted,failure=['model-policy:' policyReason];end
                            end
                        catch exception
                            accepted=false;
                            if strcmp(exception.identifier,'lmz:Cancelled')
                                failure='controlled-stop';termination='controlled_stop';
                            else
                                failure=['exception:' exception.identifier];
                                output=struct('message',exception.message);
                            end
                        end
                    end
                    if strcmp(termination,'controlled_stop')
                        rejected=rejected+1;
                        diagnostics=attemptDiagnostics(prediction,corrected, ...
                            residualNorm,NaN,output,backtracks,feasibility,gait, ...
                            'controlled_stop',failure,directionSign,NaN,exitFlag);
                        localSnapshots(end+1,1)=lmz.data.ContinuationSnapshot( ...
                            numel(values)+1,values(end),step,tangent,false,diagnostics); %#ok<AGROW>
                        notify(options.RejectedFcn,rejectedState(diagnostics, ...
                            numel(values)+1,step,prediction,directionSign,failure));
                        break
                    end
                    if accepted
                        metric=lmz.schema.DiagonalMetric(problem.scale(corrected));
                        candidateLift=lifted(:,end)+problem.difference(solution.DecisionValues,values(end).DecisionValues);
                        distances=zeros(1,size(lifted,2));
                        for historyIndex=1:size(lifted,2),distances(historyIndex)=metric.norm(candidateLift-lifted(:,historyIndex));end
                        if any(distances<options.DuplicateTolerance)
                            termination='duplicate';rejected=rejected+1;
                            diagnostics=attemptDiagnostics(prediction,corrected, ...
                                residualNorm,NaN,output,backtracks,feasibility,gait, ...
                                termination,'history-duplicate',directionSign,NaN,exitFlag);
                            localSnapshots(end+1,1)=lmz.data.ContinuationSnapshot( ...
                                numel(values)+1,solution,step,tangent,false,diagnostics); %#ok<AGROW>
                            notify(options.RejectedFcn,rejectedState(diagnostics, ...
                                numel(values)+1,step,prediction,directionSign, ...
                                'history-duplicate'));
                            break
                        end
                        segmentCount=size(lifted,2)-3;loopDistance=Inf;
                        for segmentIndex=1:segmentCount
                            loopDistance=min(loopDistance,segmentDistance(metric,candidateLift,lifted(:,segmentIndex),lifted(:,segmentIndex+1)));
                        end
                        values(end+1)=solution;lifted(:,end+1)=candidateLift; %#ok<AGROW>
                        terminationCandidate='';
                        if loopDistance<options.LoopClosureTolerance
                            termination='loop_closure';terminationCandidate=termination;
                        end
                        achieved=metric.norm(lifted(:,end)-lifted(:,end-1));
                        newTangent=(lifted(:,end)-lifted(:,end-1))/max(achieved,eps);
                        curvature=0;
                        if ~isempty(previousTangent),curvature=metric.norm(newTangent-previousTangent);end
                        previousTangent=newTangent;acceptedBacktracks=backtracks;backtracks=0;
                        if isempty(terminationCandidate)&&size(lifted,2)>=options.StagnationWindow
                            firstWindow=size(lifted,2)-options.StagnationWindow+1;
                            net=metric.norm(lifted(:,end)-lifted(:,firstWindow));
                            if net<options.DuplicateTolerance*options.StagnationWindow
                                termination='stagnation';terminationCandidate=termination;
                            end
                        end
                        if isempty(terminationCandidate)&&numel(values)>=count
                            terminationCandidate='maximum_points';
                        end
                        diagnostics=attemptDiagnostics(prediction,corrected, ...
                            residualNorm,curvature,output,acceptedBacktracks, ...
                            feasibility,gait,terminationCandidate,'', ...
                            directionSign,achieved,exitFlag);
                        localSnapshots(end+1,1)=lmz.data.ContinuationSnapshot(numel(values),solution,step,tangent,true,diagnostics); %#ok<AGROW>
                        notify(options.AcceptedFcn,struct('Kind','accepted','Solution',solution, ...
                            'PointIndex',numel(values),'StepSize',step,'ResidualNorm',residualNorm, ...
                            'Tangent',tangent,'Prediction',prediction,'Direction',directionSign, ...
                            'Curvature',curvature,'CorrectorIterations',diagnostics.CorrectorIterations, ...
                            'BacktrackingCount',acceptedBacktracks, ...
                            'TerminationCandidate',terminationCandidate));
                        if curvature>options.CurvatureThreshold,step=max(options.MinimumStep,step*options.ShrinkFactor);else,step=min(options.MaximumStep,step*options.GrowthFactor);end
                        context.progress(numel(values)/count,sprintf('Accepted continuation point %d',numel(values)));
                        checkpointState=struct('decision',corrected,'step',step,'output',output,'pointCount',numel(values));context.checkpoint(checkpointState);
                        if ~isempty(options.CheckpointPath),saveCheckpoint( ...
                                options.CheckpointPath,lmz.data.SolutionBranch.fromSolutions(values), ...
                                options,step,'running',localSnapshots);end
                        if any(strcmp(termination,{'loop_closure','stagnation'})),break,end
                    else
                        rejected=rejected+1;backtracks=backtracks+1;
                        nextStep=step*options.ShrinkFactor;terminationCandidate='';
                        if nextStep<options.MinimumStep
                            termination='minimum_step';terminationCandidate=termination;
                        elseif backtracks>=options.MaxBacktracks
                            termination='maximum_backtracks';terminationCandidate=termination;
                        end
                        diagnostics=attemptDiagnostics(prediction,corrected, ...
                            residualNorm,NaN,output,backtracks,feasibility,gait, ...
                            terminationCandidate,failure,directionSign,NaN,exitFlag);
                        snapshotSolution=values(end);if ~isempty(solution),snapshotSolution=solution;end
                        localSnapshots(end+1,1)=lmz.data.ContinuationSnapshot(numel(values)+1,snapshotSolution,step,tangent,false,diagnostics); %#ok<AGROW>
                        notify(options.RejectedFcn,rejectedState(diagnostics, ...
                            numel(values)+1,step,prediction,directionSign,failure));
                        step=nextStep;
                        if ~isempty(terminationCandidate),break,end
                    end
                end
                traceStats=struct('Accepted',numel(values),'Rejected',rejected,'FinalStep',step,'Direction',directionSign);
            end

            function notify(callback,state)
                if isempty(callback)||~isa(callback,'function_handle'),return,end
                try,callback(state);catch exception,context.log('warning',['Continuation callback failed: ' exception.message]);end
            end

            function value=attemptDiagnostics(prediction,corrected,residualNorm, ...
                    curvature,output,backtrackCount,feasibility,gait, ...
                    terminationCandidate,failure,directionSign,achieved,exitFlag)
                value=struct('Predictor',prediction, ...
                    'CorrectedDecision',corrected,'ResidualNorm',residualNorm, ...
                    'Curvature',curvature, ...
                    'CorrectorIterations',correctorIterations(output), ...
                    'BacktrackingCount',backtrackCount, ...
                    'Feasibility',feasibility,'Gait',gait, ...
                    'TerminationCandidate',terminationCandidate, ...
                    'CheckpointPath',options.CheckpointPath, ...
                    'ExitFlag',exitFlag,'CorrectorOutput',output, ...
                    'Failure',failure,'Direction',directionSign, ...
                    'AchievedStep',achieved,'Seed',false);
            end

            function value=rejectedState(diagnostics,pointIndex,stepSize, ...
                    prediction,directionSign,failure)
                value=struct('Kind','rejected','PointIndex',pointIndex, ...
                    'StepSize',stepSize,'ResidualNorm',diagnostics.ResidualNorm, ...
                    'Reason',failure,'Prediction',prediction, ...
                    'CorrectedDecision',diagnostics.CorrectedDecision, ...
                    'CorrectorIterations',diagnostics.CorrectorIterations, ...
                    'BacktrackingCount',diagnostics.BacktrackingCount, ...
                    'TerminationCandidate',diagnostics.TerminationCandidate, ...
                    'Direction',directionSign);
            end
        end
    end
end

function lifted=initializeLiftedHistory(problem,first,second,history)
if isempty(history),history=[first.DecisionValues second.DecisionValues];end
if ~isnumeric(history)||size(history,1)~=numel(first.DecisionValues)||size(history,2)<2||any(~isfinite(history(:)))
    error('lmz:Continuation:History','Continuation history has an invalid shape or value.');
end
metric=lmz.schema.DiagonalMetric(problem.scale(second.DecisionValues));
if metric.norm(problem.difference(history(:,end-1),first.DecisionValues))>1e-7||metric.norm(problem.difference(history(:,end),second.DecisionValues))>1e-7
    error('lmz:Continuation:HistorySeed','Continuation history does not end at the seed pair.');
end
lifted=zeros(size(history));lifted(:,1)=history(:,1);
for index=2:size(history,2),lifted(:,index)=lifted(:,index-1)+problem.difference(history(:,index),history(:,index-1));end
end

function distance=segmentDistance(metric,point,first,second)
segment=second-first;denominator=metric.inner(segment,segment);
if denominator<=eps,distance=metric.norm(point-first);return,end
fraction=max(0,min(1,metric.inner(point-first,segment)/denominator));projection=first+fraction*segment;distance=metric.norm(point-projection);
end

function value=correctorIterations(output)
value=NaN;
if isstruct(output)&&isfield(output,'iterations')&& ...
        isnumeric(output.iterations)&&isscalar(output.iterations)
    value=output.iterations;
end
end

function saveCheckpoint(path,branch,options,step,reason,snapshots)
artifact=branch.toArtifact();artifact.artifactType='checkpoint';
artifact.checkpointState=struct('BranchId',branch.Id,'PointCount',branch.pointCount(), ...
    'StepSize',step,'SavedAt',datestr(now,30));artifact.algorithmOptions=options.toStruct();
artifact.terminationReason=reason;artifact.diagnostics=struct('TerminationReason',reason, ...
    'PointCount',branch.pointCount(),'StepSize',step);
snapshotValues=cell(numel(snapshots),1);
for index=1:numel(snapshots),snapshotValues{index}=snapshots(index).toStruct();end
artifact.continuationSnapshots=snapshotValues;
lmz.io.ArtifactStore.save(path,artifact);
end
