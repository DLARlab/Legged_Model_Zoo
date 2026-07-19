classdef TestRegistryDiscovery < matlab.unittest.TestCase
    methods (Test)
        function discoversModels(testCase)
            r=lmz.registry.ModelRegistry.discover(); ids=r.listModels();
            testCase.verifyEqual(ids, ...
                {'slip_biped','slip_quad_load','slip_quadruped'});
            testCase.verifyClass(r.createModel('slip_quadruped'), ...
                'lmzmodels.slip_quadruped.Model');
            testCase.verifyEqual(numel(ids), 3);
            for index = 1:numel(ids)
                model = r.createModel(ids{index});
                capabilities = model.getCapabilities();
                values = struct2cell(capabilities);
                testCase.verifyTrue(capabilities.simulate);
                testCase.verifyTrue(capabilities.visualize);
                testCase.verifyFalse(capabilities.solve);
            end
        end
    end
end
