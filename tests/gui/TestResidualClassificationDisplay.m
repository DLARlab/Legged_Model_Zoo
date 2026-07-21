classdef TestResidualClassificationDisplay < matlab.unittest.TestCase
    methods (Test)
        function physicalRootHasDistinctClassification(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('tutorial_hopper');
            controller.setSolveMode('Multiple shooting');
            result=controller.solveWorkingSolution(struct('Display','off'));
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));drawnow;
            label=app.tab('solve').testHooks().Controls. ...
                ResidualClassificationLabel;
            testCase.verifyEqual(result.FeasibilityReport.Classification, ...
                'root_found');
            testCase.verifyEqual(label.Text,'Residual: root found');
            testCase.verifyEqual(label.FontColor,[0.05 0.45 0.16]);
            clear cleanup
        end
    end
end
