classdef ParameterHomotopy
    methods
        function result=run(~,problem,seed,parameterName,targets,options,context) %#ok<INUSD>
            parameterIndex=problem.getParameterSchema().indexOf(parameterName);solutions=lmz.data.Solution.empty(0,1);current=seed;
            for index=1:numel(targets)
                values=current.ParameterValues;values(parameterIndex)=targets(index);candidate=current.withParameterValues(values);
                solved=lmz.services.SolveService().solve(problem,candidate,struct('AcceptExistingTolerance',1e-7),context);current=solved.Solution;solutions(index,1)=current;context.progress(index/numel(targets),sprintf('Homotopy target %d',index));
            end
            result=struct('ParameterName',parameterName,'Targets',targets(:)','Solutions',solutions, ...
                'Branch',lmz.data.SolutionBranch.fromSolutions(solutions),'Completed',numel(solutions));
        end
    end
end
