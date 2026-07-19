classdef TestArtifactProblemMaturity < matlab.unittest.TestCase
    methods (Test)
        function newArtifactsRecordSelectedProblemStatus(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quadruped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            branch=lmz.services.BranchService().loadRoadMapBranch( ...
                problem,catalog.defaultBranchPath());
            artifact=branch.point(catalog.recommendedSeedIndex( ...
                catalog.defaultBranchPath())).toArtifact();
            testCase.verifyEqual(artifact.problemMaturity,'validated');
            testCase.verifyEqual(artifact.validationStatus,'source-equivalent');
            testCase.verifyEqual(artifact.problemMetadata.id,'periodic_apex');
            lmz.io.ArtifactStore.validate(artifact);
        end
    end
end
