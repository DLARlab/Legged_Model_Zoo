classdef TestRegisteredContactTimingSequence < matlab.unittest.TestCase
    %TESTREGISTEREDCONTACTTIMINGSEQUENCE Executable model/GUI registration.
    methods (Test)
        function tutorialSequenceIsSquareExplicitAndFixed(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            descriptor=registry.getProblemDescriptor( ...
                'tutorial_hopper','contact_timing_sequence');
            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('contact_timing_sequence', ...
                struct('NumberOfStrides',2));
            initialState=problem.FixedInitialState;
            physicalParameters=problem.FixedPhysicalParameters;
            decision=problem.getDecisionSchema().defaults();
            evaluation=problem.evaluate(decision,[], ...
                lmz.api.RunContext.synchronous(0),false);

            testCase.verifyTrue(descriptor.implemented);
            testCase.verifyTrue(descriptor.capabilities.solve);
            testCase.verifyFalse(descriptor.capabilities.simulate);
            testCase.verifyClass(problem, ...
                'lmz.multistride.ContactTimingSequenceProblem');
            testCase.verifyEqual(problem.NumberOfStrides,2);
            testCase.verifyEqual(problem.unknownDimension(),4);
            testCase.verifyEqual(problem.residualDimension(),4);
            testCase.verifyEqual(problem.getDecisionSchema().names(), ...
                {'stride_1_schedule_q_1';'stride_1_schedule_q_2'; ...
                'stride_2_schedule_q_1';'stride_2_schedule_q_2'});
            testCase.verifyLessThan(evaluation.ScaledResidualNorm,1e-10);
            testCase.verifyEqual(problem.FixedInitialState,initialState, ...
                'AbsTol',0);
            testCase.verifyEqual(problem.FixedPhysicalParameters, ...
                physicalParameters,'AbsTol',0);
            testCase.verifyFalse( ...
                evaluation.Diagnostics.StatePeriodicityImposed);
            testCase.verifyFalse(evaluation.Diagnostics.HiddenTimingSolve);
            testCase.verifyEqual(evaluation.Diagnostics.NestedSolverCalls,0);
            records=evaluation.Diagnostics.StrideEvaluations;
            testCase.verifyEqual(records{2}.InputState, ...
                records{1}.TerminalState,'AbsTol',0);
            testCase.verifyEqual({evaluation.ResidualBlocks.Name}, ...
                {'stride_1_contact_constraints', ...
                'stride_1_section_return', ...
                'stride_2_contact_constraints', ...
                'stride_2_section_return'});
            clear cleanup
        end

        function guiSolveModeUsesRegisteredSequence(testCase)
            controller=lmz.gui.AppController();
            cleanup=onCleanup(@()delete(controller.Registry));
            controller.selectModel('tutorial_hopper');
            controller.setStrideSettings(2,'error_if_missing', ...
                'return_partial',true);
            controller.setSolveMode('Timing sequence');

            testCase.verifyEqual(controller.State.ProblemId, ...
                'contact_timing_sequence');
            testCase.verifyEqual(controller.State.SolveMode,'Timing sequence');
            testCase.verifyEqual(numel( ...
                controller.State.WorkingSolution.DecisionValues),4);
            result=controller.solveWorkingSolution( ...
                struct('AcceptExistingTolerance',1e-9));
            testCase.verifyGreaterThan(result.ExitFlag,0);
            testCase.verifyLessThan(result.Evaluation.ScaledResidualNorm,1e-9);
            testCase.verifyFalse(result.Evaluation.Diagnostics. ...
                StatePeriodicityImposed);
            testCase.verifyFalse(result.Evaluation.Diagnostics.HiddenTimingSolve);
            clear cleanup
        end
    end
end
