classdef TestStandaloneSimulation < matlab.unittest.TestCase
    methods (Test)
        function allModelsSimulate(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            ids = registry.listModels();
            service = lmz.services.SimulationService();
            for index = 1:numel(ids)
                model = registry.createModel(ids{index});
                manifest = registry.getManifest(ids{index});
                kinds = cellfun(@(value) value.kind, ...
                    manifest.problemDescriptors, 'UniformOutput', false);
                maturities = cellfun(@(value) value.maturity, ...
                    manifest.problemDescriptors, 'UniformOutput', false);
                descriptorIndex = find(strcmp(kinds, 'simulation') & ...
                    strcmp(maturities, 'tutorial'), 1);
                testCase.assertNotEmpty(descriptorIndex, ...
                    sprintf('%s has no simulation tutorial.', ids{index}));
                problemId = ...
                    manifest.problemDescriptors{descriptorIndex}.id;
                problem = model.createProblem(problemId, struct());
                result = service.simulate(problem, struct(), struct(), ...
                    lmz.api.RunContext.synchronous(index));
                testCase.verifyClass(result, 'lmz.api.SimulationResult');
                testCase.verifyGreaterThan(numel(result.Time), 100);
                testCase.verifyEqual(result.Provenance.modelId, ids{index});
                testCase.verifyEqual(result.Provenance.problemId, problemId);
            end
        end
    end
end
