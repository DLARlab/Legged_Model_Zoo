classdef SolutionStore
    methods (Static)
        function saveSolution(path,solution),payload=solution.toStruct();payload.schema_version='1.0';save(path,'payload','-v7');end
        function solution=loadSolution(path),d=load(path,'payload');solution=lmz.core.Solution(d.payload);end
        function saveBranch(path,branch),payload=branch.toStruct();save(path,'payload','-v7');end
        function branch=loadBranch(path),d=load(path,'payload');s=d.payload;branch=lmz.core.SolutionBranch();branch.Id=s.id;branch.ModelId=s.model_id;branch.ProblemId=s.problem_id;branch.Points=s.points;branch.Attempts=s.attempts;branch.Metadata=s.metadata;branch.Provenance=s.provenance;end
    end
end
