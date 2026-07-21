classdef TestRectangularMultipleShooting < matlab.unittest.TestCase
    methods (Test)
        function residualAndDecisionDimensionsRemainIndependent(testCase)
            [over,~,~,overSeed]=lmztest.makeAnalyticShootingProblem(1, ...
                'FreeMasks',{true;false});
            overEvaluation=over.evaluate(overSeed,[], ...
                lmz.api.RunContext.synchronous(1003),false);
            testCase.verifyEqual(numel(overEvaluation.Residual),2);
            testCase.verifyEqual(numel(overSeed),1);

            [under,~,~,underSeed]=lmztest.makeAnalyticShootingProblem(1, ...
                'Formulation','feasibility');
            underEvaluation=under.evaluate(underSeed,[], ...
                lmz.api.RunContext.synchronous(1004),false);
            testCase.verifyEqual(numel(underEvaluation.Residual),1);
            testCase.verifyEqual(numel(underSeed),2);
        end
    end
end
