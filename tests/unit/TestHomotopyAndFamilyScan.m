classdef TestHomotopyAndFamilyScan < matlab.unittest.TestCase
    methods (Test)
        function transportsAndScans(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch(catalog.defaultBranchPath(),problem);source=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));seed=problem.makeSolution(source.DecisionValues,source.ParameterValues,problem.evaluate(source.DecisionValues,source.ParameterValues,lmz.api.RunContext.synchronous(0),false));service=lmz.services.ContinuationService();context=lmz.api.RunContext.synchronous(9);targets=source.ParameterValues(1)+[0.001 0.002];
            homotopy=service.parameterHomotopy(problem,seed,'offset_left',targets,struct(),context);testCase.verifyEqual(homotopy.Completed,2);testCase.verifyEqual(homotopy.Solutions(2).parameter('offset_left'),targets(2),'AbsTol',1e-12);
            report=service.branchFamilyScan(problem,seed,'offset_left',targets,struct('ContinuationOptions',struct('MaximumPoints',4,'BothDirections',false)),context);testCase.verifyEqual(report.Completed,2);testCase.verifyEqual(report.Failed,0);testCase.verifyEqual(report.Branches{1}.pointCount(),4);
        end
    end
end
