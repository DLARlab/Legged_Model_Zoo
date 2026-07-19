classdef TestSolutionContracts < matlab.unittest.TestCase
    methods (Test)
        function structAndNamedAccess(testCase)
            [problem,solution]=makeSolution(); restored=lmz.data.Solution.fromStruct(solution.toStruct());
            testCase.verifyEqual(restored.decision('dx'),solution.DecisionValues(1));
            testCase.verifyEqual(restored.parameter('offset_left'),solution.ParameterValues(1));
            values=solution.DecisionValues;values(1)=values(1)+0.01;changed=solution.withDecisionValues(values);testCase.verifyNotEqual(changed.Id,solution.Id);problem.validateSolution(changed);
        end
        function artifactRoundTrip(testCase)
            [~,solution]=makeSolution();path=[tempname '.mat'];cleanup=onCleanup(@()deleteFile(path));
            lmz.io.ArtifactStore.save(path,solution.toArtifact());restored=lmz.data.Solution.fromArtifact(lmz.io.ArtifactStore.load(path));testCase.verifyEqual(restored.DecisionValues,solution.DecisionValues);clear cleanup
        end
    end
end
function [problem,solution]=makeSolution
r=lmz.registry.ModelRegistry.discover();problem=r.createModel('slip_biped').createProblem('periodic_apex',struct());catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch(catalog.defaultBranchPath(),problem);source=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));solution=problem.makeSolution(source.DecisionValues,source.ParameterValues,problem.evaluate(source.DecisionValues,source.ParameterValues,lmz.api.RunContext.synchronous(0),false));
end
function deleteFile(path),if exist(path,'file'),delete(path);end,end
