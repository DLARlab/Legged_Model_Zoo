classdef TestContinuationLivePersistentOverlay < matlab.unittest.TestCase
    methods (Test)
        function workspaceOwnsNoCompetingContinuationAxes(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            continuation=layout.ComponentMap.continuation;
            hooks=continuation.testHooks();

            testCase.verifyEmpty(hooks.Controls.Axes);
            testCase.verifyEmpty(findall(hooks.Root,'Type','axes'));
            testCase.verifyEqual(layout.OverlayController.Axes, ...
                app.BranchAxes);
            clear cleanup
        end

        function previewUpdatesPredictorAndAcceptedLayers(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            pair=app.Controller.makeAdjacentSeedPair(1,struct());drawnow;
            prediction=struct('PointIndex',3,'StepSize',pair.AchievedRadius, ...
                'DecisionValues',pair.Second.DecisionValues, ...
                'Prediction',pair.Second.DecisionValues);
            app.Controller.setContinuationPreview(struct( ...
                'Phase','prediction','State',prediction));drawnow;
            accepted=prediction;accepted.Solution=pair.Second;
            accepted.ResidualNorm=0;
            app.Controller.setContinuationPreview(struct( ...
                'Phase','accepted','State',accepted));drawnow;
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyTrue(any(strcmp( ...
                layout.OverlayController.layerNames(), ...
                'accepted_continuation')));
            testCase.verifyEqual(layout.OverlayController.Axes,app.BranchAxes);
            status=layout.StatusPanel.testHooks();
            testCase.verifySubstring(status.CurrentStage, ...
                'Continuation accepted');
            testCase.verifyNotEmpty(status.ProgressDetails);
            clear cleanup
        end

        function diagnosticsUseActiveProviderCoordinate(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            pair=app.Controller.makeAdjacentSeedPair(1,struct());
            app.Controller.setAxisVariables('y','dx','dphi');drawnow;
            names=pair.Second.DecisionSchema.names();
            prediction=pair.Second.DecisionValues;
            corrected=prediction;
            prediction(1)=11.125;prediction(2)=22.25;
            corrected(1)=33.375;corrected(2)=44.5;
            coordinates=struct('Names',{names}, ...
                'Active',pair.Second.DecisionValues, ...
                'Predicted',prediction,'Corrected',corrected);
            state=struct('PointIndex',3,'StepSize',pair.AchievedRadius, ...
                'ResidualNorm',1e-6,'Reason','acceptance-policy', ...
                'DecisionValues',prediction,'Prediction',prediction, ...
                'CorrectedDecision',corrected,'Direction',1, ...
                'CoordinateDiagnostics',coordinates);

            app.Controller.setContinuationPreview(struct( ...
                'Phase','rejected','State',state));drawnow;
            controls=app.tab('continuation').testHooks().Controls;
            testCase.verifyEqual(controls.LiveDiagnosticsTable.ColumnName{3}, ...
                'Prediction (y)');
            testCase.verifyEqual(controls.LiveDiagnosticsTable.ColumnName{4}, ...
                'Corrected (y)');
            testCase.verifyEqual(controls.LiveDiagnosticsTable.Data{1,3}, ...
                sprintf('%.6g',prediction(2)));
            testCase.verifyEqual(controls.LiveDiagnosticsTable.Data{1,4}, ...
                sprintf('%.6g',corrected(2)));
            testCase.verifyNotEqual( ...
                controls.LiveDiagnosticsTable.Data{1,3}, ...
                sprintf('%.6g',prediction(1)));
            clear cleanup
        end
    end
end
