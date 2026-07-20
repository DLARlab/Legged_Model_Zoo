classdef TestExternalAnalyticPlugin < matlab.unittest.TestCase
    methods (Test)
        function discoverSimulateSolveContinueRenderAndRemove(testCase)
            [pluginRoot, cleanup] = copyPlugin();
            codeRoot = fullfile(pluginRoot, 'models');
            testCase.verifyFalse(pathContains(codeRoot));
            registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot, 'IncludeBuiltIns', false);
            registryCleanup = onCleanup(@() delete(registry));
            testCase.verifyEqual(registry.listModels(), {'analytic_hopper'});
            descriptor = registry.getProblemDescriptor( ...
                'analytic_hopper', 'periodic_hop');
            testCase.verifyTrue(descriptor.capabilities.solve);
            testCase.verifyEqual(descriptor.maturity, 'experimental');

            controller = lmz.gui.AppController(registry, ...
                lmz.api.RunContext.synchronous(71));
            testCase.verifyEqual(controller.modelIds(), {'analytic_hopper'});
            testCase.verifyEqual(controller.State.ModelId, 'analytic_hopper');
            testCase.verifyEqual(controller.State.ProblemId, 'periodic_hop');
            guiCapabilities = controller.problemCapabilities();
            testCase.verifyTrue(guiCapabilities.simulate);
            testCase.verifyTrue(guiCapabilities.solve);
            testCase.verifyTrue(guiCapabilities.('continue'));
            badge = lmz.gui.components.ProblemBadge.selectorLabel(descriptor);
            testCase.verifyNotEmpty(strfind(badge, 'Experimental')); %#ok<STREMP>
            testCase.verifyNotEmpty(strfind(badge, 'Tested')); %#ok<STREMP>
            guiSimulation = controller.simulateWorkingSolution();
            testCase.verifyClass(guiSimulation, 'lmz.api.SimulationResult');

            model = registry.createModel('analytic_hopper');
            problem = model.createProblem('periodic_hop', struct());
            context = lmz.api.RunContext.synchronous(71);
            u = problem.getDecisionSchema().defaults();
            p = problem.getParameterSchema().defaults();
            evaluation = problem.evaluate(u, p, context, true);
            testCase.verifyLessThan(evaluation.ScaledResidualNorm, 1e-10);
            simulation = evaluation.Simulation;
            testCase.verifyEqual(numel(simulation.EventRecords), 1);
            testCase.verifyEqual(simulation.EventRecords.Id, 'impact');
            testCase.verifyEqual(simulation.EventRecords.FromMode, 'flight_down');
            testCase.verifyEqual(simulation.EventRecords.ToMode, 'flight_up');
            testCase.verifyGreaterThan(simulation.EventRecords.PostState(4), 0);
            testCase.verifyGreaterThan(min(diff(simulation.Time)), 0);
            testCase.verifyEqual(simulation.States(end, 3), u(1), 'AbsTol', 2e-8);

            perturbed = u; perturbed(5) = perturbed(5) + 0.08;
            seed = problem.makeSolution(perturbed, p, []);
            solved = lmz.services.SolveService().solve(problem, seed, ...
                struct('MaxIterations', 100, ...
                'MaxFunctionEvaluations', 500), context);
            testCase.verifyGreaterThan(solved.ExitFlag, 0);
            testCase.verifyLessThan(solved.Evaluation.ScaledResidualNorm, 1e-9);

            second = u; second(4) = second(4) + 0.02;
            second(5) = second(4) * second(2);
            firstSolution = problem.makeSolution(u, p, ...
                problem.evaluate(u, p, context, false));
            secondSolution = problem.makeSolution(second, p, ...
                problem.evaluate(second, p, context, false));
            metric = lmz.schema.DiagonalMetric(problem.scale(u));
            radius = metric.norm(problem.difference(second, u));
            pair = lmz.data.SolutionPair(firstSolution, secondSolution, ...
                radius, radius, struct('source', 'analytic-exact-pair'));
            continuation = lmz.services.ContinuationService().run( ...
                problem, pair, struct('MaximumPoints', 4, ...
                'BothDirections', false, 'InitialStep', radius, ...
                'MaximumStep', radius), context);
            testCase.verifyEqual(continuation.Branch.pointCount(), 4);
            testCase.verifyLessThan(norm(problem.residual( ...
                continuation.Branch.point(4).DecisionValues, p, context)), 1e-8);

            artifactPath = fullfile(pluginRoot, 'hopper-solution.lmz.mat');
            lmz.io.ArtifactStore.save(artifactPath, firstSolution.toArtifact());
            restored = lmz.data.Solution.fromArtifact( ...
                lmz.io.ArtifactStore.load(artifactPath));
            testCase.verifyEqual(restored.DecisionValues, u, 'AbsTol', 0);
            plugin = model.getVisualizationPlugin();
            testCase.verifyClass(plugin, 'lmzplugins.analytic_hopper.HopperPlotPlugin');
            testCase.verifyClass(plugin.kinematicsFrame(simulation, 1), ...
                'lmz.viz.KinematicsFrame');

            plugin = []; restored = []; continuation = []; pair = [];
            secondSolution = []; firstSolution = []; solved = []; seed = [];
            evaluation = []; simulation = []; problem = []; model = [];
            guiSimulation = []; controller = [];
            clear registryCleanup
            testCase.verifyFalse(pathContains(codeRoot));
            builtIn = lmz.registry.ModelRegistry.discover();
            builtInCleanup = onCleanup(@() delete(builtIn));
            testCase.verifyFalse(any(strcmp(builtIn.listModels(), 'analytic_hopper')));
            clear builtInCleanup cleanup
        end
    end
end

function [target, cleanup] = copyPlugin()
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
source = fullfile(root, 'tests', 'fixtures', 'external_plugins', 'analytic_hopper');
target = [tempname '_analytic_hopper'];
copyfile(source, target);
cleanup = onCleanup(@() removeTree(target));
end

function tf = pathContains(value)
tf = any(strcmp(regexp(path, pathsep, 'split'), ...
    lmz.util.PathGuard.canonical(value, true)));
end

function removeTree(value)
if exist(value, 'dir') == 7, rmdir(value, 's'); end
end
