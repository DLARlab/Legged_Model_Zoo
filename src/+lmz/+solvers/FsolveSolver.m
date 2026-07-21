classdef FsolveSolver < lmz.solvers.RootSolver
    methods
        function result=solve(~,problem,seed,parameters,options,context)
            started=tic;
            if ~isa(problem,'lmz.api.NonlinearEquationProblem'), error('lmz:Solver:ProblemType','FsolveSolver requires NonlinearEquationProblem.'); end
            if exist('fsolve','file')~=2, error('lmz:Solver:ToolboxUnavailable','Optimization Toolbox fsolve is unavailable.'); end
            if nargin<5||isempty(options),options=lmz.solvers.SolverOptions();elseif isstruct(options),options=lmz.solvers.SolverOptions(options);end
            if isa(seed,'lmz.data.Solution'),u0=seed.DecisionValues;sourceSeed=seed.toStruct();else,u0=seed(:);sourceSeed=u0;end
            if nargin<4||isempty(parameters),parameters=problem.getParameterSchema().defaults();end
            scale=problem.scale(u0); q0=u0./scale;
            optionValues=struct('Display',options.Display,'Algorithm',options.Algorithm, ...
                'FunctionTolerance',options.FunctionTolerance,'StepTolerance',options.StepTolerance, ...
                'OptimalityTolerance',options.OptimalityTolerance,'MaxIterations',options.MaxIterations, ...
                'MaxFunctionEvaluations',options.MaxFunctionEvaluations);
            matlabOptions=lmz.compat.Optimization.fsolve(optionValues);
            evaluations=0;residualHistory=zeros(0,1);
            [q,~,exitFlag,output]=fsolve(@residual,q0,matlabOptions);
            output.ResidualHistory=residualHistory;
            u=problem.canonicalize(q.*scale); evaluation=problem.evaluate(u,parameters,context,true);
            solution=problem.makeSolution(u,parameters,evaluation);
            result=lmz.data.SolveResult(solution,evaluation,exitFlag,output,options.toStruct(),sourceSeed,context.RandomSeed, ...
                struct('solver','fsolve','matlabVersion',version, ...
                'evaluations',evaluations,'elapsedTime',toc(started), ...
                'problemMetadata',problem.getDescriptor()));
            function value=residual(qValue)
                context.check(); evaluations=evaluations+1; candidate=problem.canonicalize(qValue.*scale); value=problem.residual(candidate,parameters,context); residualHistory(end+1,1)=norm(value); context.progress(min(0.99,evaluations/options.MaxFunctionEvaluations),'Solving nonlinear equations');
            end
        end
    end
end
