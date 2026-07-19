classdef TestStandaloneBuiltInData < matlab.unittest.TestCase
    methods (Test)
        function everyModelHasLoadableExample(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            service = lmz.services.DataService();
            ids = registry.listModels();
            for index = 1:numel(ids)
                examples = service.listBuiltInExamples(ids{index});
                testCase.verifyNotEmpty(examples);
                value = service.loadBuiltInExample(ids{index}, examples{1});
                testCase.verifyEqual(value.modelId, ids{index});
            end
        end
    end
end
