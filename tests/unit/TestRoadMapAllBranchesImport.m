classdef TestRoadMapAllBranchesImport < matlab.unittest.TestCase
    methods (Test)
        function importsEveryNativeBranch(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());
            datasets=lmz.services.BranchService().loadAllRoadMapBranches(problem);counts=zeros(1,numel(datasets));
            for index=1:numel(datasets),testCase.verifyClass(datasets{index}.Branch,'lmz.data.SolutionBranch');counts(index)=datasets{index}.Branch.pointCount();testCase.verifyTrue(datasets{index}.ReadOnly);end
            testCase.verifyEqual(counts,[891 443 474 228 212 200 277 180 538]);testCase.verifyEqual(sum(counts),3443);
        end
    end
end
