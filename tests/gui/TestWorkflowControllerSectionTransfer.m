classdef TestWorkflowControllerSectionTransfer < matlab.unittest.TestCase
    methods (Test)
        function touchdownAdjacentPairStaysInRegisteredTargetChart(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quadruped');
            session=controller.selectWorkflow( ...
                'touchdown_root_continuation');

            testCase.verifyEqual( ...
                controller.State.WorkingSolution.ProblemId, ...
                'periodic_orbit');
            testCase.verifyEqual( ...
                controller.State.LockedSelection.PointIndex,267);

            pair=controller.makeAdjacentSeedPair(+1,struct());

            testCase.verifyEqual(pair.First.ProblemId,'periodic_orbit');
            testCase.verifyEqual(pair.Second.ProblemId,'periodic_orbit');
            testCase.verifyNumElements(pair.First.DecisionValues,21);
            testCase.verifyTrue(pair.Diagnostics.SectionLocal);
            testCase.verifyEqual(pair.Diagnostics.SourceIndices,[267 268]);
            testCase.verifyEqual( ...
                session.SeedPair.First.DecisionValues, ...
                pair.First.DecisionValues,'AbsTol',0);
        end


        function workflowCapabilitiesEnforceAllowedSteps(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quadruped');
            controller.selectWorkflow('roadmap_explore');

            capabilities=controller.capabilities();
            testCase.verifyTrue(capabilities.simulate);
            testCase.verifyTrue(capabilities.visualize);
            testCase.verifyFalse(capabilities.solve);
            testCase.verifyFalse(capabilities.('continue'));
            testCase.verifyFalse(capabilities.parameterHomotopy);
            testCase.verifyFalse(capabilities.branchFamilyScan);
            testCase.verifyError( ...
                @()controller.solveWorkingSolution(struct()), ...
                'lmz:GUI:WorkflowStepUnavailable');
            testCase.verifyError( ...
                @()controller.makeAdjacentSeedPair(+1,struct()), ...
                'lmz:GUI:WorkflowStepUnavailable');
        end


        function registeredPresetsDriveControllerDefaults(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quadruped');
            session=controller.selectWorkflow( ...
                'roadmap_root_continuation');

            solveOptions=controller.solveDefaultOptions();
            continuationOptions=controller.continuationDefaultOptions();
            testCase.verifyEqual(solveOptions.FunctionTolerance,1e-10);
            testCase.verifyEqual(solveOptions.MaxIterations,200);
            testCase.verifyEqual(continuationOptions.InitialStep,0.02);
            testCase.verifyEqual(continuationOptions.MaximumPoints,20);
            testCase.verifyEqual(controller.generatedSeedRadius(),0.005);
            testCase.verifyEqual( ...
                controller.State.ContinuationDirectionMode,'both');

            result=controller.solveWorkingSolution(struct());
            testCase.verifyNotEmpty(session.SolveResult);
            testCase.verifyEqual(session.SolveResult.ExitFlag, ...
                result.ExitFlag);
            testCase.verifyEqual(result.Options.FunctionTolerance,1e-10);
            testCase.verifyEqual(result.Options.MaxIterations,200);
        end
    end
end
