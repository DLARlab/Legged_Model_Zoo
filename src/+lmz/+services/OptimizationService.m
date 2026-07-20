classdef OptimizationService
    %OPTIMIZATIONSERVICE Execute optimization through the public problem contract.
    methods
        function result=run(~,problem,seed,options,context)
            parameters=problem.getParameterSchema().defaults(); if isa(seed,'lmz.data.Solution'),parameters=seed.ParameterValues;end
            result=lmz.optimization.FminconSolver().solve(problem,seed,parameters,options,context);
        end
    end
end
