classdef TestPluginRemovalCleansWorkflowRegistry < matlab.unittest.TestCase
    methods (Test)
        function deletingRegistryRemovesPluginPathAndRegistrations(testCase)
            pluginRoot=copyPlugin();
            testCase.addTeardown(@()removeTree(pluginRoot));
            codeRoot=fullfile(pluginRoot,'models');
            registry=lmz.registry.ModelRegistry.discoverWithPlugins(pluginRoot);
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            testCase.verifyTrue(pathContains(codeRoot));
            testCase.verifyTrue(any(strcmp( ...
                registry.listModels(),'analytic_hopper')));
            testCase.verifyEqual(workflows.list('analytic_hopper'), ...
                {'analytic_root_continuation'});
            provider=workflows.createDataSourceProvider( ...
                'analytic_hopper','analytic_branch');
            testCase.verifyClass(provider, ...
                ['lmzplugins.analytic_hopper.' ...
                'AnalyticBranchDataSourceProvider']);

            clear provider workflows
            delete(registry);clear registry
            testCase.verifyFalse(pathContains(codeRoot));
            builtIn=lmz.registry.ModelRegistry.discover();
            builtInCleanup=onCleanup(@()delete(builtIn));
            cleanWorkflows=lmz.workflow.WorkflowRegistry. ...
                fromModelRegistry(builtIn);
            testCase.verifyFalse(any(strcmp( ...
                builtIn.listModels(),'analytic_hopper')));
            testCase.verifyEmpty(cleanWorkflows.list('analytic_hopper'));
            clear cleanWorkflows builtInCleanup
        end
    end
end

function target=copyPlugin()
source=fullfile(lmz.util.ProjectPaths.tests(),'fixtures', ...
    'external_plugins','analytic_hopper');
target=[tempname '_workflow_removal'];copyfile(source,target);
end
function value=pathContains(target)
value=any(strcmp(regexp(path,pathsep,'split'), ...
    lmz.util.PathGuard.canonical(target,true)));
end
function removeTree(path)
if exist(path,'dir')==7,rmdir(path,'s');end
end
