classdef TestSolveProgressFocusedRefresh < matlab.unittest.TestCase
    methods (Test)
        function iterationEventsAvoidFullEditorRefresh(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            solveTab=app.tab('solve');
            initialRefreshCount=solveTab.RefreshCount;
            decision=app.Controller.State.WorkingSolution.DecisionValues;
            progress=lmz.data.SolveProgress();

            progress.record('iteration',snapshot(1,decision));
            app.Controller.State.SolveProgress=progress;
            drawnow;
            testCase.verifyEqual(solveTab.RefreshCount,initialRefreshCount);
            testCase.verifySize(solveTab.IterationTable.Data,[1 6]);

            progress.record('iteration',snapshot(2,decision));
            app.Controller.Events.publish( ...
                lmz.gui.PresentationEvents.SolveProgressChanged, ...
                struct('Event','iteration'));
            drawnow;
            testCase.verifyEqual(solveTab.RefreshCount,initialRefreshCount);
            testCase.verifySize(solveTab.IterationTable.Data,[2 6]);

            app.Controller.Events.publish( ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged,struct());
            drawnow;
            testCase.verifyGreaterThan(solveTab.RefreshCount, ...
                initialRefreshCount);
            clear cleanup
        end
    end
end

function value=snapshot(iteration,decision)
value=lmz.data.SolveIterationSnapshot(struct( ...
    'Stage','iteration','Iteration',iteration, ...
    'FunctionCount',2*iteration,'DecisionValues',decision, ...
    'ScaledResidual',10^(-iteration),'StepNorm',1/iteration, ...
    'FirstOrderOptimality',1/iteration,'Accepted',true, ...
    'Message','Focused GUI refresh test.'));
end
