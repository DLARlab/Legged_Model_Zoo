classdef TestWorkflowSelectionInitializesQuadrupedReference < matlab.unittest.TestCase
    methods (Test)
        function selectorLoadsRegisteredReference(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            id='roadmap_root_continuation';
            testCase.assertTrue(any(strcmp(app.WorkflowDropDown.ItemsData,id)));
            app.WorkflowDropDown.Value=id;
            callback=app.WorkflowDropDown.ValueChangedFcn;
            callback(app.WorkflowDropDown,[]);drawnow;
            testCase.verifyEqual(app.Controller.State.WorkflowId,id);
            testCase.verifyEqual(app.Controller.State.ModelId,'slip_quadruped');
            testCase.verifyEqual(app.Controller.State.ProblemId,'periodic_apex');
            testCase.verifyEqual( ...
                app.Controller.State.LockedSelection.PointIndex,267);
            testCase.verifyEqual(app.WorkbenchShell.Profile.Id, ...
                'scientific_workbench');
            clear cleanup
        end
    end
end
