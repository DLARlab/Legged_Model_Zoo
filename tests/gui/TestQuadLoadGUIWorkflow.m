classdef TestQuadLoadGUIWorkflow < matlab.unittest.TestCase
    methods (Test)
        function controllerLoadsEvaluatesSimulatesAndSwitchesScientificData(testCase)
            controller=lmz.gui.AppController();controller.selectModel('slip_quad_load');
            testCase.verifyEqual(controller.State.ModelId,'slip_quad_load');
            testCase.verifyEqual(controller.State.ProblemId,'multi_stride_fit');
            testCase.verifyEqual(numel(controller.State.Datasets),1);
            dataset=controller.activeDataset();
            testCase.verifyTrue(dataset.ReadOnly);
            testCase.verifyEqual(dataset.Metadata.Status,'built-in/read-only');
            testCase.verifyEqual(dataset.Metadata.PointCount,1);
            testCase.verifyEqual(numel(controller.workingSolution().DecisionValues),57);
            capabilities=controller.problemCapabilities();
            testCase.verifyTrue(capabilities.simulate);
            testCase.verifyTrue(capabilities.optimize);
            evaluation=controller.evaluateWorkingSolution(false);
            testCase.verifyTrue(isfield(evaluation.Diagnostics,'Objective'));
            simulation=controller.simulateWorkingSolution();
            testCase.verifyEqual(simulation.Observables.stride_count,2);
            testCase.verifyEqual(size(simulation.States,2),18);
            testCase.verifyEqual(size(simulation.GroundReactionForces,2),12);
            testCase.verifyEqual(numel(simulation.EventRecords),18);
            datasets=controller.loadAllScientificLoadDatasets();
            testCase.verifyEqual(numel(datasets),2);
            testCase.verifyEqual(sort(cellfun(@(item)item.Branch.DecisionSchema.count(), ...
                datasets)),[44 57]);
            testCase.verifyEqual(controller.State.ProblemId,'single_stride');
            singleSimulation=controller.simulateWorkingSolution();
            testCase.verifyEqual(singleSimulation.Observables.stride_count,1);
            descriptors=controller.Registry.createModel('slip_quad_load').getPlotDescriptors();
            testCase.verifyTrue(all(ismember({'animation','footfall','body_legs','load', ...
                'grf','tugline','sensitivity','r2'},{descriptors.id})));
        end
    end
end
