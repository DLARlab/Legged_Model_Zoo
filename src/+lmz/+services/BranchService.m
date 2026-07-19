classdef BranchService
    methods
        function branch=loadBuiltInBranch(~,registry,modelId)
            model=registry.createModel(modelId);
            if any(strcmp('periodic_apex',model.listProblems()))
                problem=model.createProblem('periodic_apex',struct()); p=problem.getParameterSchema().defaults(); speeds=linspace(0.7,1.5,7); solutions=lmz.data.Solution.empty(0,1);
                for index=1:numel(speeds),u=[speeds(index);p(1)/speeds(index)];evaluation=problem.evaluate(u,p,lmz.api.RunContext.synchronous(0),false);solutions(index,1)=problem.makeSolution(u,p,evaluation);end
            else
                problem=model.createProblem('multi_stride_fit',struct()); p=problem.getParameterSchema().defaults(); target=p(:); defaults=problem.getDecisionSchema().defaults(); solutions=lmz.data.Solution.empty(0,1);
                for index=1:7,u=defaults+(index-1)/6*(target-defaults);solutions(index,1)=problem.makeSolution(u,p,[]);end
            end
            branch=lmz.data.SolutionBranch.fromSolutions(solutions);
        end
        function dataset=addDataset(~,name,branch),dataset=lmz.data.BranchDataset(name,branch);end
        function values=coordinateValues(~,dataset,name)
            if any(strcmp(name,dataset.Branch.DecisionSchema.names())),values=dataset.Branch.decision(name);else,values=dataset.Branch.parameter(name);end
        end
        function selection=selectPoint(~,dataset,index)
            solution=dataset.Branch.point(index);selection=lmz.data.Selection(dataset.Id,index,solution.Id,'branch');
        end
        function saveNativeBranch(~,path,branch),lmz.io.ArtifactStore.save(path,branch.toArtifact());end
        function branch=loadNativeBranch(~,path),artifact=lmz.io.ArtifactStore.load(path);branch=lmz.data.SolutionBranch.fromArtifact(artifact);end
    end
end
