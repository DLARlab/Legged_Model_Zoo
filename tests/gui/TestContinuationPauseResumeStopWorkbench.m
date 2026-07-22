classdef TestContinuationPauseResumeStopWorkbench < matlab.unittest.TestCase
    methods (Test)
        function controlsRouteToCooperativeRunContext(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            context=lmz.api.RunContext.synchronous(1403);
            app.Controller.State.CurrentRun=struct( ...
                'Kind','continuation','Context',context);drawnow;
            tab=app.tab('continuation');press(tab.PauseButton);
            testCase.verifyTrue(context.Pause.IsPaused);
            press(tab.ResumeButton);testCase.verifyFalse(context.Pause.IsPaused);
            press(tab.StopButton);
            testCase.verifyTrue(context.Cancellation.IsCancellationRequested);
            app.Controller.State.CurrentRun=[];
            clear cleanup
        end
    end
end

function press(button)
callback=button.ButtonPushedFcn;callback(button,[]);drawnow;
end
