classdef TestWorkflowRegistryExternalPlugin < matlab.unittest.TestCase
    methods (Test)
        function externalWorkflowRunsWithoutCoreModelCase(testCase)
            pluginRoot=copyPlugin('workflow');
            testCase.addTeardown(@()removeTree(pluginRoot));
            registry=lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot,'IncludeBuiltIns',false);
            registryCleanup=onCleanup(@()delete(registry));
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            testCase.verifyEqual(workflows.list('analytic_hopper'), ...
                {'analytic_root_continuation'});
            descriptor=workflows.get( ...
                'analytic_hopper','analytic_root_continuation');
            testCase.verifyEqual(descriptor.AxisPreset.X,'horizontal_speed');
            testCase.verifyEqual(descriptor.AxisPreset.Y,'stride_length');
            testCase.verifyClass(descriptor.createDataSourceProvider(), ...
                ['lmzplugins.analytic_hopper.' ...
                'AnalyticBranchDataSourceProvider']);

            session=lmz.workflow.WorkflowRunner().initialize( ...
                descriptor,lmz.api.RunContext.synchronous(1410));
            testCase.verifyEqual(session.Dataset.Branch.pointCount(),3);
            testCase.verifyEqual(session.SeedIndex,2);
            testCase.verifyLessThan( ...
                session.InitialEvaluation.ScaledResidualNorm,1e-10);
            solved=session.solve(struct());
            testCase.verifyGreaterThan(solved.ExitFlag,0);
            pair=session.makeAdjacentSeedPair(+1,struct());
            testCase.verifyEqual(pair.Diagnostics.SourceIndices,[2 3]);
            result=session.continueBranch(struct( ...
                'MaximumPoints',4,'DirectionMode','both', ...
                'InitialStep',pair.AchievedRadius, ...
                'MaximumStep',pair.AchievedRadius));
            testCase.verifyEqual(result.Branch.pointCount(),4);
            testCase.verifyEqual(result.Branch.ModelId,'analytic_hopper');
            clear session descriptor workflows registryCleanup
        end

        function providerClassMustRemainInsidePluginPackage(testCase)
            pluginRoot=copyPlugin('provider_trust');
            testCase.addTeardown(@()removeTree(pluginRoot));
            path=fullfile(pluginRoot,'catalog','analytic_hopper', ...
                'data_sources.lmz.json');
            value=lmz.compat.Json.read(path);
            value.dataSources.providerClass='lmz.workflow.DataSourceProvider';
            writeText(path,lmz.compat.Json.encode(value));
            registry=lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot,'IncludeBuiltIns',false);
            registryCleanup=onCleanup(@()delete(registry));
            testCase.verifyError(@() ...
                lmz.workflow.WorkflowRegistry.fromModelRegistry(registry), ...
                'lmz:Registry:ProviderNamespace');
            clear registryCleanup
        end

        function catalogHashIsFrozenAtModelDiscovery(testCase)
            pluginRoot=copyPlugin('workflow_hash');
            testCase.addTeardown(@()removeTree(pluginRoot));
            registry=lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot,'IncludeBuiltIns',false);
            registryCleanup=onCleanup(@()delete(registry));
            path=fullfile(pluginRoot,'catalog','analytic_hopper', ...
                'workbench.lmz.json');
            value=lmz.compat.Json.read(path);value.label='Changed after trust';
            writeText(path,lmz.compat.Json.encode(value));
            testCase.verifyError(@() ...
                lmz.workflow.WorkflowRegistry.fromModelRegistry(registry), ...
                'lmz:Workflow:WorkbenchChanged');
            clear registryCleanup
        end

        function optionalCatalogsHaveCleanGenericFallback(testCase)
            pluginRoot=copyPlugin('workflow_fallback');
            testCase.addTeardown(@()removeTree(pluginRoot));
            path=fullfile(pluginRoot,'catalog','analytic_hopper', ...
                'manifest.json');
            value=lmz.compat.Json.read(path);
            value=rmfield(value,{'dataSources','workbench','workflows'});
            writeText(path,lmz.compat.Json.encode(value));
            registry=lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot,'IncludeBuiltIns',false);
            registryCleanup=onCleanup(@()delete(registry));
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            testCase.verifyEmpty( ...
                workflows.listDataSources('analytic_hopper'));
            testCase.verifyEmpty(workflows.list('analytic_hopper'));
            contribution=workflows.getWorkbench('analytic_hopper');
            testCase.verifyEqual(contribution.Id,'generic');
            testCase.verifyEqual(contribution.LayoutProfileId,'classic_tabs');
            controller=lmz.gui.AppController( ...
                registry,lmz.api.RunContext.synchronous(1411));
            testCase.verifyEqual(controller.State.ModelId,'analytic_hopper');
            testCase.verifyClass( ...
                controller.State.WorkingSolution,'lmz.data.Solution');
            clear controller workflows contribution registryCleanup
        end
    end
end

function target=copyPlugin(suffix)
source=fullfile(lmz.util.ProjectPaths.tests(),'fixtures', ...
    'external_plugins','analytic_hopper');
target=[tempname '_' suffix];copyfile(source,target);
end
function writeText(path,value)
file=fopen(path,'w');cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s',value);clear cleanup
end
function removeTree(path)
if exist(path,'dir')==7,rmdir(path,'s');end
end
