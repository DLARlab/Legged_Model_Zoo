classdef TestRegistryTrustBoundary < matlab.unittest.TestCase
    methods (Test)
        function rejectsTraversalFolderMismatchAndReservedNamespace(testCase)
            [root, cleanup] = copyPlugin();
            manifestPath = fullfile(root, 'catalog', 'analytic_hopper', 'manifest.json');
            manifest = lmz.compat.Json.read(manifestPath);
            manifest.problems = {'../escape'};
            writeText(manifestPath, lmz.compat.Json.encode(manifest));
            testCase.verifyError(@() ...
                lmz.registry.ModelRegistry.discoverWithPlugins( ...
                root, 'IncludeBuiltIns', false), 'lmz:Registry:InvalidId');
            clear cleanup

            [root, cleanup] = copyPlugin();
            manifestPath = fullfile(root, 'catalog', 'analytic_hopper', 'manifest.json');
            manifest = lmz.compat.Json.read(manifestPath);
            manifest.id = 'different_id';
            writeText(manifestPath, lmz.compat.Json.encode(manifest));
            testCase.verifyError(@() ...
                lmz.registry.ModelRegistry.discoverWithPlugins( ...
                root, 'IncludeBuiltIns', false), ...
                'lmz:Registry:CatalogIdMismatch');
            clear cleanup

            [root, cleanup] = copyPlugin();
            pluginPath = fullfile(root, 'plugin.json');
            plugin = lmz.compat.Json.read(pluginPath);
            plugin.namespace = 'lmzmodels.tutorial_hopper';
            writeText(pluginPath, lmz.compat.Json.encode(plugin));
            testCase.verifyError(@() ...
                lmz.registry.ModelRegistry.discoverWithPlugins( ...
                root, 'IncludeBuiltIns', false), ...
                'lmz:Registry:PluginNamespace');
            clear cleanup
        end

        function externalImplementationRequiresExplicitTrust(testCase)
            [root, cleanup] = copyPlugin();
            catalog = fullfile(root, 'catalog');
            testCase.verifyError(@() lmz.registry.ModelRegistry.discover(catalog), ...
                'lmz:Registry:UnsafeImplementation');
            registry = lmz.registry.ModelRegistry.discoverWithPlugins( ...
                root, 'IncludeBuiltIns', false);
            testCase.verifyEqual(registry.listModels(), {'analytic_hopper'});
            delete(registry);
            clear cleanup
        end

        function duplicateExternalAndBuiltInIdsAreRejected(testCase)
            [root, cleanup] = copyPlugin();
            sourceFolder = fullfile(root, 'catalog', 'analytic_hopper');
            targetFolder = fullfile(root, 'catalog', 'slip_biped');
            movefile(sourceFolder, targetFolder);
            manifestPath = fullfile(targetFolder, 'manifest.json');
            manifest = lmz.compat.Json.read(manifestPath);
            manifest.id = 'slip_biped';
            writeText(manifestPath, lmz.compat.Json.encode(manifest));
            testCase.verifyError(@() ...
                lmz.registry.ModelRegistry.discoverWithPlugins(root), ...
                'lmz:Registry:DuplicateModelId');
            clear cleanup
        end
    end
end

function [target, cleanup] = copyPlugin()
source = fullfile(lmz.util.ProjectPaths.tests(), 'fixtures', ...
    'external_plugins', 'analytic_hopper');
target = [tempname '_plugin_security']; copyfile(source, target);
cleanup = onCleanup(@() removeTree(target));
end
function writeText(path, value)
file = fopen(path, 'w'); cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', value); clear cleanup
end
function removeTree(path), if exist(path, 'dir') == 7, rmdir(path, 's'); end, end
