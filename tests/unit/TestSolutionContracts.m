classdef TestSolutionContracts < matlab.unittest.TestCase
    methods (Test)
        function structAndNamedAccess(testCase)
            [problem,solution]=makeSolution(); restored=lmz.data.Solution.fromStruct(solution.toStruct());
            testCase.verifyEqual(restored.decision('speed'),solution.DecisionValues(1));
            testCase.verifyEqual(restored.parameter('stride_length'),0.8);
            changed=solution.withDecisionValues([1.25;0.64]);testCase.verifyNotEqual(changed.Id,solution.Id);problem.validateSolution(changed);
        end
        function artifactRoundTrip(testCase)
            [~,solution]=makeSolution();path=[tempname '.mat'];cleanup=onCleanup(@()deleteFile(path));
            lmz.io.ArtifactStore.save(path,solution.toArtifact());restored=lmz.data.Solution.fromArtifact(lmz.io.ArtifactStore.load(path));testCase.verifyEqual(restored.DecisionValues,solution.DecisionValues);clear cleanup
        end
    end
end
function [problem,solution]=makeSolution
r=lmz.registry.ModelRegistry.discover();problem=r.createModel('slip_biped').createProblem('periodic_apex',struct());u=problem.getDecisionSchema().defaults();p=problem.getParameterSchema().defaults();solution=problem.makeSolution(u,p,problem.evaluate(u,p,lmz.api.RunContext.synchronous(0),false));
end
function deleteFile(path),if exist(path,'file'),delete(path);end,end
