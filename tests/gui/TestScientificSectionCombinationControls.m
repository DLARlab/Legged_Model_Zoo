classdef TestScientificSectionCombinationControls < matlab.unittest.TestCase
    methods (Test)
        function combinationsExposeMaturitySidesAndReasons(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            rows=controller.sectionCombinationData();
            testCase.verifyTrue(any(strcmp({rows.Classification},'validated')));
            testCase.verifyTrue(any(strcmp({rows.Classification},'unsupported')));
            testCase.verifyTrue(all(~cellfun(@isempty,{rows.Reason})));
            testCase.verifyTrue(all(ismember({rows.StartStateSide}, ...
                {'pre','post'})));
            controller.setSolveMode('Multiple shooting');
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));drawnow;
            label=app.tab('solve').testHooks().Controls.SectionSupportLabel;
            testCase.verifySubstring(label.Text,'validated');
            testCase.verifySubstring(label.Text,'catalog tested');
            clear cleanup
        end

        function loadAndDeclarativeDetailsAreClassified(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            controller.setSolveMode('Contact timings only');
            rows=controller.sectionCombinationData();
            match=strcmp({rows.StartSectionId},'apex')& ...
                strcmp({rows.StopSectionId},'stride_boundary');
            testCase.verifyEqual(sum(match),1);
            testCase.verifyEqual(rows(match).Classification,'validated');
            testCase.verifySubstring(rows(match).Reason, ...
                'timing only');

            controller.setSolveMode('Multiple shooting');
            rows=controller.sectionCombinationData();
            match=strcmp({rows.StartSectionId},'apex')& ...
                strcmp({rows.StopSectionId},'stride_boundary');
            testCase.verifyEqual(rows(match).Classification,'unsupported');
            testCase.verifySubstring(rows(match).Reason, ...
                'unsupported by multiple_shooting_horizon');

            controller.selectModel('slip_quadruped');
            controller.selectProblem('multiple_shooting');
            rows=controller.sectionCombinationData();
            testCase.verifyTrue(any(~cellfun(@isempty, ...
                {rows.StatePlaneSummary})));
            testCase.verifyTrue(any(~cellfun(@isempty, ...
                {rows.CompositeSummary})));
            plane=rows(find(~cellfun(@isempty, ...
                {rows.StatePlaneSummary}),1));
            testCase.verifySubstring(plane.Reason,'direction');
            composite=rows(strcmp({rows.StopSectionId}, ...
                'back_left_touchdown_descending'));
            testCase.verifyTrue(all(contains( ...
                {composite.CompositeSummary},'state dy')));
            testCase.verifyTrue(all(contains( ...
                {composite.CompositeSummary},'comparator lt')));
            testCase.verifyTrue(all(contains( ...
                {composite.CompositeSummary},'threshold 0')));
            testCase.verifyTrue(all(contains( ...
                {composite.CompositeSummary},'side selected')));
            mixed=strcmp({rows.StartSectionId}, ...
                'back_left_touchdown')&strcmp({rows.StopSectionId}, ...
                'descending_y_0_9');
            testCase.verifyEqual(rows(mixed).Classification,'unsupported');
            testCase.verifySubstring(rows(mixed).Reason, ...
                'same-section periodic closure');
            testCase.verifyError(@()controller.configureSections(struct( ...
                'StartSectionId','back_left_touchdown', ...
                'StopSectionId','descending_y_0_9')), ...
                'lmz:GUI:PeriodicShootingSections');
            controller.selectProblem('section_transition');
            rows=controller.sectionCombinationData();
            mixed=strcmp({rows.StartSectionId}, ...
                'back_left_touchdown')&strcmp({rows.StopSectionId}, ...
                'descending_y_0_9');
            testCase.verifyEqual(rows(mixed).Classification,'validated');
            testCase.verifySubstring(rows(mixed).Reason, ...
                'explicit terminal target');
            same=strcmp({rows.StartSectionId}, ...
                'back_left_touchdown')&strcmp({rows.StopSectionId}, ...
                'back_left_touchdown');
            testCase.verifyEqual(rows(same).Classification,'unsupported');
            testCase.verifySubstring(rows(same).Reason,'distinct endpoints');
            testCase.verifyError(@()controller.configureSections(struct( ...
                'StartSectionId','back_left_touchdown', ...
                'StopSectionId','back_left_touchdown')), ...
                'lmz:GUI:TransitionSections');

            controller.selectModel('slip_biped');
            controller.selectProblem('section_transition');
            rows=controller.sectionCombinationData();
            candidate=strcmp({rows.StartSectionId},'left_touchdown')& ...
                strcmp({rows.StopSectionId},'right_touchdown');
            testCase.verifyEqual(rows(candidate).Classification,'validated');
            testCase.verifySubstring(rows(candidate).Reason, ...
                'accepted-crossing candidate');
            testCase.verifySubstring(rows(candidate).Reason,'no root');
        end

        function problemSelectorListsTransition(testCase)
            [app,preferences,cleanup]= ...
                Round9GUITestSupport.makeApp('slip_quadruped'); %#ok<ASGLU>
            testCase.verifyTrue(any(strcmp( ...
                app.ProblemDropDown.ItemsData,'section_transition')));
            clear cleanup
        end

        function quadrupedControllerConfiguresTransition(testCase)
            verifyTransitionController(testCase,'slip_quadruped', ...
                'back_left_touchdown','descending_y_0_9',1e-9);
        end

        function bipedControllerConfiguresTransition(testCase)
            verifyTransitionController(testCase,'slip_biped', ...
                'left_touchdown','descending_y_0_95',1e-10);
        end
    end
end

function verifyTransitionController(testCase,modelId,startId,stopId,tolerance)
controller=lmz.gui.AppController();
controller.selectModel(modelId);
controller.selectProblem('section_transition');
configuration=controller.State.ProblemConfiguration;
testCase.verifyEqual(controller.State.ProblemId,'section_transition');
testCase.verifyEqual(controller.State.SolveMode,'Multiple shooting');
testCase.verifyEqual(configuration.StartSectionId,startId);
testCase.verifyEqual(configuration.StopSectionId,stopId);
testCase.verifyEqual(configuration.ShootingFormulation,'multiple_shooting');
testCase.verifyEqual(configuration.Formulation,'transition');
testCase.verifyEqual(configuration.HorizonLength,1);
testCase.verifyFalse(configuration.EventFreeMask);
controller.setShootingSettings(struct('Solver','lsqnonlin'));
testCase.verifyEqual(controller.State.ProblemConfiguration.Formulation, ...
    'transition');
evaluation=controller.evaluateWorkingSolution(false);
testCase.verifyLessThan(evaluation.ScaledResidualNorm,tolerance);
testCase.verifyTrue(evaluation.PhysicalValidity);
testCase.verifyTrue(evaluation.Feasibility.ResidualValid);
testCase.verifyError(@()controller.setShootingSettings( ...
    struct('Formulation','periodic')), ...
    'lmz:GUI:TransitionFormulation');
end
