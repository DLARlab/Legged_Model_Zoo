classdef TestPoincareSectionControls < matlab.unittest.TestCase
    methods (Test)
        function sectionSelectionConfiguresProblemAndInvalidatesDerivedState(testCase)
            [app,~,cleanup]=Round9GUITestSupport.makeApp( ...
                'tutorial_hopper','periodic_orbit'); %#ok<ASGLU>
            controller=app.Controller;solveTab=app.tab('solve');
            testCase.verifyEqual(solveTab.StartSectionDropDown.Items, ...
                controller.sectionIds());
            testCase.verifyEqual(solveTab.StopSectionDropDown.Items, ...
                controller.sectionIds());
            testCase.verifyTrue(any(strcmp( ...
                solveTab.StopSectionDropDown.Items,'height_descending')));
            controller.evaluateWorkingSolution(false);
            testCase.verifyNotEmpty(controller.State.WorkingEvaluation);

            solveTab.StopSectionDropDown.Value='height_descending';
            solveTab.StopSideDropDown.Value='post';
            solveTab.CrossingDirectionDropDown.Value='-1';
            solveTab.MinimumReturnTimeField.Value=0.02;
            callback=solveTab.StopSectionDropDown.ValueChangedFcn;
            callback(solveTab.StopSectionDropDown,[]);drawnow;

            configuration=controller.State.ProblemConfiguration;
            testCase.verifyEqual(configuration.StartSectionId,'apex');
            testCase.verifyEqual(configuration.StopSectionId, ...
                'height_descending');
            testCase.verifyEqual(configuration.StopStateSide,'post');
            testCase.verifyEqual(configuration.CrossingDirection,-1);
            testCase.verifyEqual(configuration.MinimumReturnTime,0.02);
            testCase.verifyEmpty(controller.State.WorkingEvaluation);
            testCase.verifySubstring(solveTab.RequiredSequenceLabel.Text, ...
                'Required events:');
            descriptor=controller.sectionDescriptor('height_descending');
            testCase.verifyEqual(descriptor.kind,'state_plane');
            testCase.verifyEqual(controller.Events.LastDispatchErrors,{});
            clear cleanup
        end
    end
end
