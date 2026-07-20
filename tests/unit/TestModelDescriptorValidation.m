classdef TestModelDescriptorValidation < matlab.unittest.TestCase
    methods (Test)
        function discoversCatalogInPathWithSpaces(testCase)
            parent = tempname;
            catalogPath = fullfile(parent, 'catalog with spaces');
            mkdir(parent);
            cleanup = onCleanup(@() removeTree(parent));
            copyfile(lmz.util.ProjectPaths.catalog(), catalogPath);
            registry = lmz.registry.ModelRegistry.discover(catalogPath);
            testCase.verifyEqual(numel(registry.listModels()), 4);
            clear cleanup
        end

        function rejectsMissingDescriptor(testCase)
            parent = tempname;
            modelPath = fullfile(parent, 'missing_model');
            mkdir(modelPath);
            cleanup = onCleanup(@() removeTree(parent));
            manifest = ['{"schemaVersion":"1.0.0",' ...
                '"id":"missing_model","version":"1.0.0",' ...
                '"name":"Missing","implementationClass":' ...
                '"lmzmodels.slip_quadruped.Model",' ...
                '"problems":["absent"],"capabilities":{' ...
                '"simulate":false,"solve":false,"continue":false,' ...
                '"optimize":false,"visualize":false}}'];
            writeText(fullfile(modelPath, 'manifest.json'), manifest);
            testCase.verifyError(@() ...
                lmz.registry.ModelRegistry.discover(parent), ...
                'lmz:Registry:MissingProblemDescriptor');
            clear cleanup
        end
    end
end

function writeText(path, value)
file = fopen(path, 'w');
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', value);
clear cleanup
end

function removeTree(path)
if exist(path, 'dir') == 7
    rmdir(path, 's');
end
end
