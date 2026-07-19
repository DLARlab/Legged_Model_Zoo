classdef TestHomotopyAndFamilyScan < matlab.unittest.TestCase
    methods (Test)
        function transportsAndScans(testCase)
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());u=problem.getDecisionSchema().defaults();p=problem.getParameterSchema().defaults();seed=problem.makeSolution(u,p,problem.evaluate(u,p,lmz.api.RunContext.synchronous(0),false));service=lmz.services.ContinuationService();context=lmz.api.RunContext.synchronous(9);
            homotopy=service.parameterHomotopy(problem,seed,'stride_length',[0.9 0.95],struct(),context);testCase.verifyEqual(homotopy.Completed,2);testCase.verifyEqual(homotopy.Solutions(2).parameter('stride_length'),0.95,'AbsTol',1e-12);
            report=service.branchFamilyScan(problem,seed,'stride_length',[0.9 0.95],struct('ContinuationOptions',struct('MaximumPoints',4,'BothDirections',false)),context);testCase.verifyEqual(report.Completed,2);testCase.verifyEqual(report.Failed,0);testCase.verifyEqual(report.Branches{1}.pointCount(),4);
        end
    end
end
