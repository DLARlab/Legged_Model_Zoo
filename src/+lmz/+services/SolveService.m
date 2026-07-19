classdef SolveService
    methods
        function result=solve(~,problem,seed,options,context)
            if ~isa(problem,'lmz.api.NonlinearEquationProblem'),error('lmz:Services:ProblemType','SolveService requires a nonlinear problem.');end
            parameters=problem.getParameterSchema().defaults(); if isa(seed,'lmz.data.Solution'),parameters=seed.ParameterValues;end
            result=lmz.solvers.FsolveSolver().solve(problem,seed,parameters,options,context); context.progress(1,'Solve complete');
        end
    end
end
