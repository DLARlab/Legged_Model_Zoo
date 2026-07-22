classdef TestStatusPanelProgress < matlab.unittest.TestCase
    methods (Test)
        function progressCoexistsWithCopyableStatusHistory(testCase)
            figureHandle=uifigure('Visible','off','Position',[20 20 900 650]);
            cleanup=onCleanup(@()deleteIfValid(figureHandle));
            root=uigridlayout(figureHandle,[1 1]);
            panel=lmz.gui.components.StatusPanel(root);

            testCase.verifyEqual(panel.Area.Tag,'lmz-status-area');
            testCase.verifyEqual(panel.CopyButton.Tag,'lmz-copy-diagnostics');
            testCase.verifyEqual(char(panel.Area.Editable),'off');
            panel.append('Seed accepted','info','source index 267', ...
                '2026-07-21 10:11:12');
            exactDiagnostics=sprintf('iteration=7\nscaledResidual=1.2e-8');
            panel.setProgress('Correcting candidate',0.375,exactDiagnostics);
            drawnow;

            hooks=panel.testHooks();
            testCase.verifyEqual(hooks.CurrentStage,'Correcting candidate');
            testCase.verifyEqual(hooks.ProgressValue,0.375,'AbsTol',eps);
            testCase.verifyEqual(panel.ProgressGauge.Value,0.375, ...
                'AbsTol',eps);
            testCase.verifyTrue(contains(panel.StageLabel.Text, ...
                'Correcting candidate'));
            testCase.verifyTrue(any(contains(panel.Area.Value,'Seed accepted')));
            copied=panel.diagnosticText();
            testCase.verifyTrue(contains(copied,'Stage: Correcting candidate'));
            testCase.verifyTrue(contains(copied,'Progress: 37.5%'));
            testCase.verifyTrue(contains(copied,exactDiagnostics));
            testCase.verifyTrue(contains(copied,'source index 267'));

            panel.clearProgress();
            testCase.verifyEqual(panel.CurrentStage,'Ready');
            testCase.verifyTrue(isnan(panel.ProgressValue));
            testCase.verifyEqual(panel.ProgressGauge.Value,0,'AbsTol',eps);
            testCase.verifyTrue(any(contains(panel.Area.Value,'Seed accepted')));
            clear cleanup
        end

        function progressValidationIsExplicit(testCase)
            figureHandle=uifigure('Visible','off');
            cleanup=onCleanup(@()deleteIfValid(figureHandle));
            panel=lmz.gui.components.StatusPanel(figureHandle);
            testCase.verifyError(@()panel.setProgress('solve',1.01), ...
                'lmz:GUI:StatusProgress');
            testCase.verifyError(@()panel.setProgress(42,0.5), ...
                'lmz:GUI:StatusStage');
            panel.updateProgress('Solving',NaN,'function count=3');
            testCase.verifyEqual(panel.CurrentStage,'Solving');
            testCase.verifyTrue(isnan(panel.ProgressValue));
            clear cleanup
        end

        function clearingTransientRunsResetsDockButKeepsHistory(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp(); %#ok<ASGLU>
            panel=app.WorkbenchShell.StatusPanel;
            initialRecords=numel(panel.Records);
            decision=app.Controller.State.WorkingSolution.DecisionValues;
            progress=lmz.data.SolveProgress();
            progress.record('iteration',lmz.data.SolveIterationSnapshot( ...
                struct('Stage','iteration','Iteration',3, ...
                'FunctionCount',7,'DecisionValues',decision, ...
                'ScaledResidual',1e-5,'StepNorm',1e-3, ...
                'FirstOrderOptimality',2e-5,'Accepted',true, ...
                'Message','progress reset test')));
            app.Controller.State.SolveProgress=progress;drawnow;
            testCase.verifyEqual(panel.CurrentStage,'Iteration');
            app.Controller.State.SolveProgress=[];drawnow;
            testCase.verifyEqual(panel.CurrentStage,'Ready');
            testCase.verifyTrue(isnan(panel.ProgressValue));
            testCase.verifyEqual(numel(panel.Records),initialRecords);

            preview=struct('PointIndex',3,'StepSize',0.02, ...
                'ResidualNorm',1e-7,'Reason','accepted', ...
                'Solution',app.Controller.State.WorkingSolution, ...
                'DecisionValues',decision,'CorrectedDecision',decision, ...
                'Prediction',decision,'Direction',1);
            app.Controller.setContinuationPreview(struct( ...
                'Phase','accepted','State',preview));drawnow;
            testCase.verifyEqual(panel.CurrentStage, ...
                'Continuation accepted');
            recordsBeforeClear=numel(panel.Records);
            app.Controller.setContinuationPreview([]);drawnow;
            testCase.verifyEqual(panel.CurrentStage,'Ready');
            testCase.verifyEqual(numel(panel.Records),recordsBeforeClear);
            clear cleanup
        end
    end
end

function deleteIfValid(value)
if ~isempty(value)&&isvalid(value),delete(value);end
end
