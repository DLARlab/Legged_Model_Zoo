classdef TestCanonicalModelNames < matlab.unittest.TestCase
    methods (Test)
        function registryUsesExactNames(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            testCase.verifyEqual(registry.listModels(), ...
                {'slip_biped','slip_quad_load','slip_quadruped', ...
                'tutorial_hopper'});
        end

        function oldIdsResolveWithWarning(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            testCase.verifyWarning(@()registry.createModel( ...
                'slip.quadruped.planar.v2'), ...
                'lmz:Registry:DeprecatedModelId');
            model = registry.createModel('slip_quadruped');
            manifest = model.getManifest();
            testCase.verifyEqual(manifest.id, 'slip_quadruped');
        end
    end
end
