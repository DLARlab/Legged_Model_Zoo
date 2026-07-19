classdef FsolveSolver < lmz.solvers.RootSolver
    methods
        function result=solve(~,problem,seed,parameters,options,context)
            if ~isa(problem,'lmz.api.NonlinearEquationProblem'), error('lmz:Solver:ProblemType','FsolveSolver requires NonlinearEquationProblem.'); end
            if exist('fsolve','file')~=2, error('lmz:Solver:ToolboxUnavailable','Optimization Toolbox fsolve is unavailable.'); end
            if nargin<5||isempty(options),options=lmz.solvers.SolverOptions();elseif isstruct(options),options=lmz.solvers.SolverOptions(options);end
            if isa(seed,'lmz.data.Solution'),u0=seed.DecisionValues;sourceSeed=seed.toStruct();else,u0=seed(:);sourceSeed=u0;end
            if nargin<4||isempty(parameters),parameters=problem.getParameterSchema().defaults();end
            scale=problem.scale(u0); q0=u0./scale;
            matlabOptions=optimoptions('fsolve','Display',options.Display,'Algorithm',options.Algorithm, ...
                'FunctionTolerance',options.FunctionTolerance,'StepTolerance',options.StepTolerance, ...
                'OptimalityTolerance',options.OptimalityTolerance,'MaxIterations',options.MaxIterations, ...
                'MaxFunctionEvaluations',options.MaxFunctionEvaluations);
            evaluations=0;
            [q,~,exitFlag,output]=fsolve(@residual,q0,matlabOptions);
            u=problem.canonicalize(q.*scale); evaluation=problem.evaluate(u,parameters,context,true);
            solution=problem.makeSolution(u,parameters,evaluation);
            result=lmz.data.SolveResult(solution,evaluation,exitFlag,output,options.toStruct(),sourceSeed,context.RandomSeed, ...
                struct('solver','fsolve','matlabVersion',version,'evaluations',evaluations));
            function value=residual(qValue)
                context.check(); evaluations=evaluations+1; candidate=problem.canonicalize(qValue.*scale); value=problem.residual(candidate,parameters,context); context.progress(min(0.99,evaluations/options.MaxFunctionEvaluations),'Solving nonlinear equations');
            end
        end
    end
end
