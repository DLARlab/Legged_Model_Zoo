classdef MultiStartSearch
    methods
        function result=run(~,problem,seeds,options),if nargin<4,options=struct();end;if ~isfield(options,'RandomSeed'),options.RandomSeed=1;end;if ~isfield(options,'ClusterTolerance'),options.ClusterTolerance=1e-5;end;rng(options.RandomSeed,'twister');attempts=cell(1,size(seeds,2));accepted={};solver=lmz.solvers.RootSolver();for i=1:size(seeds,2),try,[s,r]=solver.solve(problem,seeds(:,i),lmz.solvers.SolverOptions());attempts{i}=r;if r.converged,accepted{end+1}=s;end;catch ME,attempts{i}=struct('converged',false,'error',ME.message);end,end;[uniqueSolutions,labels]=lmz.solvers.SolutionClusterer().cluster(accepted,problem.decisionSchema().scales(),options.ClusterTolerance);result=struct('attempts',{attempts},'converged',{accepted},'solutions',{uniqueSolutions},'cluster_labels',labels,'random_seed',options.RandomSeed);end
    end
end
