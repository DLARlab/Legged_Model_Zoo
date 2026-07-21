classdef TestHorizonDiagnosticsPanel < matlab.unittest.TestCase
    methods (Test)
        function panelShowsRankDefectsContactsAndEnergy(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            controller.setSolveMode('Multiple shooting');
            controller.solveWorkingSolution(struct('Display','off'));
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));drawnow;
            data=app.tab('solve').testHooks().Controls. ...
                ShootingDiagnosticsTable.Data;
            names=data(:,1);
            testCase.verifyTrue(any(strcmp(names,'rank / nullity')));
            testCase.verifyTrue(any(strcmp(names,'contact norms')));
            testCase.verifyTrue(any(strcmp(names,'interface defects')));
            testCase.verifyTrue(any(strcmp(names,'energy/work residuals')));
            initializer=data{strcmp(names,'initializer history'),2};
            recovery=data{strcmp(names,'recovery history'),2};
            energyDelta=data{strcmp(names,'EnergyDelta by stride'),2};
            declaredWork=data{strcmp(names,'DeclaredWork by stride'),2};
            testCase.verifySubstring(initializer,'provided_seed');
            testCase.verifyEqual(recovery,'not recorded');
            testCase.verifyNotEqual(energyDelta,'not recorded');
            testCase.verifyNotEqual(declaredWork,'not recorded');
            axesHandle=app.tab('solve').testHooks().Controls.SeedAxes;
            testCase.verifyEqual(axesHandle.Title.String, ...
                'Horizon diagnostic profiles');
            testCase.verifyGreaterThanOrEqual(numel(axesHandle.Children),6);
            labels=arrayfun(@(item)item.DisplayName,axesHandle.Children, ...
                'UniformOutput',false);
            testCase.verifyTrue(any(contains(labels,'section defect')));
            testCase.verifyTrue(any(contains(labels,'timing')));
            testCase.verifyTrue(any(contains(labels,'control')));
            testCase.verifyTrue(any(contains(labels, ...
                'solver residual history')));
            testCase.verifyTrue(any(contains(labels,'EnergyDelta')));
            testCase.verifyTrue(any(contains(labels,'DeclaredWork')));
            testCase.verifyNotEmpty( ...
                controller.State.ShootingResult.SolveResult.Output. ...
                ResidualHistory);
            clear cleanup
        end
    end
end
