classdef TestStandaloneSimulation < matlab.unittest.TestCase
    methods (Test)
        function allModelsSimulate(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            ids = registry.listModels();
            service = lmz.services.SimulationService();
            for index = 1:numel(ids)
                model = registry.createModel(ids{index});
                problem = model.createProblem('demo_stride', struct());
                result = service.simulate(problem, struct(), struct(), ...
                    lmz.api.RunContext.synchronous(index));
                testCase.verifyClass(result, 'lmz.api.SimulationResult');
                testCase.verifyGreaterThan(numel(result.Time), 100);
                testCase.verifyEqual(result.Provenance.modelId, ids{index});
            end
        end
    end
end
