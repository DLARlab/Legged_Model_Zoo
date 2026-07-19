classdef TestContinuation < matlab.unittest.TestCase
    methods(Test)
        function traversesFold(t),p=FoldProblem();o=lmz.continuation.ContinuationOptions();o.Direction=1;o.InitialStep=.08;o.MaxPoints=45;o.ParameterIndex=2;b=lmz.continuation.PseudoArclengthContinuation().run(p,[-1;1],[-.9;.81],o);x=arrayfun(@(q)q.decision(1),b.Points);rn=[b.Points.residual_norm];t.verifyTrue(any(x<0));t.verifyTrue(any(x>0));t.verifyLessThan(max(rn),1e-6);t.verifyTrue(any([b.Points.fold_candidate]));end
    end
end
