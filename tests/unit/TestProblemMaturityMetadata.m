classdef TestProblemMaturityMetadata < matlab.unittest.TestCase
    methods (Test)
        function everyDescriptorHasValidatedMetadata(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            modelIds=registry.listModels();
            maturityValues={'tutorial','compatibility','validated','experimental'};
            validationValues={'untested','tested','source-equivalent'};
            capabilityNames={'simulate','solve','continue','optimize', ...
                'visualize','animate','parameterHomotopy','branchFamilyScan'};
            for modelIndex=1:numel(modelIds)
                manifest=registry.getManifest(modelIds{modelIndex});
                for problemIndex=1:numel(manifest.problemDescriptors)
                    descriptor=manifest.problemDescriptors{problemIndex};
                    testCase.verifyTrue(any(strcmp(descriptor.maturity,maturityValues)));
                    testCase.verifyTrue(any(strcmp(descriptor.validationStatus,validationValues)));
                    testCase.verifyTrue(isstruct(descriptor.provenance)&&isscalar(descriptor.provenance));
                    for capabilityIndex=1:numel(capabilityNames)
                        name=capabilityNames{capabilityIndex};
                        testCase.verifyTrue(isfield(descriptor.capabilities,name));
                        testCase.verifyTrue(islogical(descriptor.capabilities.(name))&& ...
                            isscalar(descriptor.capabilities.(name)));
                    end
                end
            end
        end
        function baseProblemExposesCatalogDescriptor(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quadruped').createProblem( ...
                'periodic_apex',struct());
            descriptor=problem.getDescriptor();
            testCase.verifyEqual(descriptor.maturity,'validated');
            testCase.verifyEqual(descriptor.validationStatus,'source-equivalent');
            testCase.verifyTrue(descriptor.capabilities.solve);
            testCase.verifyEqual(descriptor.modelId,'slip_quadruped');
        end
    end
end
