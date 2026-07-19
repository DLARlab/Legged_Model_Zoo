classdef TestRoadMapSelectionSynchronization < matlab.unittest.TestCase
    methods (Test)
        function hoverLockAxesAndMultipleDatasets(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quadruped');locked=controller.State.LockedSelection;
            hover=controller.hoverNearestPoint(controller.State.ActiveDatasetId,{'dx','dphi'},[7 0]);
            testCase.verifyEqual(controller.State.LockedSelection.PointIndex,locked.PointIndex);testCase.verifyNotEqual(hover.PointIndex,0);
            controller.lockBranchPoint(controller.State.ActiveDatasetId,hover.PointIndex);testCase.verifyEqual(controller.State.Selection.PointIndex,hover.PointIndex);testCase.verifyEqual(controller.State.OscillatorIndex,hover.PointIndex);
            controller.setAxisVariables('dx','dphi','y');values=controller.axisValues();testCase.verifySize(values.X,[1 891]);testCase.verifySize(values.Z,[1 891]);
            controller.loadAllRoadMapBranches();testCase.verifyEqual(numel(controller.State.Datasets),9);
        end
    end
end
