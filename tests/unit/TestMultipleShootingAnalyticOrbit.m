classdef TestMultipleShootingAnalyticOrbit < matlab.unittest.TestCase
    methods (Test)
        function affineFixedPointHasZeroNamedResiduals(testCase)
            [problem,~,~,seed]=lmztest.makeAnalyticShootingProblem(3);
            residual=problem.evaluateShooting(seed,[], ...
                lmz.api.RunContext.synchronous(1001),true);
            testCase.verifyEqual(residual.scaled(),zeros(4,1), ...
                'AbsTol',1e-14);
            testCase.verifyTrue(residual.Feasibility.Valid);
            testCase.verifyEqual( ...
                residual.Diagnostics.SegmentEvaluationCount,3);
            names=arrayfun(@(item)item.Name,residual.Blocks, ...
                'UniformOutput',false);
            testCase.verifyEqual(names,{'interface_1_defect'; ...
                'interface_2_defect';'interface_3_defect'; ...
                'final_section_closure'});
            testCase.verifyEqual(numel(residual.SegmentResults),3);
        end
    end
end
