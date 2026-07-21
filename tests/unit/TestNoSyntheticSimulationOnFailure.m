classdef TestNoSyntheticSimulationOnFailure < matlab.unittest.TestCase
    methods (Test)
        function unresolvedPhysicalHorizonReturnsNoSyntheticSimulation(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            replay=evidence.replay('case_a_fixed_controls_best_known', ...
                lmz.api.RunContext.synchronous(0),false);
            simulations=cellfun(@(item)item.Simulation, ...
                replay.Residual.SegmentResults,'UniformOutput',false);
            testCase.verifyTrue(all(cellfun(@isempty,simulations)));
            status=evidence.horizonStatus();
            testCase.verifyFalse(status.syntheticCarryForwardUsed);
            testCase.verifyFalse( ...
                status.physicalFiveStrideSimulationPublished);
        end
    end
end
