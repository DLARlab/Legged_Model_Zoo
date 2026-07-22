classdef TestNoiseOverlayReproducibility < matlab.unittest.TestCase
    methods (Test)
        function repeatedSeedProducesSameCandidate(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            solveTab=app.tab('solve');solveTab.NoiseMagnitudeField.Value=1e-4;
            solveTab.NoiseSeedSpinner.Value=1402;
            press(solveTab.NoiseButton);first=app.Controller.State.WorkingSolution;
            app.Controller.restoreWorkingSolution();drawnow;
            press(solveTab.NoiseButton);second=app.Controller.State.WorkingSolution;
            testCase.verifyEqual(second.DecisionValues,first.DecisionValues, ...
                'AbsTol',0);
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyTrue(any(strcmp( ...
                layout.OverlayController.layerNames(),'noise_candidate')));
            clear cleanup
        end
    end
end

function press(button)
callback=button.ButtonPushedFcn;callback(button,[]);drawnow;
end
