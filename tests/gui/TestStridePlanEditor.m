classdef TestStridePlanEditor < matlab.unittest.TestCase
    methods (Test)
        function loadedPlanRendersCompletedPrefixAndCapturesEdits(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            [path,pathCleanup]=Round9GUITestSupport.savePlan( ...
                Round9GUITestSupport.quadPlan()); %#ok<ASGLU>
            controller.loadStridePlan(path);
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));drawnow;
            simulation=app.tab('simulation');
            testCase.verifyEqual(size(simulation.StridePlanTable.Data),[2 8]);
            testCase.verifyEqual(simulation.StridePlanTable.Data(:,3), ...
                {'supplied';'supplied'});
            testCase.verifySubstring( ...
                simulation.StridePlanTable.Data{1,4},'quadruped');
            testCase.verifyFalse( ...
                simulation.StridePlanTable.ColumnEditable(4));

            simulation.CompletionPolicyDropDown.Value='carry_forward';
            Round9GUITestSupport.change(simulation.StrideCountSpinner,3);
            testCase.verifyEqual(controller.State.StridePlan. ...
                CompletedStrideCount,2);
            testCase.verifyEqual(controller.State.StridePlan. ...
                RequestedStrideCount,3);
            testCase.verifyEqual(simulation.StridePlanTable.Data{3,3},'missing');
            simulation.StridePlanTable.Data{3,8}=2.5;
            Round9GUITestSupport.press(simulation.ApplyOverridesButton);
            testCase.verifyEqual(controller.State.DeclaredWork,[0;0;2.5]);
            testCase.verifyEqual(controller.State.CompletionPolicy, ...
                'carry_forward');
            clear cleanup pathCleanup
        end

        function nStrideFitRequiresTheCompleteSharedPlan(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            controller.selectProblem('n_stride_fit');
            testCase.verifyError(@()controller.runOptimization(struct()), ...
                'lmz:GUI:MissingStridePlan');
            [path,pathCleanup]=Round9GUITestSupport.savePlan( ...
                Round9GUITestSupport.quadPlan()); %#ok<ASGLU>
            controller.loadStridePlan(path);
            testCase.verifyEqual(controller.State.RequestedStrideCount,2);
            testCase.verifyTrue(controller.validateStridePlan(true).Complete);
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));drawnow;
            testCase.verifyEqual( ...
                app.tab('optimization').StrideCountSpinner.Value,2);
            testCase.verifyEqual( ...
                app.tab('optimization').PlanStatusLabel.Text, ...
                '2/2 strides complete');
            clear cleanup pathCleanup
        end
    end
end
