classdef TestQuadLoadNStridePeriodicProblem < matlab.unittest.TestCase
    methods (Test)
        function codecRoundTripsCompleteLegacyVectors(testCase)
            catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog. ...
                default();
            for count = 1:2
                if count == 1
                    path = catalog.defaultSinglePath();
                else
                    path = catalog.defaultMultiPath();
                end
                dataset = lmzmodels.slip_quad_load.XAccumAdapter. ...
                    loadDataset(path);
                codec = lmzmodels.slip_quad_load.NStridePeriodicCodec( ...
                    dataset.XAccum);
                actual = codec.expand(codec.decisionDefaults(), ...
                    codec.parameterDefaults());
                testCase.verifyEqual(actual, dataset.XAccum);
                testCase.verifyEqual(codec.DecisionSchema.count(), ...
                    15 + 9 * count);
                testCase.verifyEqual(codec.ParameterSchema.count(), ...
                    numel(dataset.XAccum) - 15 - 9 * count);
            end
        end

        function twoStrideProblemHasContactsAndFinalClosureOnly(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            model = registry.createModel('slip_quad_load');
            problem = model.createProblem('n_stride_periodic', ...
                struct('NumberOfStrides', 2));
            u = problem.getDecisionSchema().defaults();
            p = problem.getParameterSchema().defaults();
            evaluation = problem.evaluate(u, p, ...
                lmz.api.RunContext.synchronous(933), false);

            testCase.verifyEqual({evaluation.ResidualBlocks.Name}, ...
                {'stride_1_contact_constraints', ...
                'stride_2_contact_constraints', ...
                'final_section_closure'});
            testCase.verifyNumElements( ...
                evaluation.ResidualBlocks(1).Values, 9);
            testCase.verifyNumElements( ...
                evaluation.ResidualBlocks(2).Values, 9);
            testCase.verifyNumElements( ...
                evaluation.ResidualBlocks(3).Values, 16);
            testCase.verifyNumElements(evaluation.Residual, 34);
            testCase.verifyEqual(problem.expectedLocalDimension(), 1);
            testCase.verifyTrue( ...
                evaluation.Diagnostics.FinalReturnClosureOnly);
            testCase.verifyFalse( ...
                evaluation.Diagnostics.IntermediatePeriodicityImposed);
            testCase.verifyFalse(evaluation.Diagnostics.HiddenTimingSolve);
            testCase.verifyTrue( ...
                evaluation.Diagnostics.EventTimingVariablesExplicit);
        end

        function missingLaterStrideIsRejectedBeforeEvaluation(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            model = registry.createModel('slip_quad_load');
            catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog. ...
                default();
            dataset = lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
                catalog.defaultMultiPath());
            configuration = struct('NumberOfStrides', 3, ...
                'InitialDecision', dataset.XAccum);
            testCase.verifyError(@() model.createProblem( ...
                'n_stride_periodic', configuration), ...
                'lmz:QuadLoad:PeriodicIncompleteDecision');
        end

        function completeThreeStrideCodecIsAccepted(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            model = registry.createModel('slip_quad_load');
            catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog. ...
                default();
            dataset = lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
                catalog.defaultMultiPath());
            indices = lmzmodels.slip_quad_load.LaterStrideLayout. ...
                globalIndices(2);
            complete = [dataset.XAccum; dataset.XAccum(indices.Block)];
            problem = model.createProblem('n_stride_periodic', struct( ...
                'NumberOfStrides', 3, 'InitialDecision', complete));
            testCase.verifyEqual(problem.getDecisionSchema().count(), 42);
            testCase.verifyEqual(problem.getParameterSchema().count(), 28);
            testCase.verifyEqual(problem.contract().NumberOfStrides, 3);
            testCase.verifyEqual(problem.contract().TimingMode, ...
                'explicit_variables');
        end

        function oneStrideJacobianHasOneDimensionalNullspace(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            model = registry.createModel('slip_quad_load');
            problem = model.createProblem('n_stride_periodic', ...
                struct('NumberOfStrides', 1));
            u = problem.getDecisionSchema().defaults();
            p = problem.getParameterSchema().defaults();
            context = lmz.api.RunContext.synchronous(934);
            baseline = problem.residual(u, p, context);
            jacobian = zeros(numel(baseline), numel(u));
            for index = 1:numel(u)
                step = 1e-6 * max(1, abs(u(index)));
                candidate = u;
                candidate(index) = candidate(index) + step;
                jacobian(:, index) = ...
                    (problem.residual(candidate, p, context) - ...
                    baseline) / step;
            end
            numericalRank = rank(jacobian, 1e-8);
            testCase.verifyEqual(numel(u) - numericalRank, ...
                problem.expectedLocalDimension());
        end
    end
end
