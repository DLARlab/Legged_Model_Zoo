classdef TestProblemSelectionConsistency < matlab.unittest.TestCase
    methods (Test)
        function dropdownsRebuildBipedWorkingProblemAndDispatchSimulation(testCase)
            app=lmz.gui.LeggedModelZooApp();
            cleanup=onCleanup(@()delete(app));drawnow;

            changeValue(app.ModelDropDown,'slip_biped');
            testCase.verifyEqual(app.Controller.State.ProblemId,'periodic_apex');
            testCase.verifyEqual(app.ProblemDropDown.Value,'periodic_apex');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'periodic_apex');
            testCase.verifyEqual(app.Controller.State.LockedSelection.PointIndex,30);
            datasetIds=cellfun(@(item)item.Id,app.Controller.State.Datasets, ...
                'UniformOutput',false);

            changeValue(app.ProblemDropDown,'trajectory_fit');
            testCase.verifyEqual(app.Controller.State.ProblemId,'trajectory_fit');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'trajectory_fit');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.DecisionSchema.count(),16);
            testCase.verifyEmpty(app.Controller.State.LockedSelection);
            testCase.verifySubstring(app.CapabilityLabel.Text,'Validated');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Source-equivalent');
            testCase.verifyEqual(char(app.SolveButton.Enable),'off');
            testCase.verifyEqual(char(app.ContinuationButton.Enable),'off');
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'on');
            testCase.verifyEqual(char(app.SendToSolveButton.Enable),'off');
            testCase.verifyEqual(char(app.SendToContinuationButton.Enable),'off');
            press(app,'Simulate candidate');
            testCase.verifySize(app.Controller.State.Simulation.States, ...
                [numel(app.Controller.State.Simulation.Time) 8]);
            testCase.verifySubstring(app.Controller.State.Status,'trajectory_fit');

            changeValue(app.ProblemDropDown,'demo_stride');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'demo_stride');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.DecisionSchema.count(),0);
            testCase.verifySubstring(app.CapabilityLabel.Text,'Tutorial');
            testCase.verifyEqual(char(app.SolveButton.Enable),'off');
            testCase.verifyEqual(char(app.ContinuationButton.Enable),'off');
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'off');
            press(app,'Simulate candidate');
            testCase.verifySize(app.Controller.State.Simulation.States, ...
                [241 8]);
            testCase.verifySubstring(app.Controller.State.Status,'demo_stride');

            changeValue(app.ProblemDropDown,'periodic_apex');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'periodic_apex');
            testCase.verifyEqual(app.Controller.State.LockedSelection.PointIndex,30);
            testCase.verifyEqual(char(app.SolveButton.Enable),'on');
            testCase.verifyEqual(char(app.ContinuationButton.Enable),'on');
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'off');
            testCase.verifyEqual(cellfun(@(item)item.Id, ...
                app.Controller.State.Datasets,'UniformOutput',false),datasetIds);
            clear cleanup
        end

        function loadProblemsControlActionsAndOptimizationPanes(testCase)
            app=lmz.gui.LeggedModelZooApp();
            cleanup=onCleanup(@()delete(app));drawnow;

            changeValue(app.ModelDropDown,'slip_quad_load');
            testCase.verifyEqual(app.Controller.State.ProblemId,'multi_stride_fit');
            testCase.verifyEqual(app.ProblemDropDown.Value,'multi_stride_fit');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'multi_stride_fit');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.DecisionSchema.count(),57);
            testCase.verifyEqual(char(app.SolveButton.Enable),'off');
            testCase.verifyEqual(char(app.ContinuationButton.Enable),'off');
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'on');
            testCase.verifyTrue(isgraphics(app.OptimizationAxes));
            testCase.verifyTrue(isgraphics(app.OptimizationSensitivityAxes));
            testCase.verifyTrue(isgraphics(app.OptimizationR2Axes));
            testCase.verifyEqual(app.OptimizationAxes.Title.String,'Objective history');
            testCase.verifyEqual(app.OptimizationSensitivityAxes.Title.String, ...
                'Sensitivity / terms');
            testCase.verifyEqual(app.OptimizationR2Axes.Title.String,'Fit quality');
            datasetIds=cellfun(@(item)item.Id,app.Controller.State.Datasets, ...
                'UniformOutput',false);

            changeValue(app.ProblemDropDown,'single_stride');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'single_stride');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.DecisionSchema.count(),44);
            testCase.verifyEmpty(app.Controller.State.LockedSelection);
            testCase.verifyEmpty(app.Controller.State.Selection);
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'off');
            press(app,'Simulate candidate');
            testCase.verifyEqual(app.Controller.State.Simulation.Observables.stride_count,1);
            testCase.verifySize(app.Controller.State.Simulation.States, ...
                [numel(app.Controller.State.Simulation.Time) 18]);

            changeValue(app.ProblemDropDown,'demo_stride');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'demo_stride');
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'off');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Tutorial');

            changeValue(app.ProblemDropDown,'multi_stride_fit');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.ProblemId, ...
                'multi_stride_fit');
            testCase.verifyEqual(app.Controller.State.WorkingSolution.DecisionSchema.count(),57);
            testCase.verifyEqual(char(app.OptimizationButton.Enable),'on');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Source-equivalent');
            testCase.verifyEqual(cellfun(@(item)item.Id, ...
                app.Controller.State.Datasets,'UniformOutput',false),datasetIds);
            press(app,'Run fit (supported models)');
            testCase.verifyNotEmpty(app.Controller.State.OptimizationResult);
            testCase.verifyGreaterThan(numel(app.OptimizationAxes.Children),0);
            testCase.verifyGreaterThan( ...
                numel(app.OptimizationSensitivityAxes.Children),0);
            testCase.verifyGreaterThan(numel(app.OptimizationR2Axes.Children),0);
            clear cleanup
        end
    end
end

function changeValue(control,value)
control.Value=value;
callback=control.ValueChangedFcn;
callback(control,[]);
drawnow;
end

function press(app,label)
buttons=findall(app.Figure,'Type','uibutton');
index=find(arrayfun(@(button)strcmp(button.Text,label),buttons),1);
if isempty(index)
    error('lmz:Test:MissingButton','Missing button %s.',label);
end
callback=buttons(index).ButtonPushedFcn;
callback(buttons(index),[]);
drawnow;
end
