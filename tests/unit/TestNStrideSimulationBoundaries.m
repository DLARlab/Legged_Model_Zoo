classdef TestNStrideSimulationBoundaries < matlab.unittest.TestCase
    %TESTNSTRIDESIMULATIONBOUNDARIES Verify public concatenated trajectories.
    methods (Test)
        function tutorialReturnsStrictThreeStrideTrajectory(testCase)
            model=lmzmodels.tutorial_hopper.Model();
            problem=model.createProblem('n_stride_simulation', ...
                struct('NumberOfStrides',3));
            result=problem.simulate(lmz.api.RunContext.synchronous(0));
            testCase.verifyEqual(result.CompletedStrideCount,3);
            testCase.verifyFalse(result.Partial);
            testCase.verifyTrue(all(diff(result.Simulation.Time)>0));
            testCase.verifyTrue(all(isfinite(result.Simulation.States),'all'));
            testCase.verifyEqual(numel(result.Diagnostics.StrideBoundaries),4);
            testCase.verifyEqual(unique([result.Simulation.EventRecords. ...
                StrideIndex]),1:3);
        end

        function sourcePeriodicPlanRoundTrips(testCase)
            model=lmzmodels.slip_biped.Model();
            service=lmz.services.MultiStrideSimulationService();
            context=lmz.api.RunContext.synchronous(0);
            first=service.simulate(model,lmz.multistride.MultiStrideRequest( ...
                'NumberOfStrides',2),context);
            second=service.simulate(model,lmz.multistride.MultiStrideRequest( ...
                'NumberOfStrides',2,'StridePlan',first.Plan),context);
            testCase.verifyEqual(second.Plan.Provenance.PeriodicDecision, ...
                first.Plan.Provenance.PeriodicDecision,'AbsTol',0);
            testCase.verifyEqual(second.Simulation.Time, ...
                first.Simulation.Time,'AbsTol',0);
            testCase.verifyEqual(second.Simulation.States, ...
                first.Simulation.States,'AbsTol',0);
            testCase.verifyEqual(numel(second.Diagnostics.StrideBoundaries),2);
            testCase.verifyFalse(second.Diagnostics.HiddenTimingSolve);
        end

        function modelSimulationRequestUsesPublicTrajectory(testCase)
            model=lmzmodels.slip_quadruped.Model();
            request=lmz.api.SimulationRequest('slip_quadruped', ...
                'n_stride_simulation',struct(),struct('NumberOfStrides',2));
            simulation=model.simulate(request,lmz.api.RunContext.synchronous(0));
            testCase.verifyClass(simulation,'lmz.api.SimulationResult');
            testCase.verifyTrue(all(diff(simulation.Time)>0));
            testCase.verifyEqual(max(simulation.Modes.stride_index),2);
        end
    end
end
