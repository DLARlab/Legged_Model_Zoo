classdef TestSolveLiveBranchOverlay < matlab.unittest.TestCase
    methods (Test)
        function solveProgressUsesSharedCanvas(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            button=app.tab('solve').SolveButton;
            callback=button.ButtonPushedFcn;callback(button,[]);drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyClass(app.Controller.State.SolveProgress, ...
                'lmz.data.SolveProgress');
            testCase.verifyTrue(any(strcmp( ...
                layout.OverlayController.layerNames(),'solved_point')));
            testCase.verifyEqual(layout.OverlayController.Axes,app.BranchAxes);
            status=layout.StatusPanel.testHooks();
            testCase.verifySubstring(lower(status.CurrentStage),'solve');
            testCase.verifyNotEmpty(status.ProgressDetails);
            clear cleanup
        end

        function perturbedSolveStreamsIterationsAndClearsTransientMarker(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round11GUITestSupport.namespace());
            preferences.setLayoutProfile('scientific_workbench');
            preferences.setWindowPosition([40 40 1120 740]);
            controller=lmz.gui.AppController(registry, ...
                lmz.api.RunContext.synchronous(11142));
            controller.selectModel('tutorial_hopper');
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()clean(app,preferences,registry));

            seed=controller.State.WorkingSolution;
            decision=seed.DecisionValues;decision(5)=decision(5)+0.08;
            controller.State.WorkingSolution= ...
                seed.withDecisionValues(decision).withoutDerivedData();
            result=controller.solveWorkingSolution(struct( ...
                'AcceptExistingTolerance',0,'MaxIterations',100, ...
                'MaxFunctionEvaluations',500));
            drawnow;

            progress=controller.State.SolveProgress;
            rows=app.tab('solve').IterationTable.Data;
            layers=app.WorkbenchShell.Layout.OverlayController.layerNames();
            testCase.verifyGreaterThan(result.ExitFlag,0);
            testCase.verifyGreaterThan(progress.count(),3);
            testCase.verifyTrue(any(strcmp(progress.Events,'iteration')));
            testCase.verifyTrue(any(strcmp(rows(:,1),'iteration')));
            testCase.verifyTrue(any(strcmp(layers,'solved_point')));
            testCase.verifyFalse(any(strcmp( ...
                layers,'current_solver_iterate')));
            clear cleanup
        end
    end
end

function clean(app,preferences,registry)
if ~isempty(app)&&isvalid(app),delete(app);end
preferences.reset();
if ~isempty(registry)&&isvalid(registry),delete(registry);end
end
