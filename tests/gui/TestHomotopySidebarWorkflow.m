classdef TestHomotopySidebarWorkflow < matlab.unittest.TestCase
    methods (Test)
        function homotopyOwnsNestedTaskPanel(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            tab=app.tab('continuation');
            testCase.verifyTrue(isgraphics(tab.HomotopyPanel));
            testCase.verifyTrue(isgraphics(tab.HomotopyButton));
            testCase.verifyNotEmpty(tab.ParameterDropDown.Items);
            testCase.verifyNotEqual(tab.ParameterDropDown, ...
                tab.FamilyParameterDropDown);
            clear cleanup
        end

        function buttonRunsNamesAndAddsRetainedResult(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            selectReferenceWorkflow(testCase,app);
            tab=app.tab('continuation');session=app.Controller.State.WorkflowSession;
            tab.ParameterDropDown.Value='k_leg';
            tab.TargetsField.Value='10 10.001';
            tab.HomotopyStepPolicyDropDown.Value='explicit_targets';
            tab.HomotopyResultNameField.Value='round 11 / homotopy';
            datasetCount=numel(app.Controller.State.Datasets);

            press(tab.HomotopyButton);

            result=app.Controller.State.HomotopyResult;
            testCase.verifyTrue(isstruct(result));
            testCase.verifyEqual(result.ParameterName,'k_leg');
            testCase.verifyEqual(result.Targets,[10 10.001],'AbsTol',0);
            testCase.verifyEqual(result.Completed,2);
            testCase.verifyEmpty(app.Controller.State.FamilyScanResult);
            aggregate=session.result();
            testCase.verifyEqual(aggregate.HomotopyResult.Branch.Id, ...
                result.Branch.Id);
            testCase.verifyEmpty(aggregate.FamilyScanResult);
            snapshot=aggregate.toStruct();
            testCase.verifyTrue(isfield(snapshot,'HomotopyResult'));
            testCase.verifyNotEmpty(snapshot.HomotopyResult);
            testCase.verifyTrue(isfield(snapshot,'FamilyScanResult'));
            testCase.verifyEmpty(snapshot.FamilyScanResult);

            press(tab.HomotopyAddButton);

            testCase.verifyEqual(numel(app.Controller.State.Datasets), ...
                datasetCount+1);
            dataset=app.Controller.State.Datasets{end};
            testCase.verifyEqual(dataset.Name,'round_11_homotopy');
            testCase.verifyEqual(dataset.Id,app.Controller.State.ActiveDatasetId);
            testCase.verifyEqual(dataset.Branch.Id,result.Branch.Id);
            testCase.verifyFalse(dataset.ReadOnly);
            retained=session.result();
            testCase.verifyEqual(retained.HomotopyResult.Branch.Id, ...
                result.Branch.Id);
            testCase.verifyEmpty(retained.FamilyScanResult);
            clear cleanup
        end
    end
end

function selectReferenceWorkflow(testCase,app)
id='roadmap_root_continuation';
testCase.assertTrue(any(strcmp(app.WorkflowDropDown.ItemsData,id)));
if ~strcmp(app.Controller.State.WorkflowId,id)
    app.WorkflowDropDown.Value=id;
    callback=app.WorkflowDropDown.ValueChangedFcn;
    callback(app.WorkflowDropDown,[]);drawnow;
end
testCase.assertEqual(app.Controller.State.WorkflowId,id);
end

function press(button)
callback=button.ButtonPushedFcn;callback(button,[]);drawnow;
end
