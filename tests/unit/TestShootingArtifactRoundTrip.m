classdef TestShootingArtifactRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function hashBoundPlainArtifactRoundTrips(testCase)
            result=solveTutorial(1020);
            artifact=result.toArtifact();
            path=[tempname '.mat'];
            cleanup=onCleanup(@()deleteIfPresent(path));
            lmz.io.ArtifactStore.save(path,artifact);
            loaded=lmz.io.ArtifactStore.load(path);
            restored=lmz.shooting.ShootingResult.fromArtifact(loaded);
            testCase.verifyEqual(loaded.shootingHorizonHash, ...
                artifact.shootingHorizonHash);
            testCase.verifyEqual(restored.Horizon.toStruct(), ...
                result.Horizon.toStruct());
            testCase.verifyTrue(restored.FeasibilityReport.Success);
            clear cleanup
        end


        function failedClassificationOverridesPositiveSolverExit(testCase)
            source=solveTutorial(1022);
            testCase.verifyGreaterThan(source.SolveResult.ExitFlag,0);
            record=source.FeasibilityReport.toStruct();
            record.Success=false;
            record.Classification='best_known_residual';
            record.PhysicalConditionsValid=true;
            bestKnown=withReport(source, ...
                lmz.shooting.FeasibilityReport(record)).toArtifact();
            testCase.verifyEqual(bestKnown.terminationReason, ...
                'best_known_residual');

            record.Classification='physical_validation_failure';
            record.PhysicalConditionsValid=false;
            physicalFailure=withReport(source, ...
                lmz.shooting.FeasibilityReport(record)).toArtifact();
            testCase.verifyEqual(physicalFailure.terminationReason, ...
                'physical_validation_failure');
            testCase.verifyEqual(physicalFailure.diagnostics.ExitFlag, ...
                source.SolveResult.ExitFlag);
        end
    end
end

function result=solveTutorial(seed)
model=lmz.registry.ModelRegistry.discover().createModel('tutorial_hopper');
problem=model.createProblem('multiple_shooting',struct('HorizonLength',2));
result=lmz.services.MultipleShootingService().solve(problem, ...
    problem.getDecisionSchema().defaults(), ...
    struct('Solver','fsolve','Display','off'), ...
    lmz.api.RunContext.synchronous(seed));
end
function value=withReport(source,report)
value=lmz.shooting.ShootingResult(source.SolveResult,source.Horizon,report, ...
    'SegmentResults',source.SegmentResults, ...
    'InitializerHistory',source.InitializerHistory, ...
    'ContinuationHistory',source.ContinuationHistory, ...
    'Checkpoints',source.Checkpoints,'Diagnostics',source.Diagnostics);
end
function deleteIfPresent(path)
if exist(path,'file')==2,delete(path);end
end
