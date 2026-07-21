classdef TestMultipleShootingVersusSingleShooting < matlab.unittest.TestCase
    methods (Test)
        function composedMapAndDefectsShareFixedPoint(testCase)
            gains=[0.4;0.5;0.25];offsets=[1.2;0.7;0.4];
            compositeGain=prod(gains);
            compositeOffset=offsets(3)+gains(3)*offsets(2)+ ...
                gains(3)*gains(2)*offsets(1);
            fixed=compositeOffset/(1-compositeGain);
            nodes=[fixed;gains(1)*fixed+offsets(1);0;fixed];
            nodes(3)=gains(2)*nodes(2)+offsets(2);
            [problem,~,~,seed]=lmztest.makeAnalyticShootingProblem(3, ...
                'NodeValues',nodes,'Gains',gains,'Offsets',offsets);
            evaluation=problem.evaluate(seed,[], ...
                lmz.api.RunContext.synchronous(1002),false);
            single=gains(3)*(gains(2)*(gains(1)*fixed+offsets(1))+ ...
                offsets(2))+offsets(3)-fixed;
            testCase.verifyEqual(evaluation.Residual,zeros(4,1), ...
                'AbsTol',1e-13);
            testCase.verifyEqual(single,0,'AbsTol',1e-13);
        end
    end
end
