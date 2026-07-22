classdef TestFamilyScanSidebarWorkflow < matlab.unittest.TestCase
    methods (Test)
        function familyScanIsNotPresentedAsTwoDimensional(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            tab=app.tab('continuation');
            testCase.verifyTrue(isgraphics(tab.FamilyPanel));
            testCase.verifyTrue(isgraphics(tab.FamilyScanButton));
            notes=findall(tab.FamilyPanel,'Type','uilabel');
            values=arrayfun(@(item)char(item.Text),notes,'UniformOutput',false);
            testCase.verifyTrue(any(contains(values,'not 2-D continuation')));
            clear cleanup
        end

        function buttonsKeepHomotopyAndFamilyResultsIsolated(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            selectReferenceWorkflow(testCase,app);
            tab=app.tab('continuation');session=app.Controller.State.WorkflowSession;
            tab.ParameterDropDown.Value='k_leg';
            tab.TargetsField.Value='10';
            tab.HomotopyStepPolicyDropDown.Value='explicit_targets';
            press(tab.HomotopyButton);
            homotopy=app.Controller.State.HomotopyResult;
            testCase.assertNotEmpty(homotopy);

            tab.FamilyParameterDropDown.Value='k_leg';
            tab.FamilyTargetsField.Value='10';
            tab.FamilyStepPolicyDropDown.Value='adaptive_branches';
            tab.FamilySecondSeedRadiusField.Value=0.005;
            tab.PointsSpinner.Value=3;
            tab.DirectionModeDropDown.Value='forward';
            tab.InitialStepField.Value=0.005;
            tab.MaximumStepField.Value=0.005;
            tab.FeasibilityCheckBox.Value=false;
            tab.FamilyResultNameField.Value='round 11 family / scan';

            press(tab.FamilyScanButton);

            report=app.Controller.State.FamilyScanResult;
            testCase.verifyEqual(report.ParameterName,'k_leg');
            testCase.verifyEqual(report.Targets,10,'AbsTol',0);
            testCase.verifyEqual(report.Completed,1);
            testCase.verifyEqual(report.Failed,0);
            testCase.verifyEqual(report.Status,{'completed'});
            testCase.verifyEqual(report.Branches{1}.pointCount(),3);
            testCase.verifyEqual(app.Controller.State.HomotopyResult.Branch.Id, ...
                homotopy.Branch.Id);
            testCase.verifyNotEqual(report.Branches{1}.Id,homotopy.Branch.Id);
            testCase.verifyEmpty(app.Controller.State.ContinuationResult);
            aggregate=session.result();
            testCase.verifyEqual(aggregate.HomotopyResult.Branch.Id, ...
                homotopy.Branch.Id);
            testCase.verifyEqual(aggregate.FamilyScanResult.Branches{1}.Id, ...
                report.Branches{1}.Id);
            snapshot=aggregate.toStruct();
            testCase.verifyNotEmpty(snapshot.HomotopyResult);
            testCase.verifyNotEmpty(snapshot.FamilyScanResult);

            datasetCount=numel(app.Controller.State.Datasets);
            press(tab.FamilyAddButton);

            testCase.verifyEqual(numel(app.Controller.State.Datasets), ...
                datasetCount+1);
            dataset=app.Controller.State.Datasets{end};
            testCase.verifyEqual(dataset.Name,'round_11_family_scan_01_10');
            testCase.verifyEqual(dataset.Id,app.Controller.State.ActiveDatasetId);
            testCase.verifyEqual(dataset.Branch.Id,report.Branches{1}.Id);
            testCase.verifyFalse(dataset.ReadOnly);
            retained=session.result();
            testCase.verifyEqual(retained.HomotopyResult.Branch.Id, ...
                homotopy.Branch.Id);
            testCase.verifyEqual(retained.FamilyScanResult.Branches{1}.Id, ...
                report.Branches{1}.Id);
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
