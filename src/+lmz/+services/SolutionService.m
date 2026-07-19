classdef SolutionService
    methods
        function solution=solutionFromSelection(~,datasets,selection)
            dataset=[];for index=1:numel(datasets),if strcmp(datasets{index}.Id,selection.DatasetId),dataset=datasets{index};break,end,end
            if isempty(dataset),error('lmz:SolutionService:Dataset','Selection dataset is missing.');end
            solution=dataset.Branch.point(selection.PointIndex);
        end
        function value=workingCopy(~,solution),value=solution.withDecisionValues(solution.DecisionValues);end
        function report=validate(~,problem,solution),report=problem.validateSolution(solution);end
        function result=simulate(~,problem,solution,context)
            request=problem.toSimulationRequest(solution.DecisionValues,solution.ParameterValues,struct());result=problem.Model.simulate(request,context);
        end
        function comparison=compare(~,problem,first,second)
            comparison=struct('decisionDifference',problem.difference(second.DecisionValues,first.DecisionValues), ...
                'parameterDifference',second.ParameterValues-first.ParameterValues);
        end
    end
end
