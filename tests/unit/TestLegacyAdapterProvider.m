classdef TestLegacyAdapterProvider < matlab.unittest.TestCase
    methods (Test)
        function registeredResults29AdapterRoundTripsExactly(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            registryCleanup=onCleanup(@()delete(registry));
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            descriptor=workflows.getDataSource('slip_quadruped','roadmap');
            provider=descriptor.createProvider();
            adapter=provider.legacyAdapter(descriptor,registry);
            testCase.verifyClass(adapter, ...
                'lmzmodels.slip_quadruped.Results29LegacyDataAdapterProvider');
            source=fullfile(lmz.util.ProjectPaths.examples(),'data', ...
                'slip_quadruped','RoadMap','PK_20_2.mat');
            testCase.verifyTrue(adapter.canLoad(source));
            raw=load(source,'results');raw=raw.results(:,1:3);
            problem=registry.createModel('slip_quadruped'). ...
                createProblem('periodic_apex',struct());
            branch=adapter.importBranch(source,problem).subset(1:3);
            output=[tempname '.mat'];
            fileCleanup=onCleanup(@()deleteIfPresent(output));
            adapter.exportBranch(output,branch);
            exported=load(output,'results');
            testCase.verifyEqual(exported.results,raw,'AbsTol',0);
            reloaded=lmz.services.BranchService().reloadLegacySource( ...
                problem,output);
            testCase.verifyEqual(reloaded.DecisionValues, ...
                branch.DecisionValues,'AbsTol',0);
            testCase.verifyEqual(reloaded.ParameterValues, ...
                branch.ParameterValues,'AbsTol',0);
            clear fileCleanup registryCleanup
        end

        function everyScientificSourceExposesItsModelAdapter(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
            expected={ ...
                'slip_biped','gaitmap', ...
                'lmzmodels.slip_biped.Results14LegacyDataAdapterProvider'; ...
                'slip_quad_load','scientific_load', ...
                'lmzmodels.slip_quad_load.XAccumLegacyDataAdapterProvider'; ...
                'slip_quadruped','roadmap', ...
                'lmzmodels.slip_quadruped.Results29LegacyDataAdapterProvider'};
            for row=1:size(expected,1)
                descriptor=workflows.getDataSource( ...
                    expected{row,1},expected{row,2});
                provider=descriptor.createProvider();
                adapter=provider.legacyAdapter(descriptor,registry);
                testCase.verifyClass(adapter,expected{row,3});
            end
            clear cleanup
        end
    end
end

function deleteIfPresent(path)
if exist(path,'file')==2,delete(path);end
end
