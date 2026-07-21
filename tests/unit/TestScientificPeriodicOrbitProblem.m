classdef TestScientificPeriodicOrbitProblem < matlab.unittest.TestCase
    methods (Test)
        function quadrupedDefaultIsExactApexPreset(testCase)
            [model, apex, configured, context] = ...
                localProblems('slip_quadruped', struct(), 921);
            u = apex.getDecisionSchema().defaults();
            p = apex.getParameterSchema().defaults();
            source = apex.evaluate(u, p, context, true);
            actual = configured.evaluate(u, p, context, true);

            testCase.verifyEqual(actual.Residual, source.Residual);
            testCase.verifyEqual(actual.ScaledResidual, ...
                source.ScaledResidual);
            testCase.verifyEqual(actual.Simulation.Time, ...
                source.Simulation.Time);
            testCase.verifyEqual(actual.Simulation.States, ...
                source.Simulation.States);
            testCase.verifyTrue( ...
                actual.Diagnostics.PeriodicOrbit.ApexPresetEquivalent);
            testCase.verifyFalse( ...
                actual.Diagnostics.PeriodicOrbit.HiddenTimingSolve);
            testCase.verifyClass(model, ...
                'lmzmodels.slip_quadruped.Model');
        end

        function bipedDefaultIsExactApexPreset(testCase)
            [~, apex, configured, context] = ...
                localProblems('slip_biped', struct(), 922);
            u = apex.getDecisionSchema().defaults();
            p = apex.getParameterSchema().defaults();
            source = apex.evaluate(u, p, context, true);
            actual = configured.evaluate(u, p, context, true);

            testCase.verifyEqual(actual.Residual, source.Residual);
            testCase.verifyEqual(actual.ScaledResidual, ...
                source.ScaledResidual);
            testCase.verifyEqual(actual.Simulation.Time, ...
                source.Simulation.Time);
            testCase.verifyEqual(actual.Simulation.States, ...
                source.Simulation.States);
            testCase.verifyTrue( ...
                actual.Diagnostics.PeriodicOrbit.ApexPresetEquivalent);
            testCase.verifyFalse( ...
                actual.Diagnostics.PeriodicOrbit.HiddenTimingSolve);
        end

        function quadrupedTouchdownUsesTrueConsecutiveReturn(testCase)
            configuration = struct( ...
                'StartSectionId', 'back_left_touchdown', ...
                'StopSectionId', 'back_left_touchdown', ...
                'StartStateSide', 'post', 'StopStateSide', 'post', ...
                'StrideCount', 1, 'SymmetryId', 'planar_translation');
            [model, apex, problem, context] = ...
                localProblems('slip_quadruped', configuration, 923);
            u = apex.getDecisionSchema().defaults();
            p = apex.getParameterSchema().defaults();
            evaluation = problem.evaluate(u, p, context, true);

            sectionBlock = evaluation.ResidualBlocks(3);
            testCase.verifyEqual(sectionBlock.Name, 'section_periodicity');
            testCase.verifyNumElements(sectionBlock.Values, 13);
            testCase.verifyLessThan(norm(sectionBlock.Values), 1e-8);
            testCase.verifyFalse(evaluation.Diagnostics.HiddenTimingSolve);
            testCase.verifyTrue(evaluation.Diagnostics.RephasedSimulation);
            testCase.verifyGreaterThan(min(diff( ...
                evaluation.Simulation.Time)), 0);
            testCase.verifyEqual(evaluation.Simulation.States(1, :).', ...
                evaluation.Diagnostics.StartCrossing.state, ...
                'AbsTol', 2e-12);
            solution = problem.makeSolution(u, p, evaluation);
            testCase.verifyEqual(solution.ProblemId, 'periodic_orbit');
            testCase.verifyEqual(solution.Lineage.StartSectionHash, ...
                evaluation.Diagnostics.StartSectionHash);
            solved = lmz.services.SolveService().solve( ...
                problem, solution, struct(), context);
            testCase.verifyGreaterThan(solved.ExitFlag, 0);
            testCase.verifyLessThan( ...
                solved.Evaluation.ScaledResidualNorm, 1e-8);
            testCase.verifyEqual(solved.Output.algorithm, ...
                'accepted-existing-seed');
            retransferred = lmz.services.SectionTransferService().transfer( ...
                model, solution, 'back_left_liftoff', context);
            testCase.verifyEqual( ...
                retransferred.Lineage.SourceSectionId, ...
                'back_left_touchdown');
            testCase.verifyTrue(retransferred.DecisionCodecRephased);
            testCase.verifyEqual(retransferred.Solution.ProblemId, ...
                'periodic_orbit');

            perturbed = u;
            perturbed(2) = perturbed(2) + 5e-3;
            offOrbit = problem.evaluate(perturbed, p, context, false);
            testCase.verifyGreaterThan(norm( ...
                offOrbit.ResidualBlocks(3).Values), 1e-6);
            testCase.verifyFalse(offOrbit.Diagnostics.RephasedSimulation);
        end

        function bipedTouchdownUsesTrueConsecutiveReturn(testCase)
            configuration = struct( ...
                'StartSectionId', 'left_touchdown', ...
                'StopSectionId', 'left_touchdown', ...
                'StartStateSide', 'post', 'StopStateSide', 'post', ...
                'StrideCount', 1, 'SymmetryId', 'planar_translation');
            [model, apex, problem, context] = ...
                localProblems('slip_biped', configuration, 924);
            u = apex.getDecisionSchema().defaults();
            p = apex.getParameterSchema().defaults();
            evaluation = problem.evaluate(u, p, context, true);

            sectionBlock = evaluation.ResidualBlocks(1);
            testCase.verifyEqual(sectionBlock.Name, 'section_periodicity');
            testCase.verifyNumElements(sectionBlock.Values, 7);
            testCase.verifyLessThan(norm(sectionBlock.Values), 1e-9);
            testCase.verifyFalse(evaluation.Diagnostics.HiddenTimingSolve);
            testCase.verifyTrue(evaluation.Diagnostics.RephasedSimulation);
            testCase.verifyGreaterThan(min(diff( ...
                evaluation.Simulation.Time)), 0);
            solution = problem.makeSolution(u, p, evaluation);
            retransferred = lmz.services.SectionTransferService().transfer( ...
                model, solution, 'left_liftoff', context);
            testCase.verifyEqual(retransferred.Lineage.SourceSectionId, ...
                'left_touchdown');
            testCase.verifyTrue(retransferred.DecisionCodecRephased);
            testCase.verifyEqual(retransferred.Solution.ProblemId, ...
                'periodic_orbit');

            perturbed = u;
            perturbed(2) = perturbed(2) + 5e-3;
            offOrbit = problem.evaluate(perturbed, p, context, false);
            testCase.verifyGreaterThan(norm( ...
                offOrbit.ResidualBlocks(1).Values), 1e-6);
        end

        function transferAllowsDifferentSectionCoordinateCounts(testCase)
            [model, apex, ~, context] = ...
                localProblems('slip_quadruped', struct(), 925);
            u = apex.getDecisionSchema().defaults();
            p = apex.getParameterSchema().defaults();
            evaluation = apex.evaluate(u, p, context, true);
            source = apex.makeSolution(u, p, evaluation);

            result = lmz.services.SectionTransferService().transfer( ...
                model, source, 'back_left_touchdown', context);
            testCase.verifyEqual(result.Crossing.SectionId, ...
                'back_left_touchdown');
            testCase.verifyEqual(result.Lineage.SourceSectionId, 'apex');
            testCase.verifyEqual(result.Lineage.TargetSectionId, ...
                'back_left_touchdown');
            testCase.verifyEqual(result.Simulation.States(1, :).', ...
                result.Crossing.State, 'AbsTol', 2e-12);
            testCase.verifyGreaterThan(min(diff(result.Simulation.Time)), 0);
            testCase.verifyGreaterThanOrEqual( ...
                result.PhysicalOrbitMaxError,0);
            testCase.verifyLessThanOrEqual( ...
                result.PhysicalOrbitMaxError,1e-12);
            testCase.verifyTrue( ...
                result.PhaseInvariantObservablesPreserved);
            testCase.verifyTrue(result.DecisionCodecRephased);
            testCase.verifyEqual(result.Solution.ProblemId, ...
                'periodic_orbit');
        end

        function transferLocatorPreservesTutorialStatePlane(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            model = registry.createModel('tutorial_hopper');
            problem = model.createProblem('periodic_hop', struct());
            u = problem.getDecisionSchema().defaults();
            p = problem.getParameterSchema().defaults();
            context = lmz.api.RunContext.synchronous(926);
            evaluation = problem.evaluate(u, p, context, true);
            source = problem.makeSolution(u, p, evaluation);

            result = lmz.services.SectionTransferService().transfer( ...
                model, source, 'height_descending', context);
            testCase.verifyEqual(result.Crossing.SectionId, ...
                'height_descending');
            testCase.verifyEqual(result.Simulation.States(1, 3), ...
                0.1, 'AbsTol', 2e-12);
            testCase.verifyGreaterThan(min(diff(result.Simulation.Time)), 0);
            testCase.verifyTrue(result.DecisionCodecRephased);
            testCase.verifyEqual(result.Solution.ProblemId, ...
                'periodic_orbit');
        end
    end
end

function [model, apex, configured, context] = ...
        localProblems(modelId, configuration, seed)
registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel(modelId);
apex = model.createProblem('periodic_apex', struct());
configured = model.createProblem('periodic_orbit', configuration);
context = lmz.api.RunContext.synchronous(seed);
end
