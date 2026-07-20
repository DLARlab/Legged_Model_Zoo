classdef TestGUIUsability < matlab.unittest.TestCase
    methods (Test)
        function busyStateTakesPrecedenceAndLeavesCancelAvailable(testCase)
            [app,cleanup]=makeApp();
            app.Controller.selectModel('slip_biped');
            app.Controller.selectProblem('trajectory_fit');
            optimization=app.tab('optimization');
            optimization.setCapabilities(app.Controller.capabilities());
            optimization.setBusy(true,struct('Busy',true,'Kind','optimization'));
            testCase.verifyEqual(char(optimization.RunButton.Enable),'off');
            testCase.verifyEqual(char(optimization.CancelButton.Enable),'on');
            optimization.setBusy(false,struct('Busy',false));
            testCase.verifyEqual(char(optimization.RunButton.Enable),'on');
            testCase.verifyEqual(char(optimization.CancelButton.Enable),'off');
            continuation=app.tab('continuation');
            continuation.setBusy(true,struct('Busy',true,'Kind','continuation'));
            testCase.verifyEqual(char(continuation.RunButton.Enable),'off');
            testCase.verifyEqual(char(continuation.StopButton.Enable),'on');
            continuation.setBusy(false,struct('Busy',false));
            testCase.verifyEqual(char(continuation.StopButton.Enable),'off');
            clear cleanup
        end

        function recordingBusyStateLocksProfilesAndEnablesOnlyExportCancel(testCase)
            [app,cleanup]=makeApp();simulation=app.tab('simulation');
            controls=simulation.testHooks().Controls;
            exportCancel=findobj(app.Figure, ...
                'Tag','lmz-simulation-cancel-export');
            testCase.verifyEqual(char(exportCancel.Enable),'off');

            context=lmz.api.RunContext.synchronous(17);
            app.Controller.State.RecordingState=struct('Active',true, ...
                'Format','gif','Path',[tempname '.gif'],'Context',context);
            drawnow;
            testCase.verifyTrue(simulation.IsBusy);
            testCase.verifyEqual(char(controls.VisualProfileDropDown.Enable),'off');
            testCase.verifyEqual(char(controls.FPSSpinner.Enable),'off');
            testCase.verifyEqual(char(exportCancel.Enable),'on');
            testCase.verifyEqual(char(app.ModelDropDown.Enable),'off');
            testCase.verifyEqual(char(app.OptimizationCancelButton.Enable),'off');
            testCase.verifyEqual(char(app.tab('continuation').StopButton.Enable),'off');
            cancelCallback=exportCancel.ButtonPushedFcn;
            cancelCallback(exportCancel,[]);
            testCase.verifyTrue(context.Cancellation.IsCancellationRequested);

            app.Controller.State.RecordingState=struct('Active',false);
            drawnow;
            testCase.verifyFalse(simulation.IsBusy);
            testCase.verifyEqual(char(controls.VisualProfileDropDown.Enable),'on');
            testCase.verifyEqual(char(exportCancel.Enable),'off');
            testCase.verifyEqual(char(app.ModelDropDown.Enable),'on');
            clear cleanup
        end

        function preferencesPersistResetAndExcludeRepository(testCase)
            preferences=testPreferences();cleanup=onCleanup(@()preferences.reset());
            folder=tempname;mkdir(folder);folderCleanup=onCleanup(@()rmdir(folder));
            preferences.setPalette('high-contrast');
            preferences.setWindowPosition([11 22 1200 760]);
            preferences.rememberDataFolder(folder);preferences.rememberOutputFolder(folder);
            restored=lmz.gui.PreferencesStore('Namespace',preferences.Namespace);
            testCase.verifyEqual(restored.palette(),'high-contrast');
            testCase.verifyEqual(restored.windowPosition([1 1 1 1]),[11 22 1200 760]);
            testCase.verifyEqual(restored.recentDataFolder(''),folder);
            restored.rememberDataFolder(lmz.util.ProjectPaths.root());
            testCase.verifyEqual(restored.recentDataFolder(''),folder);
            restored.reset();testCase.verifyEqual(restored.palette(),'default');
            clear folderCleanup cleanup
        end

        function accessibilityMetadataAndPaletteAreExplicit(testCase)
            [app,cleanup]=makeApp();
            minimum=lmz.gui.Accessibility.MinimumWindowSize;
            app.Figure.Position=[50 50 700 400];
            lmz.gui.Accessibility.enforceMinimumWindow(app.Figure);
            testCase.verifyGreaterThanOrEqual(app.Figure.Position(3:4),minimum);
            testCase.verifyNotEmpty(app.BranchDimensionDropDown.Tooltip);
            testCase.verifyNotEmpty(app.ContinuationParameterDropDown.Tooltip);
            testCase.verifyNotEmpty(app.AnimationFPSSpinner.Tooltip);
            testCase.verifyTrue(lmz.gui.Palette.distinguishableSelectionMarkers('default'));
            testCase.verifyTrue(lmz.gui.Palette.distinguishableSelectionMarkers('high-contrast'));
            app.PaletteDropDown.Value='high-contrast';
            callback=app.PaletteDropDown.ValueChangedFcn;callback(app.PaletteDropDown,[]);
            testCase.verifyEqual(app.Preferences.palette(),'high-contrast');
            clear cleanup
        end

        function statusIncludesTimestampAndCopyableDetails(testCase)
            [app,cleanup]=makeApp();
            app.Controller.State.Status='Usability status marker';drawnow;
            values=app.StatusArea.Value;
            testCase.verifyTrue(any(contains(values,'Usability status marker')));
            testCase.verifyTrue(any(~cellfun('isempty',regexp(values, ...
                '^\[\d{4}-\d{2}-\d{2} ','once'))));
            testCase.verifyEqual(char(app.StatusArea.Editable),'off');
            clear cleanup
        end
    end
end

function [app,cleanup]=makeApp()
preferences=testPreferences();app=lmz.gui.LeggedModelZooApp( ...
    'Preferences',preferences,'Visible','off');
cleanup=onCleanup(@()clean(app,preferences));
end
function preferences=testPreferences()
namespace=sprintf('LMZGuiUsability%d%d',round(now*1e7),randi(1e6));
preferences=lmz.gui.PreferencesStore('Namespace',namespace);
end
function clean(app,preferences)
if ~isempty(app)&&isvalid(app),delete(app);end
preferences.reset();
end
