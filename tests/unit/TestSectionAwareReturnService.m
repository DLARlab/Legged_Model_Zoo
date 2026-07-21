classdef TestSectionAwareReturnService < matlab.unittest.TestCase
    %TESTSECTIONAWARERETURNSERVICE True start rephasing and stop truncation.
    methods (Test)
        function selectedStartAndStopBoundReturnedTrajectory(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('periodic_hop',struct());
            context=lmz.api.RunContext.synchronous(991);
            decision=problem.getDecisionSchema().defaults();
            parameters=problem.getParameterSchema().defaults();
            evaluation=problem.evaluate( ...
                decision,parameters,context,true);
            source=problem.makeSolution(decision,parameters,evaluation);

            configuration=struct( ...
                'StartSectionId','height_descending', ...
                'StopSectionId','ground_impact_pre');
            result=lmz.services.PoincareReturnService().simulate( ...
                model,source,configuration,context);

            testCase.verifyEqual(result.Simulation.Time(1),0);
            testCase.verifyEqual(result.Simulation.States(1,3),0.1, ...
                'AbsTol',2e-12);
            testCase.verifyEqual(result.Simulation.Time(end), ...
                result.StopCrossing.Time,'AbsTol',8*eps);
            testCase.verifyEqual(result.Simulation.States(end,:).', ...
                result.StopCrossing.State,'AbsTol',2e-12);
            testCase.verifyEqual(result.Simulation.States(end,3),0, ...
                'AbsTol',2e-12);
            testCase.verifyTrue(result.Diagnostics. ...
                StartSectionInitialization.TrajectoryRephased);
            testCase.verifyTrue( ...
                result.Diagnostics.TerminatedAtAcceptedCrossing);
            testCase.verifyTrue(result.Diagnostics.TrajectoryTruncated);
            testCase.verifyEqual(result.Diagnostics. ...
                SectionTerminationPolicy.SectionId,'ground_impact_pre');
            testCase.verifyLessThanOrEqual(result.Diagnostics. ...
                StartSectionInitialization.PhysicalOrbitMaxError,1e-12);
        end

        function identicalNamedEventSectionFindsNextCycle(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('periodic_hop',struct());
            context=lmz.api.RunContext.synchronous(992);
            decision=problem.getDecisionSchema().defaults();
            parameters=problem.getParameterSchema().defaults();
            evaluation=problem.evaluate( ...
                decision,parameters,context,true);
            source=problem.makeSolution(decision,parameters,evaluation);
            configuration=struct( ...
                'StartSectionId','ground_impact_post', ...
                'StopSectionId','ground_impact_post');

            result=lmz.services.PoincareReturnService().simulate( ...
                model,source,configuration,context);

            testCase.verifyGreaterThan(result.ReturnTime,0.5);
            testCase.verifyEqual(result.StartCrossing.Time,0);
            testCase.verifyEqual(result.StopCrossing.Time, ...
                result.Simulation.Time(end),'AbsTol',8*eps);
            testCase.verifyEqual(result.StopCrossing.Occurrence,1);
            testCase.verifyTrue(result.StopCrossing.Accepted);
        end
    end
end
