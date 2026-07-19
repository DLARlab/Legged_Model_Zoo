classdef TestRunArtifacts < matlab.unittest.TestCase
    methods (Test)
        function solveContinuationOptimizationSave(testCase)
            registry=lmz.registry.ModelRegistry.discover();context=lmz.api.RunContext.synchronous(31);problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());seed=problem.makeSolution([0.7;1],[],[]);solved=lmz.services.SolveService().solve(problem,seed,struct(),context);pair=lmz.services.SeedService().makeSecondSeed(problem,solved.Solution,0.03,struct(),context);continued=lmz.services.ContinuationService().run(problem,pair,struct('MaximumPoints',4,'BothDirections',false),context);
            fit=registry.createModel('slip_quad_load').createProblem('multi_stride_fit',struct());optimized=lmz.services.OptimizationService().run(fit,fit.makeSolution(fit.getDecisionSchema().defaults(),[],[]),struct(),context);artifacts={solved.toArtifact(),continued.toArtifact(),optimized.toArtifact()};types={'solve-run','continuation-run','optimization-run'};
            for index=1:3,path=[tempname '.mat'];cleanup=onCleanup(@()deleteFile(path));lmz.io.ArtifactStore.save(path,artifacts{index});loaded=lmz.io.ArtifactStore.load(path);testCase.verifyEqual(loaded.artifactType,types{index});clear cleanup,end
        end
    end
end
function deleteFile(path),if exist(path,'file'),delete(path);end,end
