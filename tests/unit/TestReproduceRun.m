classdef TestReproduceRun < matlab.unittest.TestCase
    methods (Test)
        function solveOptionsAndLineageAreReconstructed(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            problem = registry.createModel('slip_biped').createProblem( ...
                'periodic_apex', struct());
            catalog = lmzmodels.slip_biped.GaitMapCatalog.default();
            branch = catalog.loadBranch( ...
                catalog.defaultBranchPath(), problem, true);
            index = catalog.recommendedSeedIndex(catalog.defaultBranchPath());
            seed = branch.point(index);
            context = lmz.api.RunContext.synchronous(71);
            options = struct('AcceptExistingTolerance', 1e-7);
            original = lmz.services.SolveService().solve( ...
                problem, seed, options, context);
            artifact = original.toArtifact();
            values = struct2cell(artifact.sourceDataHashes);
            builtIn = cellfun(@(value) isstruct(value) && ...
                isfield(value, 'relativePath') && ...
                ~isempty(value.relativePath), values);
            testCase.verifyTrue(any(builtIn), ...
                'Normal scientific run metadata must retain verifiable paths.');
            artifact.sourceDataHashes.fixture = struct( ...
                'relativePath', 'VERSION', ...
                'sha256', lmz.util.FileHash.sha256(fullfile( ...
                lmz.util.ProjectPaths.root(), 'VERSION')));
            [reproduced, report] = lmz.services.reproduceRun(artifact);
            testCase.verifyClass(reproduced, 'lmz.data.SolveResult');
            testCase.verifyEqual(report.Options, options);
            testCase.verifyEqual(report.RandomSeed, 71);
            testCase.verifyEqual(report.SourceArtifactId, seed.Id);
            fixture = find(strcmp({report.HashChecks.Name}, 'fixture'), 1);
            testCase.verifyNotEmpty(fixture);
            testCase.verifyTrue(report.HashChecks(fixture).Verified);
            testCase.verifyGreaterThanOrEqual(report.VerifiedHashCount, 3);
            testCase.verifyEqual(reproduced.Solution.DecisionValues, ...
                original.Solution.DecisionValues, 'AbsTol', 1e-10);
            artifact.sourceDataHashes.fixture.sha256 = repmat('0', 1, 64);
            testCase.verifyError(@() lmz.services.reproduceRun(artifact), ...
                'lmz:Reproduce:SourceHashMismatch');
        end

        function continuationOptionsPairAndConfigurationAreReconstructed(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            model = registry.createModel('tutorial_hopper');
            configuration = struct('AuthoringCase', 'reproduce-run');
            problem = model.createProblem('periodic_hop', configuration);
            context = lmz.api.RunContext.synchronous(72);
            firstDecision = problem.getDecisionSchema().defaults();
            parameters = problem.getParameterSchema().defaults();
            secondDecision = firstDecision;
            secondDecision(4) = secondDecision(4) + 0.02;
            secondDecision(5) = secondDecision(4) * secondDecision(2);
            first = problem.makeSolution(firstDecision, parameters, ...
                problem.evaluate(firstDecision, parameters, context, false));
            second = problem.makeSolution(secondDecision, parameters, ...
                problem.evaluate(secondDecision, parameters, context, false));
            metric = lmz.schema.DiagonalMetric(problem.scale(firstDecision));
            radius = metric.norm(problem.difference( ...
                secondDecision, firstDecision));
            pair = lmz.data.SolutionPair(first, second, radius, radius, ...
                struct('source', 'reproduction-test'));
            original = lmz.services.ContinuationService().run(problem, pair, ...
                struct('MaximumPoints', 3, 'BothDirections', false, ...
                'InitialStep', radius, 'MaximumStep', radius), context);
            artifact = original.toArtifact();
            testCase.verifyEqual( ...
                artifact.problemMetadata.configuration, configuration);
            [reproduced, report] = lmz.services.reproduceRun(artifact);
            testCase.verifyClass(reproduced, 'lmz.data.ContinuationResult');
            testCase.verifyEqual(report.Options, original.Options);
            testCase.verifyEqual(report.RandomSeed, 72);
            testCase.verifyEqual(reproduced.Branch.pointCount(), ...
                original.Branch.pointCount());
        end

        function optimizationOptionsDataHashAndConfigurationAreReconstructed(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            datasetPath = fullfile(lmz.util.ProjectPaths.examples(), ...
                'data', 'slip_biped', 'trajectory_fit', ...
                'exp_1802_j30.mat');
            configuration = struct('EnforceConstraints', false, ...
                'DatasetPath', datasetPath);
            problem = registry.createModel('slip_biped').createProblem( ...
                'trajectory_fit', configuration);
            values = problem.sourceSeed();
            values(1) = values(1) + 0.01;
            seed = problem.makeSolution(values, ...
                problem.getParameterSchema().defaults(), []);
            options = struct('Algorithm', 'sqp', 'MaxIterations', 1, ...
                'MaxFunctionEvaluations', 8, 'OptimalityTolerance', 1e-3, ...
                'StepTolerance', 1e-3, 'ConstraintTolerance', 0.2);
            original = lmz.services.OptimizationService().run( ...
                problem, seed, options, lmz.api.RunContext.synchronous(73));
            artifact = original.toArtifact();
            testCase.verifyEqual( ...
                artifact.problemMetadata.configuration, configuration);
            [reproduced, report] = lmz.services.reproduceRun(artifact);
            testCase.verifyClass(reproduced, 'lmz.data.OptimizationResult');
            testCase.verifyEqual(report.Options, original.Options);
            testCase.verifyEqual(report.RandomSeed, 73);
            testCase.verifyGreaterThanOrEqual(report.VerifiedHashCount, 1);
            testCase.verifyEqual(reproduced.Solution.DecisionValues, ...
                original.Solution.DecisionValues, 'AbsTol', 1e-7);
        end
    end
end
