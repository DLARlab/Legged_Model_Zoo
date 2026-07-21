classdef TestShootingModeControls < matlab.unittest.TestCase
    methods (Test)
        function formulationMasksSolverAndHorizonAreExplicit(testCase)
            [app,controller,preferences,cleanup]=shootingApp(); %#ok<ASGLU>
            controls=app.tab('solve').testHooks().Controls;
            testCase.verifyTrue(any(strcmp( ...
                controls.FormulationDropDown.ItemsData,'multiple_shooting')));
            testCase.verifyTrue(any(strcmp( ...
                controls.SolverDropDown.ItemsData,'lsqnonlin')));
            testCase.verifyTrue(any(strcmp(controls.SolverDropDown.ItemsData, ...
                'fmincon_feasibility')));
            testCase.verifyEqual(controls.InterfaceMaskField.Value,'all');
            testCase.verifyEqual(controls.ControlMaskField.Value,'none');
            controls.HorizonLengthSpinner.Value=3;
            callback=controls.HorizonLengthSpinner.ValueChangedFcn;
            callback(controls.HorizonLengthSpinner,[]);drawnow;
            editor=controller.shootingEditorData();
            testCase.verifyEqual(editor.SegmentCount,3);
            testCase.verifyEqual( ...
                controller.State.ProblemConfiguration.HorizonLength,3);
            clear cleanup
        end

        function loadControlsReachNativeShootingConfiguration(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            controller.setSolveMode('Multiple shooting');
            defaults=controller.shootingEditorData();
            testCase.verifyEqual(defaults.Configuration.EnergyWorkMode, ...
                'energy_neutral');
            testCase.verifyEqual(defaults.NativeConfiguration.EnergyMode, ...
                'energy_neutral');
            controller.setShootingSettings(struct('HorizonLength',3, ...
                'InterfaceStateMask',false, ...
                'ControlFreeMask',true, ...
                'EventFreeMask',[false true], ...
                'EnergyWorkMode','energy_neutral', ...
                'TemplateInitializer','individual_1_tr_to_tl'));
            editor=controller.shootingEditorData();
            native=editor.NativeConfiguration;

            testCase.verifyEqual(editor.SegmentCount,3);
            testCase.verifyEqual(native.NumberOfStrides,3);
            testCase.verifyFalse(native.FreeNodeMask);
            testCase.verifyTrue(native.FreeControlMask);
            testCase.verifyEqual(native.EnergyMode,'energy_neutral');
            testCase.verifyEqual(native.TemplateId, ...
                'individual_1_tr_to_tl');
            testCase.verifyTrue(all( ...
                editor.EventFreeMask==false));
            testCase.verifyTrue(editor.ReturnTimeFree);
        end

        function shootingCapabilitiesDoNotPromiseMissingSimulation(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            loadDescriptor=registry.getProblemDescriptor( ...
                'slip_quad_load','multiple_shooting_horizon');
            tutorialDescriptor=registry.getProblemDescriptor( ...
                'tutorial_hopper','multiple_shooting');
            testCase.verifyFalse(loadDescriptor.capabilities.simulate);
            testCase.verifyFalse(loadDescriptor.capabilities.visualize);
            testCase.verifyFalse(loadDescriptor.capabilities.animate);
            testCase.verifyFalse(tutorialDescriptor.capabilities.simulate);
            testCase.verifyFalse(tutorialDescriptor.capabilities.visualize);
        end

        function loadNodeMasksFollowSelectedSectionCoordinates(testCase)
            apexController=lmz.gui.AppController();
            apexController.selectModel('slip_quad_load');
            apexController.setSolveMode('Multiple shooting');
            apexMask=false(1,14);apexMask(14)=true;
            apexController.setShootingSettings(struct('HorizonLength',2, ...
                'InterfaceStateMask',apexMask));
            apexNative=apexController.shootingEditorData(). ...
                NativeConfiguration;
            testCase.verifySize(apexNative.FreeNodeMask,[3 14]);

            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            controller.setSolveMode('Multiple shooting');
            controller.configureSections(struct( ...
                'StartSectionId','stride_boundary', ...
                'StopSectionId','stride_boundary'));
            mask=false(1,15);mask(15)=true;
            controller.setShootingSettings(struct('HorizonLength',2, ...
                'InterfaceStateMask',mask));
            native=controller.shootingEditorData().NativeConfiguration;
            testCase.verifySize(native.FreeNodeMask,[3 15]);
            testCase.verifyTrue(all(native.FreeNodeMask(:,15)));
            testCase.verifyFalse(any(any(native.FreeNodeMask(:,1:14))));

            flattened=reshape(repmat(mask,3,1).',[],1);
            controller.setShootingSettings(struct( ...
                'InterfaceStateMask',flattened));
            native=controller.shootingEditorData().NativeConfiguration;
            testCase.verifySize(native.FreeNodeMask,[3 15]);
            testCase.verifyTrue(all(native.FreeNodeMask(:,15)));
        end

        function sectionChangeRebuildsSeedAndClearsRunState(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quad_load');
            controller.setSolveMode('Multiple shooting');
            original=controller.State.WorkingSolution;
            originalCount=original.DecisionSchema.count();
            controller.State.ShootingResult=struct('Stale',true, ...
                'Checkpoints',{{struct('Stale',true)}});
            controller.State.SolveResult=struct('Stale',true);
            controller.State.SeedPair=struct('Stale',true);
            controller.State.ContinuationPreview=struct('Stale',true);
            controller.State.ContinuationResult=struct('Stale',true);

            controller.configureSections(struct( ...
                'StartSectionId','stride_boundary', ...
                'StopSectionId','stride_boundary'));
            replacement=controller.State.WorkingSolution;
            testCase.verifyNotEqual( ...
                replacement.DecisionSchema.count(),originalCount);
            testCase.verifyEqual(replacement.DecisionValues, ...
                replacement.DecisionSchema.defaults(),'AbsTol',0);
            testCase.verifyEqual(replacement.ParameterValues, ...
                replacement.ParameterSchema.defaults(),'AbsTol',0);
            testCase.verifyEqual(replacement.ProblemId, ...
                'multiple_shooting_horizon');
            testCase.verifyEmpty(controller.State.ShootingResult);
            testCase.verifyEmpty(controller.State.SolveResult);
            testCase.verifyEmpty(controller.State.SeedPair);
            testCase.verifyEmpty(controller.State.ContinuationPreview);
            testCase.verifyEmpty(controller.State.ContinuationResult);
            evaluation=controller.evaluateWorkingSolution(false);
            testCase.verifyEqual(numel(replacement.DecisionValues), ...
                controller.shootingEditorData().UnknownCount);
            testCase.verifyTrue(isfinite(evaluation.ScaledResidualNorm));
        end
    end
end

function [app,controller,preferences,cleanup]=shootingApp()
controller=lmz.gui.AppController();
controller.selectModel('tutorial_hopper');
controller.setSolveMode('Multiple shooting');
preferences=lmz.gui.PreferencesStore( ...
    'Namespace',Round9GUITestSupport.namespace());
app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
    'Preferences',preferences,'Visible','off');
cleanup=onCleanup(@()Round9GUITestSupport.clean(app,preferences));drawnow;
end
