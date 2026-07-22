classdef TestLayoutPreferenceRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function workbenchSelectionsPersistWithVersionedSchema(testCase)
            namespace=sprintf('LMZLayoutPreferences%d%d', ...
                randi(2^30),randi(2^30));
            preferences=lmz.gui.PreferencesStore('Namespace',namespace);
            cleanup=onCleanup(@()preferences.reset());

            preferences.setLayoutProfile('scientific_workbench');
            preferences.setSidebarTab('Solve / Seeds');
            preferences.setCentralViewTab('Run Overlay');
            preferences.setSidebarWidthRatio(0.4);

            restored=lmz.gui.PreferencesStore('Namespace',namespace);
            testCase.verifyEqual(restored.layoutProfile(), ...
                'scientific_workbench');
            testCase.verifyEqual(restored.sidebarTab(),'Solve / Seeds');
            testCase.verifyEqual(restored.centralViewTab(),'Run Overlay');
            testCase.verifyEqual(restored.sidebarWidthRatio(),0.4, ...
                'AbsTol',eps);
            snapshot=restored.snapshot();
            testCase.verifyEqual(snapshot.SchemaVersion,4);
            testCase.verifyEqual(snapshot.LayoutProfile, ...
                'scientific_workbench');
            testCase.verifyEqual(snapshot.SidebarTab,'Solve / Seeds');
            testCase.verifyEqual(snapshot.CentralViewTab,'Run Overlay');
            testCase.verifyEqual(snapshot.SidebarWidthRatio,0.4, ...
                'AbsTol',eps);
            testCase.verifyEqual(getpref(namespace,'SchemaVersion'),4);
            clear cleanup
        end

        function invalidStoredValuesUseSafeFallbacks(testCase)
            namespace=sprintf('LMZInvalidLayoutPreferences%d%d', ...
                randi(2^30),randi(2^30));
            preferences=lmz.gui.PreferencesStore('Namespace',namespace);
            cleanup=onCleanup(@()preferences.reset());
            setpref(namespace,'LayoutProfile','Not a layout');
            setpref(namespace,'SidebarTab',42);
            setpref(namespace,'CentralViewTab','');
            setpref(namespace,'SidebarWidthRatio',1.5);

            testCase.verifyEqual(preferences.layoutProfile(), ...
                'classic_tabs');
            testCase.verifyEqual(preferences.sidebarTab(),'info_selection');
            testCase.verifyEqual(preferences.centralViewTab(),'branch_state');
            testCase.verifyEqual(preferences.sidebarWidthRatio(), ...
                1.85/(3.35+1.85),'AbsTol',eps);
            testCase.verifyError(@()preferences.setLayoutProfile('Bad ID'), ...
                'lmz:GUI:LayoutProfilePreference');
            testCase.verifyError(@()preferences.setSidebarWidthRatio(1), ...
                'lmz:GUI:SidebarWidthRatioPreference');
            clear cleanup
        end

        function minimumWindowContractIsExact(testCase)
            testCase.verifyEqual(lmz.gui.Accessibility.MinimumWindowSize, ...
                [900 650]);
        end

        function chosenClassicLayoutSurvivesModelAndWorkflowChanges(testCase)
            [app,preferences,cleanup]=Round11GUITestSupport.makeApp();
            app.LayoutDropDown.Value='classic_tabs';
            callback=app.LayoutDropDown.ValueChangedFcn;
            callback(app.LayoutDropDown,[]);
            drawnow;
            testCase.verifyEqual(preferences.layoutProfile(),'classic_tabs');
            app.Controller.selectModel('slip_biped');drawnow;
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ClassicTabbedLayout');
            app.Controller.selectModel('slip_quadruped');
            app.Controller.selectWorkflow('roadmap_root_continuation');drawnow;
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ClassicTabbedLayout');
            testCase.verifyEqual(app.Controller.layoutProfileId(),'classic_tabs');
            testCase.verifyEqual(preferences.layoutProfile(),'classic_tabs');
            clear cleanup
        end

        function chosenScientificLayoutSurvivesClassicContribution(testCase)
            [app,preferences,cleanup]=Round11GUITestSupport.makeApp( ...
                'scientific_workbench');
            app.Controller.selectModel('tutorial_hopper');drawnow;

            contribution=app.Controller.workbenchContribution();
            testCase.verifyEqual(contribution.LayoutProfileId,'classic_tabs');
            testCase.verifyClass(app.WorkbenchShell.Layout, ...
                'lmz.gui.layout.ScientificWorkbenchLayout');
            testCase.verifyEqual(app.LayoutDropDown.Value, ...
                'scientific_workbench');
            testCase.verifyEqual(app.Controller.layoutProfileId(), ...
                'scientific_workbench');
            testCase.verifyEqual(preferences.layoutProfile(), ...
                'scientific_workbench');
            clear cleanup
        end

        function absentChoiceUsesRegisteredWorkflowDefault(testCase)
            namespace=Round11GUITestSupport.namespace();
            preferences=lmz.gui.PreferencesStore('Namespace',namespace);
            preferences.setWindowPosition([40 40 1120 740]);
            testCase.verifyFalse(ispref(namespace,'LayoutProfile'));
            app=lmz.gui.LeggedModelZooApp('Preferences',preferences, ...
                'Visible','off');
            cleanup=onCleanup(@()Round11GUITestSupport.clean( ...
                app,preferences));
            drawnow;

            expected=app.Controller.State.WorkflowSession. ...
                Descriptor.LayoutProfileId;
            testCase.verifyEqual(app.WorkbenchShell.Profile.Id,expected);
            testCase.verifyEqual(app.LayoutDropDown.Value,expected);
            testCase.verifyEqual(app.Controller.layoutProfileId(),expected);
            testCase.verifyFalse(ispref(namespace,'LayoutProfile'));

            app.Controller.selectModel('tutorial_hopper');drawnow;
            expected=app.Controller.State.WorkbenchContribution.LayoutProfileId;
            testCase.verifyEqual(app.WorkbenchShell.Profile.Id,expected);
            testCase.verifyEqual(app.Controller.layoutProfileId(),expected);
            testCase.verifyFalse(ispref(namespace,'LayoutProfile'));

            app.Controller.selectModel('slip_quadruped');
            app.Controller.selectWorkflow('roadmap_root_continuation');drawnow;
            expected=app.Controller.State.WorkflowSession. ...
                Descriptor.LayoutProfileId;
            testCase.verifyEqual(app.WorkbenchShell.Profile.Id,expected);
            testCase.verifyEqual(app.Controller.layoutProfileId(),expected);
            testCase.verifyFalse(ispref(namespace,'LayoutProfile'));
            clear cleanup
        end

        function resetReturnsToRegisteredDefaultWithoutRecursion(testCase)
            [app,preferences,cleanup]=Round11GUITestSupport.makeApp( ...
                'classic_tabs');
            expected=app.Controller.State.WorkflowSession. ...
                Descriptor.LayoutProfileId;
            testCase.assertNotEqual(expected,'classic_tabs');
            before=app.Controller.Events.transactionCount();

            app.resetPreferences();drawnow;

            testCase.verifyEqual(app.Controller.Events.transactionCount()-before,1);
            testCase.verifyEmpty(app.Controller.Events.LastDispatchErrors);
            testCase.verifyEqual(app.WorkbenchShell.Profile.Id,expected);
            testCase.verifyEqual(app.LayoutDropDown.Value,expected);
            testCase.verifyEqual(app.Controller.layoutProfileId(),expected);
            testCase.verifyFalse(ispref(preferences.Namespace,'LayoutProfile'));
            clear cleanup
        end
    end
end
