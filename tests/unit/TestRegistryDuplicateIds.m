classdef TestRegistryDuplicateIds < matlab.unittest.TestCase
    methods (Test)
        function rejectsDuplicateModelIds(testCase)
            parent = tempname;
            mkdir(parent);
            cleanup = onCleanup(@() removeTree(parent));
            source = fullfile(lmz.util.ProjectPaths.catalog(), ...
                'slip_quadruped');
            copyfile(source, fullfile(parent, 'first'));
            copyfile(source, fullfile(parent, 'second'));
            testCase.verifyError(@() ...
                lmz.registry.ModelRegistry.discover(parent), ...
                'lmz:Registry:DuplicateModelId');
            clear cleanup
        end
    end
end

function removeTree(path)
if exist(path, 'dir') == 7
    rmdir(path, 's');
end
end
