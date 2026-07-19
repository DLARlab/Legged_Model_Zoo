classdef EvaluationService
    %EVALUATIONSERVICE Generic deterministic problem evaluation boundary.
    methods
        function evaluation=evaluate(~,problem,solution,includeSimulation,context)
            if ~isa(problem,'lmz.api.BaseProblem')||~isa(solution,'lmz.data.Solution')
                error('lmz:Services:EvaluationInput','Evaluation requires a problem and Solution.');
            end
            context.check();
            evaluation=problem.evaluate(solution.DecisionValues,solution.ParameterValues, ...
                context,includeSimulation);
        end
    end
end
