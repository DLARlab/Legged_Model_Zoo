classdef TestCapabilitiesDerivedFromProblems < matlab.unittest.TestCase
    methods (Test)
        function manifestSummaryIsDescriptorAggregate(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            ids=registry.listModels();
            names={'simulate','solve','continue','optimize','visualize', ...
                'animate','parameterHomotopy','branchFamilyScan'};
            for modelIndex=1:numel(ids)
                manifest=registry.getManifest(ids{modelIndex});
                for nameIndex=1:numel(names)
                    expected=false;name=names{nameIndex};
                    for problemIndex=1:numel(manifest.problemDescriptors)
                        descriptor=manifest.problemDescriptors{problemIndex};
                        expected=expected||(descriptor.implemented&& ...
                            descriptor.capabilities.(name));
                    end
                    testCase.verifyEqual(manifest.capabilities.(name),expected);
                end
            end
        end
        function staleManifestFlagsDoNotDefineSummary(testCase)
            parent=tempname;catalogPath=fullfile(parent,'catalog');mkdir(parent);
            cleanup=onCleanup(@()removeTree(parent));
            copyfile(lmz.util.ProjectPaths.catalog(),catalogPath);
            path=fullfile(catalogPath,'slip_quadruped','manifest.json');
            manifest=jsondecode(fileread(path));
            names=fieldnames(manifest.capabilities);
            for index=1:numel(names),manifest.capabilities.(names{index})=false;end
            writeText(path,jsonencode(manifest));
            registry=lmz.registry.ModelRegistry.discover(catalogPath);
            derived=registry.getCapabilities('slip_quadruped');
            testCase.verifyTrue(derived.solve);
            testCase.verifyTrue(derived.('continue'));
            testCase.verifyTrue(derived.parameterHomotopy);
            testCase.verifyFalse(registry.getManifest('slip_quadruped'). ...
                declaredCapabilities.solve);
            clear cleanup
        end
    end
end

function writeText(path,value)
file=fopen(path,'w');cleanup=onCleanup(@()fclose(file));fprintf(file,'%s',value);clear cleanup
end
function removeTree(path),if exist(path,'dir')==7,rmdir(path,'s');end,end
