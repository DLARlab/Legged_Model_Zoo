classdef TestRegistryDiscovery < matlab.unittest.TestCase
    methods (Test)
        function discoversModels(testCase)
            r=lmz.registry.ModelRegistry.discover(); ids=r.listModels();
            testCase.verifyEqual(ids, ...
                {'slip_biped','slip_quad_load','slip_quadruped', ...
                'tutorial_hopper'});
            testCase.verifyClass(r.createModel('slip_quadruped'), ...
                'lmzmodels.slip_quadruped.Model');
            testCase.verifyEqual(numel(ids), 4);
            for index = 1:numel(ids)
                model = r.createModel(ids{index});
                capabilities = model.getCapabilities();
                values = struct2cell(capabilities);
                testCase.verifyTrue(capabilities.simulate);
                testCase.verifyTrue(capabilities.visualize);
                if strcmp(ids{index},'slip_quad_load')
                    testCase.verifyTrue(capabilities.solve);
                    testCase.verifyTrue(capabilities.optimize);
                else
                    testCase.verifyTrue(capabilities.solve);
                    testCase.verifyTrue(capabilities.('continue'));
                end
            end
        end

        function catalogAndImplementationsAgreeOnIdentityAndVersion(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            cleanup = onCleanup(@() delete(registry));
            ids = registry.listModels();
            for index = 1:numel(ids)
                catalogManifest = registry.getManifest(ids{index});
                implementationManifest = ...
                    registry.createModel(ids{index}).getManifest();
                testCase.verifyEqual(implementationManifest.id, ...
                    catalogManifest.id);
                testCase.verifyEqual(implementationManifest.version, ...
                    catalogManifest.version);
            end
            clear cleanup
        end
    end
end
