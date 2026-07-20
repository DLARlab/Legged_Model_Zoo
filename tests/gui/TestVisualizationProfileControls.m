classdef TestVisualizationProfileControls < matlab.unittest.TestCase
    methods (Test)
        function scientificDefaultsSwitchLiveAndRestorePreference(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            controller.simulateWorkingSolution();
            preferences=testPreferences();
            preferenceCleanup=onCleanup(@()preferences.reset());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            appCleanup=onCleanup(@()deleteIfValid(app));drawnow;
            tab=app.tab('simulation');controls=tab.testHooks().Controls;

            testCase.verifyTrue(isfield(controls,'ForceCheckBox'));
            verifyProfile(testCase,tab,controls,'research_legacy',false, ...
                'Hatched',{'Hatched','Hidden'},true,20, ...
                'lmzmodels.slip_quad_load.ResearchRenderer');
            testCase.verifyFalse(tab.AnimationRenderer.ShowForces);
            testCase.verifyEqual(tab.AnimationRenderer.Options.GroundStyle, ...
                'hatched');

            controls.ForceCheckBox.Value=true;
            tab.refresh();drawnow;
            testCase.verifyFalse(controls.ForceCheckBox.Value);
            testCase.verifyFalse(tab.AnimationRenderer.ShowForces);

            researchRenderer=tab.AnimationRenderer;
            chooseProfile(controls.VisualProfileDropDown,'clean_generic');
            testCase.verifyFalse(isvalid(researchRenderer));
            verifyProfile(testCase,tab,controls,'clean_generic',true, ...
                'Line',{'Line','Hidden'},false,25, ...
                'lmzmodels.slip_quad_load.QuadLoadRenderer');
            testCase.verifyTrue(tab.AnimationRenderer.ShowForces);
            testCase.verifyEqual(tab.AnimationRenderer.Options.GroundStyle, ...
                'line');

            cleanRenderer=tab.AnimationRenderer;
            chooseProfile(controls.VisualProfileDropDown,'high_contrast');
            testCase.verifyFalse(isvalid(cleanRenderer));
            verifyProfile(testCase,tab,controls,'high_contrast',false, ...
                'Hatched',{'Hatched','Hidden'},true,20, ...
                'lmzmodels.slip_quad_load.ResearchRenderer');
            testCase.verifyEqual(preferences.visualizationProfile( ...
                'slip_quad_load','multi_stride_fit',''), 'high_contrast');

            delete(app);app=[];clear appCleanup
            restoredApp=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            restoredCleanup=onCleanup(@()deleteIfValid(restoredApp));drawnow;
            restoredTab=restoredApp.tab('simulation');
            restoredControls=restoredTab.testHooks().Controls;
            verifyProfile(testCase,restoredTab,restoredControls, ...
                'high_contrast',false,'Hatched',{'Hatched','Hidden'}, ...
                true,20,'lmzmodels.slip_quad_load.ResearchRenderer');
            clear restoredCleanup preferenceCleanup
        end

        function genericHighContrastAdvertisesLineGround(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            preferences=testPreferences();
            preferenceCleanup=onCleanup(@()preferences.reset());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            appCleanup=onCleanup(@()deleteIfValid(app));drawnow;
            tab=app.tab('simulation');controls=tab.testHooks().Controls;

            chooseProfile(controls.VisualProfileDropDown,'high_contrast');
            testCase.verifyEqual(tab.CurrentProfile.RendererClass, ...
                'lmz.viz.SceneRenderer2D');
            testCase.verifyEqual(controls.GroundStyleDropDown.Value,'Line');
            testCase.verifyEqual(controls.GroundStyleDropDown.Items, ...
                {'Line','Hidden'});
            testCase.verifyFalse(controls.ForceCheckBox.Value);
            clear appCleanup preferenceCleanup
        end
    end
end

function verifyProfile(testCase,tab,controls,id,forces,ground,groundItems, ...
        cameraFollow,fps,rendererClass)
testCase.verifyEqual(controls.VisualProfileDropDown.Value,id);
testCase.verifyEqual(tab.CurrentProfile.Id,id);
testCase.verifyEqual(logical(controls.ForceCheckBox.Value),forces);
testCase.verifyFalse(logical(controls.DetailedOverlayCheckBox.Value));
testCase.verifyEqual(controls.GroundStyleDropDown.Value,ground);
testCase.verifyEqual(controls.GroundStyleDropDown.Items,groundItems);
testCase.verifyEqual(logical(controls.CameraFollowCheckBox.Value),cameraFollow);
testCase.verifyEqual(controls.FPSSpinner.Value,fps);
testCase.verifyClass(tab.AnimationRenderer,rendererClass);
testCase.verifyEqual(tab.AnimationRenderer.Profile.Id,id);
testCase.verifyEqual(tab.AnimationRenderer.ShowForces,forces);
testCase.verifyEqual(tab.AnimationRenderer.CameraFollow,cameraFollow);
testCase.verifyFalse(tab.AnimationRenderer.DetailedOverlay);
testCase.verifyTrue(tab.AnimationRenderer.GroundVisible);
testCase.verifyEqual(tab.AnimationRenderer.Options.Palette,id);
end

function chooseProfile(control,value)
control.Value=value;callback=control.ValueChangedFcn;callback(control,[]);drawnow;
end

function preferences=testPreferences()
namespace=sprintf('LMZVisualizationProfile%d%d',round(now*1e7),randi(1e6));
preferences=lmz.gui.PreferencesStore('Namespace',namespace);
end

function deleteIfValid(value)
if ~isempty(value)&&isvalid(value),delete(value);end
end
