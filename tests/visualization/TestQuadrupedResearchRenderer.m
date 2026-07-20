classdef TestQuadrupedResearchRenderer < matlab.unittest.TestCase
    methods (Test)
        function classicAxesPreserveLayerOrderHandlesAndCamera(testCase)
            simulation = QuadrupedGraphicsTestSupport.simulation();
            profile = QuadrupedGraphicsTestSupport.profile('research_legacy');
            figureHandle = figure('Visible', 'off', 'Position', [10 10 640 480]);
            axesHandle = axes('Parent', figureHandle);
            sentinel = plot(axesHandle, 100, 100, 'Tag', 'user.sentinel');
            renderer = lmzmodels.slip_quadruped.ResearchRenderer( ...
                axesHandle, simulation, profile, struct());
            cleanup = onCleanup(@() clean(renderer, figureHandle));
            expected = expectedLayerOrder();
            testCase.verifyEqual(renderer.sourceLayerOrder(), expected);
            owned = findall(axesHandle, '-regexp', 'Tag', '^lmz\.quadruped\.');
            testCase.verifyEqual(numel(owned), 49);
            testCase.verifyTrue(renderer.DetailedOverlay);
            testCase.verifyFalse(renderer.ShowForces);
            testCase.verifyEqual(renderer.Handles.LegBL.Spring1.EdgeColor, ...
                [245 131 58]/256, 'AbsTol', 1e-15);
            testCase.verifyEqual(renderer.Handles.Body.Outline.LineWidth, 4);
            testCase.verifyEqual(char( ...
                renderer.Handles.COM.Outer.Visible), 'on');
            renderer.updateFrame(2);
            testCase.verifyEqual(xlim(axesHandle), [-0.3 2.7], 'AbsTol', 1e-14);
            testCase.verifyEqual(ylim(axesHandle), [-0.1 2], 'AbsTol', 0);
            for iteration = 1:100
                renderer.updateFrame(1+mod(iteration, 3));
            end
            testCase.verifyEqual(numel(findall(axesHandle, '-regexp', ...
                'Tag', '^lmz\.quadruped\.')), 49);
            testCase.verifyTrue(isgraphics(sentinel));
            imageData = renderer.captureFrame();
            testCase.verifyGreaterThan(size(imageData, 1), 10);
            testCase.verifyGreaterThan(size(imageData, 2), 10);
            delete(renderer);
            testCase.verifyTrue(isgraphics(sentinel));
            testCase.verifyEmpty(findall(axesHandle, '-regexp', ...
                'Tag', '^lmz\.quadruped\.'));
            clear cleanup
            if isgraphics(figureHandle), delete(figureHandle); end
        end

        function optionsToggleVisibilityWithoutRebuild(testCase)
            [renderer, figureHandle] = makeRenderer('research_legacy');
            cleanup = onCleanup(@() clean(renderer, figureHandle));
            owned = findall(renderer.Handles.Body.Outline.Parent, ...
                '-regexp', 'Tag', '^lmz\.quadruped\.');
            renderer.setOptions(struct('DetailedOverlay', false, ...
                'ShowForces', true, 'GroundVisible', true, ...
                'GroundStyle', 'plain'), false);
            renderer.updateFrame(2);
            testCase.verifyEqual(char( ...
                renderer.Handles.Phase.Box.Visible), 'off');
            testCase.verifyEqual(char(renderer.Handles.Title.Visible), 'off');
            testCase.verifyEqual(char( ...
                renderer.Handles.Ground.Field.Visible), 'on');
            testCase.verifyEqual(char( ...
                renderer.Handles.Ground.Hatch.Visible), 'off');
            testCase.verifyEqual(char( ...
                renderer.Handles.Forces(1).Visible), 'on');
            testCase.verifyEqual(renderer.Handles.Forces(1).UData, 0.025, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(renderer.Handles.Forces(1).VData, 0.25, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(numel(findall( ...
                renderer.Handles.Body.Outline.Parent, '-regexp', ...
                'Tag', '^lmz\.quadruped\.')), numel(owned));
            followBefore=renderer.CameraFollow;
            testCase.verifyError(@()renderer.setOptions( ...
                struct('CameraFollow',~followBefore, ...
                'GroundStyle','untrusted'),false), ...
                'lmz:Renderer:GroundStyle');
            testCase.verifyEqual(renderer.CameraFollow,followBefore);
            testCase.verifyError(@()renderer.setOptions( ...
                struct('Palette','bad palette'),false), ...
                'lmz:Renderer:Palette');
            testCase.verifyError(@()renderer.setOptions( ...
                struct('Palette',42),false), ...
                'lmz:Renderer:OptionType');
            clear cleanup
        end

        function symmetricMorphologySuppressesCOMWithoutDroppingHandles(testCase)
            figureHandle = figure('Visible', 'off');
            renderer = lmzmodels.slip_quadruped.ResearchRenderer( ...
                axes('Parent', figureHandle), ...
                QuadrupedGraphicsTestSupport.simulation(0.5), ...
                QuadrupedGraphicsTestSupport.profile('research_legacy'), ...
                struct());
            cleanup = onCleanup(@() clean(renderer, figureHandle));
            testCase.verifyEqual(char( ...
                renderer.Handles.COM.Outer.Visible), 'off');
            testCase.verifyEqual(char( ...
                renderer.Handles.COM.Inner.Visible), 'off');
            testCase.verifyEqual(numel(findall( ...
                renderer.Handles.Body.Outline.Parent, '-regexp', ...
                'Tag', '^lmz\.quadruped\.')), 49);
            clear cleanup
        end

        function profileSwitchRebuildsWithHighContrastStyle(testCase)
            [renderer, figureHandle] = makeRenderer('research_legacy');
            cleanup = onCleanup(@() clean(renderer, figureHandle));
            renderer.updateFrame(2);
            current = renderer.CurrentIndex;
            renderer.setProfile( ...
                QuadrupedGraphicsTestSupport.profile('high_contrast'));
            testCase.verifyEqual(renderer.CurrentIndex, current);
            testCase.verifyEqual(renderer.Handles.LegBL.Spring1.EdgeColor, ...
                [0.85 0.2 0], 'AbsTol', 1e-15);
            testCase.verifyEqual(renderer.Handles.Body.Outline.LineWidth, 4);
            testCase.verifyEqual(numel(findall( ...
                renderer.Handles.Body.Outline.Parent, '-regexp', ...
                'Tag', '^lmz\.quadruped\.')), 49);
            clear cleanup
        end

        function uiAxesHiddenBatchLifecycle(testCase)
            figureHandle = uifigure('Visible', 'off', ...
                'Position', [10 10 640 480]);
            axesHandle = uiaxes(figureHandle, 'Position', [40 40 560 400]);
            renderer = lmzmodels.slip_quadruped.ResearchRenderer(axesHandle, ...
                QuadrupedGraphicsTestSupport.simulation(), ...
                QuadrupedGraphicsTestSupport.profile('research_legacy'), struct());
            cleanup = onCleanup(@() clean(renderer, figureHandle));
            renderer.updateFrame(3);
            testCase.verifyEqual(renderer.CurrentIndex, 3);
            testCase.verifyEqual(numel(findall(axesHandle, '-regexp', ...
                'Tag', '^lmz\.quadruped\.')), 49);
            testCase.verifyTrue(all(isfinite(renderer.Handles.Body.Outline.XData)));
            clear cleanup
        end

        function registryDefaultsAndFactorySelectResearchOnlyForScientific(testCase)
            registry = lmz.registry.ModelRegistry.discover();
            registryCleanup = onCleanup(@() delete(registry));
            profiles = lmz.viz.VisualizationProfileRegistry(registry);
            testCase.verifyEqual(profiles.defaultProfile( ...
                'slip_quadruped', 'periodic_apex').Id, 'research_legacy');
            testCase.verifyEqual(profiles.defaultProfile( ...
                'slip_quadruped', 'demo_stride').Id, 'clean_generic');
            figureHandle = figure('Visible', 'off');
            figureCleanup = onCleanup(@() delete(figureHandle));
            factory = lmz.viz.RendererFactory(registry, profiles);
            [renderer, profile] = factory.createRenderer(axes(figureHandle), ...
                QuadrupedGraphicsTestSupport.simulation(), ...
                'slip_quadruped', 'periodic_apex');
            rendererCleanup = onCleanup(@() delete(renderer));
            testCase.verifyClass(renderer, ...
                'lmzmodels.slip_quadruped.ResearchRenderer');
            testCase.verifyEqual(profile.Id, 'research_legacy');
            clear rendererCleanup figureCleanup registryCleanup
        end

        function cleanRendererRetainsStableLifecycleContract(testCase)
            simulation = QuadrupedGraphicsTestSupport.simulation();
            figureHandle = figure('Visible', 'off');
            renderer = lmzmodels.slip_quadruped.QuadrupedRenderer( ...
                axes(figureHandle), simulation);
            cleanup = onCleanup(@() clean(renderer, figureHandle));
            testCase.verifyTrue(isa(renderer, 'lmz.viz.Renderer'));
            testCase.verifyEqual(renderer.frameCount(), 3);
            count = numel(findall(renderer.Handles.Body.Parent));
            renderer.updateFrame(2);
            testCase.verifyEqual(renderer.CurrentIndex, 2);
            testCase.verifyEqual(numel(findall(renderer.Handles.Body.Parent)), count);
            clear cleanup
        end
    end
end

function [renderer, figureHandle] = makeRenderer(profileId)
figureHandle = figure('Visible', 'off', 'Position', [10 10 640 480]);
renderer = lmzmodels.slip_quadruped.ResearchRenderer( ...
    axes('Parent', figureHandle), ...
    QuadrupedGraphicsTestSupport.simulation(), ...
    QuadrupedGraphicsTestSupport.profile(profileId), struct());
end

function value = expectedLayerOrder()
value = {};
for code = {'bl','fl'}
    value = [value, legTags(code{1})]; %#ok<AGROW>
end
value = [value, {'lmz.quadruped.ground.field', ...
    'lmz.quadruped.ground.hatch', ...
    'lmz.quadruped.body.background', ...
    'lmz.quadruped.body.shading', 'lmz.quadruped.body.outline', ...
    'lmz.quadruped.com.outer', 'lmz.quadruped.com.inner'}];
for code = {'br','fr'}
    value = [value, legTags(code{1})]; %#ok<AGROW>
end
for code = {'bl','fl','br','fr'}
    value{end+1} = ['lmz.quadruped.force.' code{1}]; %#ok<AGROW>
end
value = [value, {'lmz.quadruped.overlay.title', ...
    'lmz.quadruped.phase.box'}];
for index = 1:4
    value{end+1} = sprintf('lmz.quadruped.phase.text.%d', index); %#ok<AGROW>
end
for code = {'bl','br','fl','fr'}
    value = [value, {['lmz.quadruped.phase.' code{1} '.base'], ...
        ['lmz.quadruped.phase.' code{1} '.duration']}]; %#ok<AGROW>
end
end

function value = legTags(code)
prefix = ['lmz.quadruped.leg_' code '.'];
value = {[prefix 'spring1'], [prefix 'upper_background'], ...
    [prefix 'upper_shading'], [prefix 'upper_outline'], ...
    [prefix 'lower'], [prefix 'spring2']};
end

function clean(renderer, figureHandle)
try
    if ~isempty(renderer) && isvalid(renderer), delete(renderer); end
catch
end
if ~isempty(figureHandle) && isgraphics(figureHandle), delete(figureHandle); end
end
