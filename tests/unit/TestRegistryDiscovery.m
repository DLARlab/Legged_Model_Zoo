classdef TestRegistryDiscovery < matlab.unittest.TestCase
    methods (Test)
        function discoversModels(testCase)
            r=lmz.registry.ModelRegistry.discover(); ids=r.listModels();
            testCase.verifyTrue(any(strcmp(ids,'slip.quadruped.planar.v2')));
            testCase.verifyClass(r.createModel('slip.quadruped.planar.v2'),'lmzmodels.slipquadruped.Model');
            testCase.verifyEqual(numel(ids), 3);
            for index = 1:numel(ids)
                model = r.createModel(ids{index});
                capabilities = model.getCapabilities();
                values = struct2cell(capabilities);
                testCase.verifyFalse(any([values{:}]));
            end
        end
    end
end
