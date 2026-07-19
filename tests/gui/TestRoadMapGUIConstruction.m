classdef TestRoadMapGUIConstruction < matlab.unittest.TestCase
    methods (Test)
        function standaloneRoadMapControls(testCase)
            app=lmz.gui.LeggedModelZooApp();cleanup=onCleanup(@()delete(app));drawnow;
            testCase.verifyEqual(app.Controller.State.ModelId,'slip_quadruped');testCase.verifyNotEmpty(app.BranchDatasetList);testCase.verifyNotEmpty(app.BranchXDropDown);testCase.verifyNotEmpty(app.EventTable);testCase.verifyNotEmpty(app.OscillatorAxes);testCase.verifyEqual(app.Controller.State.LockedSelection.PointIndex,267);clear cleanup
        end
    end
end
