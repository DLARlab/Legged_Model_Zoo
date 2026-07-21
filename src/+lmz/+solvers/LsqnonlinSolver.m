classdef LsqnonlinSolver < lmz.solvers.RootSolver
    %LSQNONLINSOLVER Scaled nonlinear least-squares solver adapter.
    methods
        function result=solve(~,problem,seed,parameters,options,context)
            started=tic;
            if ~isa(problem,'lmz.api.NonlinearEquationProblem')
                error('lmz:Solver:ProblemType', ...
                    'LsqnonlinSolver requires NonlinearEquationProblem.');
            end
            if exist('lsqnonlin','file')~=2
                error('lmz:Solver:ToolboxUnavailable', ...
                    'Optimization Toolbox lsqnonlin is unavailable.');
            end
            if nargin<5||isempty(options)
                options=lmz.solvers.SolverOptions();
            elseif isstruct(options)
                options=lmz.solvers.SolverOptions(options);
            end
            validateAlgorithm(options.Algorithm);
            if isa(seed,'lmz.data.Solution')
                u0=seed.DecisionValues;sourceSeed=seed.toStruct();
            else
                u0=seed(:);sourceSeed=u0;
            end
            if nargin<4||isempty(parameters)
                parameters=problem.getParameterSchema().defaults();
            end
            scale=problem.scale(u0);q0=u0./scale;
            [lower,upper]=scaledBounds(problem,scale);
            if any(isfinite([lower;upper]))&& ...
                    strcmp(options.Algorithm,'levenberg-marquardt')
                error('lmz:Solver:AlgorithmBounds', ...
                    ['lsqnonlin levenberg-marquardt does not support finite ' ...
                    'bounds. Select trust-region-reflective explicitly.']);
            end
            optionValues=struct('Display',options.Display, ...
                'Algorithm',options.Algorithm, ...
                'FunctionTolerance',options.FunctionTolerance, ...
                'StepTolerance',options.StepTolerance, ...
                'OptimalityTolerance',options.OptimalityTolerance, ...
                'MaxIterations',options.MaxIterations, ...
                'MaxFunctionEvaluations',options.MaxFunctionEvaluations);
            matlabOptions=lmz.compat.Optimization.lsqnonlin(optionValues);
            evaluations=0;residualHistory=zeros(0,1);
            [q,resnorm,~,exitFlag,output,~,jacobian]=lsqnonlin( ...
                @residual,q0,lower,upper,matlabOptions);
            u=problem.canonicalize(q.*scale);
            evaluation=problem.evaluate(u,parameters,context,true);
            solution=problem.makeSolution(u,parameters,evaluation);
            output.ResidualSumOfSquares=resnorm;
            output.ResidualHistory=residualHistory;
            result=lmz.data.SolveResult(solution,evaluation,exitFlag,output, ...
                options.toStruct(),sourceSeed,context.RandomSeed,struct( ...
                'solver','lsqnonlin','matlabVersion',version, ...
                'evaluations',evaluations,'elapsedTime',toc(started), ...
                'returnedJacobian',jacobian, ...
                'problemMetadata',problem.getDescriptor()));

            function value=residual(qValue)
                context.check();evaluations=evaluations+1;
                candidate=problem.canonicalize(qValue.*scale);
                value=problem.residual(candidate,parameters,context);
                residualHistory(end+1,1)=norm(value);
                context.progress(min(0.99,evaluations/ ...
                    options.MaxFunctionEvaluations), ...
                    'Solving nonlinear least squares');
            end
        end
    end
end

function validateAlgorithm(value)
allowed={'levenberg-marquardt','trust-region-reflective'};
if ~ischar(value)||~any(strcmp(value,allowed))
    error('lmz:Solver:Algorithm', ...
        'lsqnonlin Algorithm must be explicitly selected from: %s.', ...
        strjoin(allowed,', '));
end
end

function [lower,upper]=scaledBounds(problem,scale)
schema=problem.getDecisionSchema();count=schema.count();
lower=zeros(count,1);upper=zeros(count,1);
for index=1:count
    lower(index)=schema.Specs(index).LowerBound/scale(index);
    upper(index)=schema.Specs(index).UpperBound/scale(index);
end
end
