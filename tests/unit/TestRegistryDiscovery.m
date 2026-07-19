classdef TestRegistryDiscovery < matlab.unittest.TestCase
    methods (Test)
        function discoversModels(testCase)
            r=lmz.registry.ModelRegistry.discover(); ids=r.listModels();
            testCase.verifyTrue(any(strcmp(ids,'slip.quadruped.planar.v2')));
            testCase.verifyClass(r.createModel('slip.quadruped.planar.v2'),'lmzmodels.slipquadruped.Model');
        end
    end
end
