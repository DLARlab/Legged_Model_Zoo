classdef TestQuadLoadInterfaceDefects < matlab.unittest.TestCase
    methods (Test)
        function everyLoadSegmentHasExplicitFourteenCoordinateDefect(testCase)
            problem=lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingProblem([],struct( ...
                'NumberOfStrides',3,'EnergyMode','diagnostic_only'));
            residual=problem.evaluateShooting( ...
                problem.Codec.decisionDefaults(),[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual(numel(residual.InterfaceDefects),3);
            for index=1:3
                defect=residual.InterfaceDefects(index);
                testCase.verifyEqual(numel(defect.Values),14);
                testCase.verifyEqual(defect.InterfaceIndex,index);
            end
            names=arrayfun(@(item)item.Name,residual.Blocks, ...
                'UniformOutput',false);
            testCase.verifyEqual(sum(startsWith(names,'interface_')& ...
                endsWith(names,'_defect')),3);
            testCase.verifyTrue(residual.Diagnostics.SingleEvaluationCache);
        end
    end
end
