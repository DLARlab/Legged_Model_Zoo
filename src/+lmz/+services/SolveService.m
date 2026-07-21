classdef SolveService
    %SOLVESERVICE Execute a nonlinear solve through the public problem contract.
    methods
        function result=solve(~,problem,seed,options,context)
            started=tic;
            if ~isa(problem,'lmz.api.NonlinearEquationProblem'),error('lmz:Services:ProblemType','SolveService requires a nonlinear problem.');end
            parameters=problem.getParameterSchema().defaults(); if isa(seed,'lmz.data.Solution'),parameters=seed.ParameterValues;end
            if isa(seed,'lmz.data.Solution')
                tolerance=1e-7;if isfield(options,'AcceptExistingTolerance'),tolerance=options.AcceptExistingTolerance;end
                initial=problem.evaluate(seed.DecisionValues,parameters,context,false);
                if initial.ScaledResidualNorm<=tolerance&& ...
                        physicallyValid(initial)
                    evaluation=problem.evaluate(seed.DecisionValues,parameters,context,true);
                    solution=problem.makeSolution(seed.DecisionValues,parameters,evaluation);
                    output=struct('algorithm','accepted-existing-seed','iterations',0, ...
                        'funcCount',2,'message','Seed already satisfies the requested tolerance.');
                    result=lmz.data.SolveResult(solution,evaluation,1,output,options, ...
                        seed.toStruct(),context.RandomSeed,struct('solver','accept-existing', ...
                        'tolerance',tolerance,'matlabVersion',version, ...
                        'evaluations',2,'elapsedTime',toc(started), ...
                        'problemMetadata',problem.getDescriptor()));
                    context.progress(1,'Existing seed accepted as solved.');return
                end
            end
            result=lmz.solvers.FsolveSolver().solve(problem,seed,parameters,options,context); context.progress(1,'Solve complete');
        end
    end
end

function value=physicallyValid(evaluation)
value=logical(evaluation.PhysicalValidity);
if isstruct(evaluation.Feasibility)&& ...
        isfield(evaluation.Feasibility,'Valid')
    value=value&&logical(evaluation.Feasibility.Valid);
end
end
