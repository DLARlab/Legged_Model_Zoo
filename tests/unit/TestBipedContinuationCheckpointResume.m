classdef TestBipedContinuationCheckpointResume < matlab.unittest.TestCase
    methods (Test)
        function resumesRepositoryBranchCheckpoint(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch([],problem,true);
            index=catalog.Manifest.defaultSeedIndex;context=lmz.api.RunContext.synchronous(76);
            pair=lmz.services.SeedService().adjacentBranchPair(problem,branch,index,1,struct(),context);
            path=[tempname '.mat'];cleanup=onCleanup(@()deleteIfPresent(path));
            first=lmz.services.ContinuationService().run(problem,pair,struct( ...
                'MaximumPoints',3,'BothDirections',false,'InitialStep',pair.AchievedRadius, ...
                'MaximumStep',pair.AchievedRadius,'CheckpointPath',path),context);
            testCase.verifyEqual(first.Branch.pointCount(),3);
            resumed=lmz.services.ContinuationService().resumeCheckpoint(problem,path, ...
                struct('MaximumPoints',4),context);
            testCase.verifyEqual(resumed.Branch.pointCount(),4);clear cleanup
        end
    end
end
function deleteIfPresent(path),if exist(path,'file')==2,delete(path);end,end
