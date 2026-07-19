classdef PseudoArclengthContinuation
    methods
        function result=run(~,problem,pair,options,context)
            if isstruct(options),options=lmz.continuation.ContinuationOptions(options);end
            forward=trace(pair.First,pair.Second,options.MaximumPoints); solutions=forward;
            if options.BothDirections
                backward=trace(pair.Second,pair.First,max(2,ceil(options.MaximumPoints/2))); backward=backward(end:-1:2); solutions=[backward,forward]; %#ok<AGROW>
            end
            branch=lmz.data.SolutionBranch.fromSolutions(solutions); snapshots=lmz.data.ContinuationSnapshot.empty(0,1);
            for index=1:numel(solutions),snapshots(index,1)=lmz.data.ContinuationSnapshot(index,solutions(index),options.InitialStep,[],true,struct());end
            result=lmz.data.ContinuationResult(branch,snapshots,'maximum_points',options.toStruct(),struct('acceptedPoints',numel(solutions)));
            function values=trace(first,second,count)
                values=[first,second]; step=options.InitialStep;
                while numel(values)<count
                    context.check(); [prediction,tangent]=lmz.continuation.SecantPredictor.predict(problem,values(end-1).DecisionValues,values(end).DecisionValues,step);
                    [corrected,exitFlag,output,residualNorm]=lmz.continuation.PseudoArclengthCorrector().correct(problem,prediction,tangent,values(end).ParameterValues,options,context);
                    if exitFlag<=0||residualNorm>options.CorrectorTolerance*10
                        step=step/2; if step<options.MinimumStep,break,end; continue
                    end
                    solution=problem.makeSolution(corrected,values(end).ParameterValues,problem.evaluate(corrected,values(end).ParameterValues,context,false));
                    if lmz.schema.DiagonalMetric(problem.scale(corrected)).norm(problem.difference(solution.DecisionValues,values(end).DecisionValues))<options.DuplicateTolerance,break,end
                    values(end+1)=solution; %#ok<AGROW>
                    step=min(options.MaximumStep,step*1.2); context.progress(numel(values)/count,sprintf('Accepted continuation point %d',numel(values))); context.checkpoint(struct('decision',corrected,'step',step,'output',output));
                end
            end
        end
    end
end
