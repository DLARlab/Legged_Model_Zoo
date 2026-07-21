classdef TestQuadrupedCompositeSectionShooting < matlab.unittest.TestCase
    methods (Test)
        function touchdownWhileDescendingIsAccepted(testCase)
            model=lmz.registry.ModelRegistry.discover(). ...
                createModel('slip_quadruped');
            problem=model.createProblem('periodic_orbit', ...
                localConfiguration('back_left_touchdown_descending'));
            u=problem.getDecisionSchema().defaults();
            evaluation=problem.evaluate(u, ...
                problem.getParameterSchema().defaults(), ...
                lmz.api.RunContext.synchronous(1120),true);
            dyIndex=evaluation.Simulation.StateSchema.indexOf('dy');
            testCase.verifyLessThan(evaluation.ScaledResidualNorm,1e-8);
            testCase.verifyTrue(evaluation.PhysicalValidity);
            testCase.verifyTrue( ...
                evaluation.Diagnostics.DirectSectionIntegration);
            testCase.verifyTrue(evaluation.Diagnostics.StopCrossing.accepted);
            testCase.verifyEqual( ...
                evaluation.Diagnostics.StopCrossing.stateSide,'post');
            testCase.verifyLessThan( ...
                evaluation.Simulation.States(end,dyIndex),0);
        end
    end
end

function value=localConfiguration(sectionId)
value=struct('StartSectionId',sectionId,'StopSectionId',sectionId, ...
    'SymmetryId','planar_translation');
end
