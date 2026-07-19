function [problem,pair,context]=makeAnalyticContinuationCase(seed)
%MAKEANALYTICCONTINUATIONCASE Exact two-point seed on y=0.
if nargin<1,seed=700;end
context=lmz.api.RunContext.synchronous(seed);
problem=lmztest.AnalyticModel().createProblem('line',struct());
parameters=problem.getParameterSchema().defaults();
first=problem.makeSolution([0;0],parameters, ...
    problem.evaluate([0;0],parameters,context,false));
second=problem.makeSolution([0.1;0],parameters, ...
    problem.evaluate([0.1;0],parameters,context,false));
pair=lmz.data.SolutionPair(first,second,0.1,0.1, ...
    struct('Source','analytic-test'));
end
