classdef FoldProblem < lmz.problems.NonlinearProblem
    methods
        function m=metadata(~),m=struct('id','fold','model_id','analytic_fold','version','1.0');end
        function s=decisionSchema(~),e(1)=lmz.core.NamedVectorSchema.entry('x','x','analytic','1',-1,-3,3,1);e(2)=lmz.core.NamedVectorSchema.entry('lambda','lambda','parameter','1',1,-1,9,1);s=lmz.core.NamedVectorSchema(e);end
        function e=evaluate(~,z,request),r=z(1)^2-z(2);e=lmz.problems.ProblemEvaluation(struct('EqualityResidual',r,'ResidualBlocks',lmz.problems.ResidualBlock.create('fold_equation','equality',r,1),'IsValid',all(isfinite(z)),'IsPhysicallyValid',true));end
    end
end
