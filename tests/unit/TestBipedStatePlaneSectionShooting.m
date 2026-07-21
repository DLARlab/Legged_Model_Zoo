classdef TestBipedStatePlaneSectionShooting < matlab.unittest.TestCase
    methods (Test)
        function descendingPlaneCorrectsToTransverseReturn(testCase)
            model=lmz.registry.ModelRegistry.discover(). ...
                createModel('slip_biped');
            problem=model.createProblem('periodic_orbit', ...
                localConfiguration('descending_y_0_95'));
            u=problem.getDecisionSchema().defaults();
            p=problem.getParameterSchema().defaults();
            seed=problem.makeSolution(u,p,[]);
            solved=lmz.services.SolveService().solve(problem,seed, ...
                localOptions(),lmz.api.RunContext.synchronous(1140));
            crossing=solved.Evaluation.Diagnostics.StopCrossing;
            testCase.verifyGreaterThan(solved.ExitFlag,0);
            testCase.verifyLessThan( ...
                solved.Evaluation.ScaledResidualNorm,1e-9);
            testCase.verifyTrue(solved.Evaluation.PhysicalValidity);
            testCase.verifyTrue(solved.Evaluation.Diagnostics. ...
                DirectSectionIntegration);
            testCase.verifyTrue(crossing.accepted);
            testCase.verifyFalse(crossing.grazing);
            testCase.verifyEqual(crossing.crossingDirection,-1);
            testCase.verifyLessThan(crossing.directionalDerivative,0);
            testCase.verifyNumElements(solved.Solution.DecisionValues,11);
        end
    end
end

function value=localConfiguration(sectionId)
value=struct('StartSectionId',sectionId,'StopSectionId',sectionId, ...
    'SymmetryId','planar_translation');
end

function value=localOptions()
value=struct('FunctionTolerance',1e-10,'StepTolerance',1e-10, ...
    'MaximumIterations',100,'AcceptExistingTolerance',1e-10);
end
