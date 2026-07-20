classdef TestVisualizationProfiles < matlab.unittest.TestCase
    methods (Test)
        function scientificAndTutorialDefaultsAreExplicit(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            profiles=lmz.viz.VisualizationProfileRegistry(registry);
            scientific={'slip_quadruped','periodic_apex'; ...
                'slip_biped','periodic_apex'; ...
                'slip_quad_load','single_stride'};
            for index=1:size(scientific,1)
                profile=profiles.defaultProfile(scientific{index,1},scientific{index,2});
                testCase.verifyEqual(profile.Id,'research_legacy');
                testCase.verifyTrue(contains(profile.RendererClass,'.ResearchRenderer'));
            end
            tutorials={'slip_quadruped','demo_stride';'slip_biped','demo_stride'; ...
                'slip_quad_load','demo_stride';'tutorial_hopper','periodic_hop'};
            for index=1:size(tutorials,1)
                testCase.verifyEqual(profiles.defaultProfile( ...
                    tutorials{index,1},tutorials{index,2}).Id,'clean_generic');
            end
            clear cleanup
        end

        function everyScientificModelOffersThreeProfiles(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cleanup=onCleanup(@()delete(registry));
            profiles=lmz.viz.VisualizationProfileRegistry(registry);
            models={'slip_quadruped','slip_biped','slip_quad_load'};
            for index=1:numel(models)
                config=profiles.configForModel(models{index});
                ids=cellfun(@(item)item.Id,config.Profiles,'UniformOutput',false);
                testCase.verifyTrue(all(ismember( ...
                    {'research_legacy','clean_generic','high_contrast'},ids)));
            end
            clear cleanup
        end

        function externalPluginRetainsGenericFallback(testCase)
            root=fullfile(lmz.util.ProjectPaths.tests(),'fixtures', ...
                'external_plugins','analytic_hopper');
            registry=lmz.registry.ModelRegistry.discoverWithPlugins(root, ...
                'IncludeBuiltIns',false);cleanup=onCleanup(@()delete(registry));
            profiles=lmz.viz.VisualizationProfileRegistry(registry);
            profile=profiles.defaultProfile('analytic_hopper','periodic_hop');
            testCase.verifyEqual(profile.Id,'clean_generic');
            testCase.verifyEqual(profile.RendererClass,'lmz.viz.SceneRenderer2D');
            clear cleanup
        end

        function preferenceRoundTripIsPerModelAndProblem(testCase)
            namespace=['LMZProfile' num2str(round(now*1e8)) num2str(randi(1e6))];
            preferences=lmz.gui.PreferencesStore('Namespace',namespace);
            cleanup=onCleanup(@()preferences.reset());
            preferences.setVisualizationProfile( ...
                'slip_quadruped','periodic_apex','high_contrast');
            preferences.setVisualizationProfile( ...
                'slip_quadruped','demo_stride','clean_generic');
            restored=lmz.gui.PreferencesStore('Namespace',namespace);
            testCase.verifyEqual(restored.visualizationProfile( ...
                'slip_quadruped','periodic_apex','research_legacy'), ...
                'high_contrast');
            testCase.verifyEqual(restored.visualizationProfile( ...
                'slip_quadruped','demo_stride','research_legacy'), ...
                'clean_generic');
            testCase.verifyEqual(restored.visualizationProfile( ...
                'slip_biped','periodic_apex','research_legacy'), ...
                'research_legacy');
            clear cleanup
        end
    end
end
