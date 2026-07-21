classdef TestEnergyPolicyDiagnostics < matlab.unittest.TestCase
    methods (Test)
        function completedCarryForwardDisplaysAcceptedEnergyTransition(testCase)
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
            simulation.CompletionPolicyDropDown.Value='carry_forward';
            Round9GUITestSupport.change(simulation.StrideCountSpinner,3);
            Round9GUITestSupport.press(simulation.CompletePlanButton);

            result=controller.State.MultiStrideResult;
            testCase.verifyEqual(result.CompletionStatus,'complete');
            testCase.verifyEqual(result.CompletedStrideCount,3);
            testCase.verifyEqual(result.Plan.EnergyPolicy.Id, ...
                'energy_neutral_only');
            testCase.verifyEqual(numel(result.EnergyDiagnostics),1);
            testCase.verifyTrue(result.EnergyDiagnostics{1}.Accepted);
            testCase.verifyEqual(result.EnergyDiagnostics{1}.EnergyDelta,0);
            testCase.verifySubstring(simulation.EnergyDiagnosticLabel.Text, ...
                '1 transitions accepted');
            testCase.verifyFalse(result.Diagnostics.AllContactTimingsFeasible);
            clear cleanup pathCleanup
        end


        function pendingStiffnessRequiresAndAcceptsDeclaredWork(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            plan=Round9GUITestSupport.quadPlan();
            [path,pathCleanup]=Round9GUITestSupport.savePlan(plan); %#ok<ASGLU>
            controller.loadStridePlan(path);
            controller.setStrideSettings( ...
                3,'carry_forward','return_partial',true);
            before=plan.StrideSpecs(2);
            controls=before.ControlParameters;
            controls.PostSwingStiffness= ...
                controls.PostSwingStiffness(:)+1;
            after=before.withControlParameters(controls,struct( ...
                'PostSwingStiffness',controls.PostSwingStiffness));
            policy=lmzmodels.slip_quad_load.QuadLoadEnergyPolicy();
            [delta,~]=policy.parameterTransitionEnergy( ...
                plan.InitialState,before,after);
            overrides=struct('stride3',struct( ...
                'PostSwingStiffness',controls.PostSwingStiffness));
            controller.setStrideOverrides(overrides,[0;0;0]);
            testCase.verifyError(@()controller.validateStrideEnergy(), ...
                'lmz:MultiStride:EnergyTransition');

            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));drawnow;
            simulation=app.tab('simulation');
            simulation.StridePlanTable.Data{3,5}= ...
                mat2str(controls.PostSwingStiffness(:).',17);
            simulation.StridePlanTable.Data{3,8}=delta;
            Round9GUITestSupport.press(simulation.ValidateEnergyButton);

            report=controller.State.PlanValidation;
            testCase.verifyTrue(report.Valid);
            testCase.verifyTrue(report.Estimated);
            testCase.verifyEqual(numel(report.EnergyDiagnostics),1);
            testCase.verifyEqual( ...
                report.EnergyDiagnostics{1}.DeclaredWork,delta,'AbsTol',1e-12);
            testCase.verifySubstring( ...
                simulation.EnergyDiagnosticLabel.Text,'accepted');
            clear cleanup pathCleanup
        end
    end
end
