classdef TestSolutionBranch < matlab.unittest.TestCase
    methods (Test)
        function namedPointSubsetAndArtifact(testCase)
            registry=lmz.registry.ModelRegistry.discover();branch=lmz.services.BranchService().loadBuiltInBranch(registry,'slip_biped');
            testCase.verifyEqual(branch.pointCount(),215);testCase.verifySize(branch.decision('dx'),[1 215]);
            subset=branch.subset([2 4 6]);testCase.verifyEqual(subset.pointCount(),3);testCase.verifyEqual(subset.point(2).DecisionValues,branch.point(4).DecisionValues);
            path=[tempname '.mat'];cleanup=onCleanup(@()deleteFile(path));lmz.io.ArtifactStore.save(path,branch.toArtifact());restored=lmz.data.SolutionBranch.fromArtifact(lmz.io.ArtifactStore.load(path));testCase.verifyEqual(restored.DecisionValues,branch.DecisionValues);clear cleanup
        end
    end
end
function deleteFile(path),if exist(path,'file'),delete(path);end,end
