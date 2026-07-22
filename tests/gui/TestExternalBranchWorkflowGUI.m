classdef TestExternalBranchWorkflowGUI < matlab.unittest.TestCase
    methods (Test)
        function externalWorkflowUsesGenericWorkbench(testCase)
            pluginRoot=copyPlugin();
            testCase.addTeardown(@()removeTree(pluginRoot));
            registry=lmz.registry.ModelRegistry.discoverWithPlugins( ...
                pluginRoot,'IncludeBuiltIns',false);
            controller=lmz.gui.AppController( ...
                registry,lmz.api.RunContext.synchronous(1412));
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round11GUITestSupport.namespace());
            preferences.setLayoutProfile('scientific_workbench');
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()clean(app,preferences,registry));drawnow;
            ids=controller.workflowIds();
            testCase.verifyNumElements(ids,1);
            id=ids{1};
            testCase.verifyTrue(any(strcmp(app.WorkflowDropDown.ItemsData,id)));
            app.WorkflowDropDown.Value=id;
            callback=app.WorkflowDropDown.ValueChangedFcn;
            callback(app.WorkflowDropDown,[]);drawnow;
            descriptor=controller.Workflows.get( ...
                controller.State.ModelId,id);
            testCase.verifyEqual(controller.State.WorkflowId,id);
            testCase.verifyEqual(controller.State.ModelId,descriptor.ModelId);
            testCase.verifyEqual(controller.State.ProblemId,descriptor.ProblemId);
            testCase.verifyEqual(controller.State.LockedSelection.PointIndex, ...
                descriptor.DefaultPointIndex);
            testCase.verifyTrue(isgraphics(app.BranchAxes));

            solved=controller.solveWorkingSolution(struct());
            testCase.verifyGreaterThan(solved.ExitFlag,0);
            testCase.verifyLessThan( ...
                solved.Evaluation.ScaledResidualNorm,1e-9);
            pair=controller.makeAdjacentSeedPair(+1,struct());
            testCase.verifyGreaterThan(pair.AchievedRadius,0);
            continued=controller.runContinuationDirection('forward',struct( ...
                'MaximumPoints',3,'InitialStep',pair.AchievedRadius, ...
                'MaximumStep',pair.AchievedRadius));
            testCase.verifyEqual(continued.Branch.pointCount(),3);
            testCase.verifyEqual(continued.Branch.ModelId,descriptor.ModelId);
            testCase.verifyEqual(continued.Branch.ProblemId,descriptor.ProblemId);

            simulation=controller.simulateWorkingSolution();
            testCase.verifyClass(simulation,'lmz.api.SimulationResult');
            figureHandle=figure('Visible','off');
            figureCleanup=onCleanup(@()deleteFigure(figureHandle));
            factory=lmz.viz.RendererFactory(registry, ...
                lmz.viz.VisualizationProfileRegistry(registry));
            [renderer,profile]=factory.createRenderer( ...
                axes('Parent',figureHandle),simulation, ...
                descriptor.ModelId,descriptor.ProblemId, ...
                descriptor.VisualizationProfileId,struct());
            rendererCleanup=onCleanup(@()deleteRenderer(renderer));
            testCase.verifyClass(renderer,'lmz.viz.SceneRenderer2D');
            testCase.verifyEqual(profile.Id,descriptor.VisualizationProfileId);
            testCase.verifyGreaterThan(numel(renderer.Handles),3);
            renderer.updateFrame(numel(simulation.Time));
            testCase.verifyEqual(renderer.CurrentIndex,numel(simulation.Time));
            clear rendererCleanup figureCleanup
            clear cleanup
        end
    end
end

function target=copyPlugin()
source=fullfile(lmz.util.ProjectPaths.tests(),'fixtures', ...
    'external_plugins','analytic_hopper');
target=[tempname '_external_gui'];copyfile(source,target);
end
function clean(app,preferences,registry)
if ~isempty(app)&&isvalid(app),delete(app);end
preferences.reset();delete(registry);
end
function removeTree(path)
if exist(path,'dir')==7,rmdir(path,'s');end
end
function deleteRenderer(renderer)
if ~isempty(renderer)&&isvalid(renderer),delete(renderer);end
end
function deleteFigure(figureHandle)
if isgraphics(figureHandle),delete(figureHandle);end
end
