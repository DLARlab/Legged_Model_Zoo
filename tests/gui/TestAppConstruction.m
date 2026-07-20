classdef TestAppConstruction < matlab.unittest.TestCase
    methods (Test)
        function headlessConstruction(testCase)
            app = lmz.gui.LeggedModelZooApp('CreateFigure', false);
            cleanup = onCleanup(@()delete(app));
            testCase.verifyEqual(app.Controller.modelIds(), ...
                {'slip_biped','slip_quad_load','slip_quadruped', ...
                'tutorial_hopper'});
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

        function tutorialHopperSelectionCapabilityAndDemo(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            preferences=testPreferences();
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()clean(app,preferences));drawnow;

            testCase.verifyEqual(app.ModelDropDown.Value,'tutorial_hopper');
            testCase.verifyEqual(app.ProblemDropDown.Value,'periodic_hop');
            testCase.verifyTrue(any(strcmp(app.ProblemDropDown.ItemsData, ...
                'demo_hop')));
            testCase.verifySubstring(app.CapabilityLabel.Text,'Tutorial');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Tested');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Solve');

            app.ProblemDropDown.Value='demo_hop';
            callback=app.ProblemDropDown.ValueChangedFcn;
            callback(app.ProblemDropDown,[]);drawnow;
            testCase.verifyEqual(controller.State.ProblemId,'demo_hop');
            testCase.verifyEqual(controller.State.WorkingSolution.ProblemId, ...
                'demo_hop');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Tutorial');
            testCase.verifySubstring(app.CapabilityLabel.Text,'Tested');
            testCase.verifyFalse(contains(app.CapabilityLabel.Text,'Solve'));
            testCase.verifyEqual(char(app.SimulateButton.Enable),'on');
            testCase.verifyEqual(char(app.SolveButton.Enable),'off');
            testCase.verifyEqual(char(app.ContinuationButton.Enable),'off');

            callback=app.SimulateButton.ButtonPushedFcn;
            callback(app.SimulateButton,[]);drawnow;
            testCase.verifyClass(controller.State.Simulation, ...
                'lmz.api.SimulationResult');
            testCase.verifyEqual(controller.bodyTrajectoryNames(),{'x','y'});
            testCase.verifyEqual(controller.Events.LastDispatchErrors,{});

            delete(app);
            testCase.verifyEqual(controller.Events.subscriptionCount(),0);
            clear cleanup
        end
    end
end

function preferences=testPreferences()
namespace=sprintf('LMZTutorialGui%d%d',round(now*1e7),randi(1e6));
preferences=lmz.gui.PreferencesStore('Namespace',namespace);
end

function clean(app,preferences)
if ~isempty(app)&&isvalid(app),delete(app);end
preferences.reset();
end
