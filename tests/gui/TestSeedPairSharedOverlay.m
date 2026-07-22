classdef TestSeedPairSharedOverlay < matlab.unittest.TestCase
    methods (Test)
        function adjacentPairCreatesNamedLayers(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp(); %#ok<ASGLU>
            app.Controller.makeAdjacentSeedPair(1,struct());drawnow;
            overlay=Round11GUITestSupport.scientificLayout(app). ...
                OverlayController;
            names=overlay.layerNames();
            testCase.verifyTrue(all(ismember( ...
                {'first_seed','second_seed','continuation_predictor'},names)));
            testCase.verifyFalse(any(strcmp(names,'predicted_seed')));
            summary=app.SolveStatus.Text;
            testCase.verifySubstring(summary,'Adjacent branch seed pair');
            testCase.verifySubstring(summary,'max source residual');
            testCase.verifyFalse(contains(summary,'generated residual'));
            testCase.verifyFalse(contains(summary,'NaN'));
            clear cleanup
        end

        function generatedPairKeepsPredictionAndCorrectionDistinct(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp(); %#ok<ASGLU>
            pair=app.Controller.makeSecondSeed(0.005);drawnow;
            overlay=Round11GUITestSupport.scientificLayout(app). ...
                OverlayController;
            names=overlay.layerNames();
            testCase.verifyTrue(all(ismember( ...
                {'predicted_seed','first_seed','second_seed'},names)));
            correction=pair.Second.DecisionValues- ...
                pair.Diagnostics.Prediction;
            testCase.verifyGreaterThan(norm(correction),0);
            predicted=overlay.layerHandle('predicted_seed');
            corrected=overlay.layerHandle('second_seed');
            testCase.verifyNotEmpty(predicted);
            testCase.verifyNotEmpty(corrected);

            decisionNames=pair.Second.DecisionSchema.names();
            [~,order]=sort(abs(correction),'descend');
            testCase.assertGreaterThanOrEqual(numel(order),2);
            app.Controller.setAxisVariables(decisionNames{order(1)}, ...
                decisionNames{order(2)},'');drawnow;
            testCase.verifyEqual(overlay.layerHandle('predicted_seed'), ...
                predicted);
            testCase.verifyEqual(overlay.layerHandle('second_seed'),corrected);
            testCase.verifyEqual(predicted.XData, ...
                pair.Diagnostics.Prediction(order(1)),'AbsTol',0);
            testCase.verifyEqual(corrected.XData, ...
                pair.Second.DecisionValues(order(1)),'AbsTol',0);
            testCase.verifyNotEqual(predicted.XData,corrected.XData);

            app.Controller.makeAdjacentSeedPair(1,struct());drawnow;
            names=overlay.layerNames();
            testCase.verifyFalse(any(strcmp(names,'predicted_seed')));
            testCase.verifyTrue(all(ismember( ...
                {'first_seed','second_seed','continuation_predictor'},names)));
            testCase.verifyEqual(overlay.layerHandle('second_seed'),corrected);
            clear cleanup
        end
    end
end
