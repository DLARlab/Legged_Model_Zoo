classdef PeriodicOrbitProblem < lmz.problems.NonlinearProblem
    properties, Model; Schema; Options struct; end
    properties (Access=private), CacheKey char=''; CacheValue=[]; end
    methods
        function obj=PeriodicOrbitProblem(model,schema,options),obj.Model=model;obj.Schema=schema;if nargin<3,options=struct();end;obj.Options=options;end
        function m=metadata(obj),mm=obj.Model.metadata();m=struct('id','periodic_orbit','model_id',mm.id,'version','1.0');end
        function s=decisionSchema(obj),s=obj.Schema;end
        function e=evaluate(obj,z,request)
            if nargin<3,request=struct();end;z=obj.canonicalize(z);key=sprintf('%.17g,',z);if strcmp(key,obj.CacheKey),e=obj.CacheValue;return;end;t=tic;
            try
                sim=obj.Model.simulate(struct('decision',z,'problem_options',obj.Options));n=min(size(sim.state,2),numel(z));r=sim.state(end,1:n).'-sim.state(1,1:n).';
                if isfield(sim,'periodic_residual'),r=sim.periodic_residual(:);end
                block=lmz.problems.ResidualBlock.create('periodicity','equality',r,ones(size(r)));e=lmz.problems.ProblemEvaluation(struct('EqualityResidual',r,'ResidualBlocks',block,'Simulation',sim,'IsValid',all(isfinite(r)),'IsPhysicallyValid',sim.diagnostics.finite));
            catch ME,e=lmz.problems.ProblemEvaluation.failure(ME,min(obj.Schema.width(),8));end;e.ElapsedSeconds=toc(t);obj.CacheKey=key;obj.CacheValue=e;
        end
        function clearCache(obj),obj.CacheKey='';obj.CacheValue=[];end
    end
end
