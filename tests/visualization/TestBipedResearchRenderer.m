classdef TestBipedResearchRenderer < matlab.unittest.TestCase
    methods (Test)
        function classicAxesLifecyclePreservesHandlesAndLayers(testCase)
            simulation=makeSimulation();figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));axesHandle=axes(figureHandle);
            renderer=lmzmodels.slip_biped.ResearchRenderer(axesHandle,simulation);
            rendererCleanup=onCleanup(@()delete(renderer));
            testCase.verifyTrue(renderer.IsInitialized);
            testCase.verifyEqual(numel(axesHandle.Children),12);
            expected=[renderer.Handles.COG;renderer.Handles.Right.Upper; ...
                renderer.Handles.Right.Spring2;renderer.Handles.Right.Lower; ...
                renderer.Handles.Right.Spring1;renderer.Handles.Body; ...
                renderer.Handles.GroundHatch;renderer.Handles.GroundMask; ...
                renderer.Handles.Left.Upper;renderer.Handles.Left.Spring2; ...
                renderer.Handles.Left.Lower;renderer.Handles.Left.Spring1];
            testCase.verifyEqual(axesHandle.Children,expected);
            before=expected;renderer.updateFrame(2);
            after=[renderer.Handles.COG;renderer.Handles.Right.Upper; ...
                renderer.Handles.Right.Spring2;renderer.Handles.Right.Lower; ...
                renderer.Handles.Right.Spring1;renderer.Handles.Body; ...
                renderer.Handles.GroundHatch;renderer.Handles.GroundMask; ...
                renderer.Handles.Left.Upper;renderer.Handles.Left.Spring2; ...
                renderer.Handles.Left.Lower;renderer.Handles.Left.Spring1];
            testCase.verifyEqual(after,before);
            testCase.verifyEqual(xlim(axesHandle),[0.6 3.6],'AbsTol',2e-14);
            testCase.verifyEqual(ylim(axesHandle),[-0.3 2],'AbsTol',eps);
            testCase.verifyEqual(char(axesHandle.Visible),'off');
            testCase.verifyEqual(char(axesHandle.Box),'on');
            testCase.verifyEqual(renderer.Handles.Left.Lower.FaceColor, ...
                [202 202 202]/256,'AbsTol',eps);
            testCase.verifyEqual(renderer.Handles.Right.Lower.FaceColor,[1 1 1], ...
                'AbsTol',eps);
            renderer.setOptions(struct('GroundVisible',false),false);
            testCase.verifyEqual(char(renderer.Handles.GroundMask.Visible),'off');
            testCase.verifyEqual(char(renderer.Handles.GroundHatch.Visible),'off');
            renderer.clear();testCase.verifyFalse(renderer.IsInitialized);
            testCase.verifyEmpty(fieldnames(renderer.Handles));
            testCase.verifyError(@()renderer.captureFrame(), ...
                'lmz:Renderer:Capture');
            clear rendererCleanup cleanup
        end

        function profileDefaultsAndCleanRendererContract(testCase)
            path=fullfile(lmz.util.ProjectPaths.root(),'catalog','slip_biped', ...
                'graphics.lmz.json');
            config=lmz.viz.GraphicsConfig.fromJson(path);
            testCase.verifyEqual(config.defaultForMaturity('validated'), ...
                'research_legacy');
            testCase.verifyEqual(config.defaultForMaturity('tutorial'),'clean_generic');
            research=config.getProfile('research_legacy');
            testCase.verifyEqual(research.RendererClass, ...
                'lmzmodels.slip_biped.ResearchRenderer');
            highContrast=config.getProfile('high_contrast');
            testCase.verifyEqual(highContrast.RendererClass, ...
                'lmzmodels.slip_biped.ResearchRenderer');
            simulation=makeSimulation();figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));axesHandle=axes(figureHandle);
            clean=config.getProfile('clean_generic');
            renderer=lmzmodels.slip_biped.BipedRenderer( ...
                axesHandle,simulation,clean,struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            testCase.verifyTrue(isa(renderer,'lmz.viz.Renderer'));
            testCase.verifyEqual(renderer.frameCount(),numel(simulation.Time));
            renderer.updateFrame(0.5);testCase.verifyEqual(renderer.CurrentIndex,2);
            testCase.verifyTrue(all(isgraphics(renderer.Handles.Legs)));
            renderer.setOptions(struct('GroundVisible',false),false);
            testCase.verifyEqual(char(renderer.Handles.Ground.Visible),'off');
            clear rendererCleanup cleanup
        end

        function hiddenUIAxesLifecycle(testCase)
            testCase.assumeTrue(exist('uifigure','file')==2, ...
                'UI figures are unavailable in this MATLAB release.');
            try
                figureHandle=uifigure('Visible','off');axesHandle=uiaxes(figureHandle);
            catch exception
                testCase.assumeTrue(false,['UIAxes unavailable: ' exception.message]);
            end
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            renderer=lmzmodels.slip_biped.ResearchRenderer(axesHandle,makeSimulation());
            rendererCleanup=onCleanup(@()delete(renderer));
            renderer.updateFrame(3);
            testCase.verifyEqual(renderer.CurrentIndex,3);
            testCase.verifyEqual(numel(axesHandle.Children),12);
            testCase.verifyTrue(all(isgraphics([renderer.Handles.Body; ...
                renderer.Handles.COG;renderer.Handles.GroundHatch])));
            clear rendererCleanup cleanup
        end

        function rendererFactorySelectsResearchDefault(testCase)
            simulation=makeSimulation();figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));axesHandle=axes(figureHandle);
            registry=lmz.registry.ModelRegistry.discover();
            factory=lmz.viz.RendererFactory(registry, ...
                lmz.viz.VisualizationProfileRegistry(registry));
            [renderer,profile]=factory.createRenderer(axesHandle,simulation, ...
                'slip_biped','periodic_apex','',struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            testCase.verifyClass(renderer,'lmzmodels.slip_biped.ResearchRenderer');
            testCase.verifyEqual(profile.Id,'research_legacy');
            testCase.verifyEqual(renderer.frameCount(),numel(simulation.Time));
            clear rendererCleanup
            [renderer,profile]=factory.createRenderer(axesHandle,simulation, ...
                'slip_biped','periodic_apex','high_contrast',struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            testCase.verifyClass(renderer,'lmzmodels.slip_biped.ResearchRenderer');
            testCase.verifyEqual(profile.Id,'high_contrast');
            testCase.verifyEqual(renderer.Handles.Left.Lower.FaceColor,[0 1 1], ...
                'AbsTol',eps);
            testCase.verifyEqual(numel(axesHandle.Children),12);
            clear rendererCleanup cleanup
        end
    end
end

function simulation=makeSimulation()
time=[0;0.3;1];states=[2 0 .9 0 .2 0 -.3 0; ...
    2.1 0 .92 0 .15 0 -.2 0;2.2 0 .95 0 .1 0 -.1 0];
modes=struct('left',[false;true;false],'right',[true;false;true], ...
    'period',1);names={'L_TD','L_LO','R_TD','R_LO','APEX'};
times=[0.2 0.6 0.7 0.1 1];records=repmat(struct('Name','','Time',0),5,1);
for index=1:5,records(index).Name=names{index};records(index).Time=times(index);end
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
    struct(),struct(),struct(),struct(),'EventRecords',records);
kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(simulation);
simulation=lmz.api.SimulationResult(simulation.Time,simulation.StateSchema, ...
    simulation.States,simulation.Modes,simulation.Observables, ...
    simulation.Parameters,simulation.Diagnostics,simulation.Provenance, ...
    'EventRecords',simulation.EventRecords,'Kinematics',kinematics);
end

function closeIfValid(handle)
if ~isempty(handle)&&isgraphics(handle),delete(handle);end
end
