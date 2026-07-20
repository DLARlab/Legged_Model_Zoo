classdef TestBuiltInAnalyticTutorial < matlab.unittest.TestCase
    methods (Test)
        function registryWorkflowAndGenericSceneAreFunctional(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            cleanup = onCleanup(@() delete(registry));
            testCase.verifyTrue(any(strcmp( ...
                registry.listModels(), 'tutorial_hopper')));
            manifest = registry.getManifest('tutorial_hopper');
            testCase.verifyFalse(manifest.external);
            descriptor = registry.getProblemDescriptor( ...
                'tutorial_hopper', 'periodic_hop');
            testCase.verifyEqual(descriptor.maturity, 'tutorial');
            testCase.verifyEqual(descriptor.validationStatus, 'tested');

            model = registry.createModel('tutorial_hopper');
            testCase.verifyClass(model, ...
                'lmzmodels.tutorial_hopper.Model');
            demo = model.createProblem('demo_hop', struct());
            context = lmz.api.RunContext.synchronous(17);
            simulation = lmz.services.SimulationService().simulate( ...
                demo, struct(), struct(), context);
            testCase.verifyEqual(numel(simulation.EventRecords), 1);
            testCase.verifyEqual(simulation.EventRecords.Id, 'impact');
            testCase.verifyGreaterThan(min(diff(simulation.Time)), 0);

            problem = model.createProblem('periodic_hop', struct());
            decision = problem.getDecisionSchema().defaults();
            parameters = problem.getParameterSchema().defaults();
            evaluation = problem.evaluate( ...
                decision, parameters, context, true);
            testCase.verifyLessThan( ...
                evaluation.ScaledResidualNorm, 1e-10);

            perturbed = decision;
            perturbed(5) = perturbed(5) + 0.08;
            seed = problem.makeSolution(perturbed, parameters, []);
            solved = lmz.services.SolveService().solve( ...
                problem, seed, struct('MaxIterations', 100, ...
                'MaxFunctionEvaluations', 500), context);
            testCase.verifyGreaterThan(solved.ExitFlag, 0);
            testCase.verifyLessThan( ...
                solved.Evaluation.ScaledResidualNorm, 1e-9);

            second = decision;
            second(4) = second(4) + 0.02;
            second(5) = second(4) * second(2);
            firstSolution = problem.makeSolution(decision, parameters, ...
                problem.evaluate(decision, parameters, context, false));
            secondSolution = problem.makeSolution(second, parameters, ...
                problem.evaluate(second, parameters, context, false));
            metric = lmz.schema.DiagonalMetric(problem.scale(decision));
            radius = metric.norm(problem.difference(second, decision));
            pair = lmz.data.SolutionPair( ...
                firstSolution, secondSolution, radius, radius, ...
                struct('source', 'built-in-analytic-pair'));
            continuation = lmz.services.ContinuationService().run( ...
                problem, pair, struct('MaximumPoints', 4, ...
                'BothDirections', false, 'InitialStep', radius, ...
                'MaximumStep', radius), context);
            testCase.verifyEqual(continuation.Branch.pointCount(), 4);

            figureHandle = figure('Visible', 'off');
            figureCleanup = onCleanup(@() delete(figureHandle));
            renderer = model.getVisualizationPlugin().createRenderer( ...
                axes('Parent', figureHandle), evaluation.Simulation);
            handleCount = numel(renderer.Handles);
            renderer.updateFrame(numel(evaluation.Simulation.Time));
            testCase.verifyEqual(numel(renderer.Handles), handleCount);
            testCase.verifyGreaterThan(handleCount, 3);
            delete(renderer);
            clear figureCleanup cleanup
        end

        function publicExampleReturnsStructuredSuccess(testCase)
            examplePath = fullfile(lmz.util.ProjectPaths.examples(), ...
                'demo_tutorial_hopper.m');
            run(examplePath);
            testCase.verifyTrue(isstruct(output) && isscalar(output));
            testCase.verifyEqual( ...
                output.SuccessMarker, 'LMZ_TUTORIAL_HOPPER_OK');
            testCase.verifyEqual(output.PointCount, 4);
            testCase.verifyLessThan(output.ResidualNorm, 1e-9);
        end
    end
end
