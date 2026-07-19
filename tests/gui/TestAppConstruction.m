classdef TestAppConstruction < matlab.unittest.TestCase
    methods (Test)
        function headlessConstruction(testCase)
            app = lmz.gui.LeggedModelZooApp('CreateFigure', false);
            cleanup = onCleanup(@()delete(app));
            testCase.verifyEqual(app.Controller.modelIds(), ...
                {'slip_biped','slip_quad_load','slip_quadruped'});
            clear cleanup
        end

        function desktopConstruction(testCase)
            app = lmz.gui.LeggedModelZooApp();
            cleanup = onCleanup(@()delete(app));
            testCase.verifyNotEmpty(app.Figure);
            testCase.verifyTrue(isgraphics(app.OptimizationAxes));
            testCase.verifyTrue(isgraphics(app.OptimizationSensitivityAxes));
            testCase.verifyTrue(isgraphics(app.OptimizationR2Axes));
            clear cleanup
        end
    end
end
