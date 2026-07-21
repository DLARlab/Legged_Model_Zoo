classdef TestSectionPreferenceRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function selectedSectionPersistsAcrossAppReconstruction(testCase)
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            controller.selectProblem('periodic_orbit');
            first=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');drawnow;
            firstTab=first.tab('solve');
            firstTab.StopSectionDropDown.Value='height_descending';
            firstTab.MinimumReturnTimeField.Value=0.031;
            callback=firstTab.StopSectionDropDown.ValueChangedFcn;
            callback(firstTab.StopSectionDropDown,[]);drawnow;
            stored=preferences.sectionPreference( ...
                'tutorial_hopper','periodic_orbit',struct());
            testCase.verifyEqual(stored.StopSectionId,'height_descending');
            testCase.verifyEqual(stored.MinimumReturnTime,0.031);
            delete(first);

            secondController=lmz.gui.AppController();
            secondController.selectModel('tutorial_hopper');
            secondController.selectProblem('periodic_orbit');
            second=lmz.gui.LeggedModelZooApp('Controller',secondController, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                second,preferences));drawnow;
            secondTab=second.tab('solve');
            testCase.verifyEqual(secondTab.StopSectionDropDown.Value, ...
                'height_descending');
            testCase.verifyEqual(secondTab.MinimumReturnTimeField.Value,0.031);
            testCase.verifyEqual(secondController.State. ...
                ProblemConfiguration.StopSectionId,'height_descending');
            testCase.verifyEqual(secondController.Events.LastDispatchErrors,{});
            clear cleanup
        end
    end
end
