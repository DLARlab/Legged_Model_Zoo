% See tests/fixtures/FoldProblem.m for the headless x^2-lambda example.
startup; problem=FoldProblem(); options=lmz.continuation.ContinuationOptions();options.MaxPoints=40;options.ParameterIndex=2;branch=lmz.continuation.PseudoArclengthContinuation().run(problem,[-1;1],[-.9;.81],options);disp([[branch.Points.decision].' [branch.Points.arclength].']);
