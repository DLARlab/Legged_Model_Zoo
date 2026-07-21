classdef TestAdaptiveHorizonHomotopy < matlab.unittest.TestCase
    methods (Test)
        function anchorAndFullEndpointsAreExact(testCase)
            problem=lmzmodels.tutorial_hopper.Model().createProblem( ...
                'multiple_shooting',struct('HorizonLength',3));
            anchor=problem.getDecisionSchema().defaults();
            names=problem.getDecisionSchema().names();
            anchor(strcmp(names,'node_2_y'))=1.1;
            parameters=problem.getParameterSchema().defaults();
            context=lmz.api.RunContext.synchronous(2101);
            full=problem.evaluate(anchor,parameters,context,false);
            atZero=lmz.shooting.HorizonHomotopyProblem( ...
                problem,anchor,0,numel(full.ScaledResidual));
            atOne=lmz.shooting.HorizonHomotopyProblem( ...
                problem,anchor,1,numel(full.ScaledResidual));

            testCase.verifyEqual(atZero.residual(anchor,parameters,context), ...
                zeros(size(full.ScaledResidual)),'AbsTol',0);
            testCase.verifyEqual(atOne.residual(anchor,parameters,context), ...
                full.ScaledResidual,'AbsTol',0);
        end

        function adaptiveTraceReachesFullThreeSegmentProblem(testCase)
            problem=lmzmodels.tutorial_hopper.Model().createProblem( ...
                'multiple_shooting',struct('HorizonLength',3));
            anchor=problem.getDecisionSchema().defaults();
            names=problem.getDecisionSchema().names();
            anchor(strcmp(names,'node_2_y'))=1.1;
            context=lmz.api.RunContext.synchronous(2102);
            result=lmz.shooting.HorizonContinuation().traceHomotopy( ...
                problem,anchor,struct('ResidualTolerance',1e-8, ...
                'HomotopyInitialStep',0.4, ...
                'HomotopyMaximumStep',0.5, ...
                'HomotopyMinimumStep',0.01),context);

            testCase.verifyTrue(result.Completed);
            testCase.verifyEqual(result.Lambda,1);
            testCase.verifyGreaterThanOrEqual(numel(result.Attempts),2);
            testCase.verifyGreaterThanOrEqual(numel(result.Checkpoints),3);
            final=problem.evaluate(result.Decision, ...
                problem.getParameterSchema().defaults(),context,false);
            testCase.verifyLessThan(max(abs(final.ScaledResidual)),1e-8);
        end
    end
end
