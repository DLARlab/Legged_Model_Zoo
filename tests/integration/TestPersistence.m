classdef TestPersistence < matlab.unittest.TestCase
    methods(Test),function branchRoundTrip(t),b=lmz.core.SolutionBranch();b.ModelId='test';b.ProblemId='fold';b.addPoint(struct('decision',[1;1]));p=[tempname '.mat'];clean=onCleanup(@()delete(p));lmz.io.SolutionStore.saveBranch(p,b);q=lmz.io.SolutionStore.loadBranch(p);t.verifyEqual(q.Points.decision,[1;1]);end,end
end
