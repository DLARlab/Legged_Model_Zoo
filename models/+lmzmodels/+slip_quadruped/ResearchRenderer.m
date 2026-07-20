classdef ResearchRenderer < lmz.viz.ResearchRenderer
    %RESEARCHRENDERER Source-faithful compound quadruped renderer.
    %   This class owns only handles below the supplied axes. Playback,
    %   interpolation, and recording remain service responsibilities.
    properties (SetAccess=private)
        Style
        LayerOrder = {}
    end
    properties (Access=private)
        GroundGeometry
    end

    methods
        function obj = ResearchRenderer(axesHandle, simulation, profile, options)
            if nargin < 1, axesHandle = []; end
            if nargin < 2, simulation = []; end
            if nargin < 3, profile = []; end
            if nargin < 4, options = struct(); end
            options = profileDefaults(profile, options);
            obj@lmz.viz.ResearchRenderer(axesHandle, [], profile, options);
            obj.Style = lmzmodels.slip_quadruped.ResearchStyle.resolve(profile);
            if ~isempty(simulation), obj.initialize(simulation); end
        end

        function setProfile(obj, profile)
            obj.Style = lmzmodels.slip_quadruped.ResearchStyle.resolve(profile);
            setProfile@lmz.viz.ResearchRenderer(obj, profile);
        end

        function value = sourceLayerOrder(obj)
            %SOURCELAYERORDER Bottom-to-top creation order of owned handles.
            value = obj.LayerOrder;
        end
    end

    methods (Access=protected)
        function configureAxes(obj)
            configureAxes@lmz.viz.ResearchRenderer(obj);
            hold(obj.Axes, 'on');
            box(obj.Axes, 'off');
            obj.Axes.Color = [1 1 1];
        end

        function buildHandles(obj)
            frame = lmzmodels.slip_quadruped.ResearchLegGeometry. ...
                frame(obj.Simulation, 1);
            body = lmzmodels.slip_quadruped.ResearchBodyGeometry.compute( ...
                frame.BodyFrame, namedParameter(obj.Simulation, 'l_b'));
            com = lmzmodels.slip_quadruped.ResearchCOMGeometry.compute( ...
                frame.BodyFrame, obj.Style.com.radius);
            obj.GroundGeometry = ...
                lmzmodels.slip_quadruped.ResearchGroundGeometry.compute();
            phase = lmzmodels.slip_quadruped.ResearchPhaseDiagramGeometry. ...
                compute(frame.BodyFrame(1), frame.Schedule);
            obj.LayerOrder = {};

            [obj.Handles.LegBL, tags] = createLeg(obj.Axes, ...
                frame.Geometry{1}, obj.Style, 'bl');
            obj.LayerOrder = [obj.LayerOrder, tags];
            [obj.Handles.LegFL, tags] = createLeg(obj.Axes, ...
                frame.Geometry{2}, obj.Style, 'fl');
            obj.LayerOrder = [obj.LayerOrder, tags];

            obj.Handles.Ground.Field = patchGeometry(obj.Axes, ...
                obj.GroundGeometry.Field, obj.Style.ground.fieldColor, ...
                obj.Style.ground.edgeColor, obj.Style.ground.lineWidth, ...
                'lmz.quadruped.ground.field');
            obj.Handles.Ground.Hatch = patchGeometry(obj.Axes, ...
                obj.GroundGeometry.Hatch, obj.Style.ground.hatchColor, ...
                obj.Style.ground.hatchColor, obj.Style.ground.lineWidth, ...
                'lmz.quadruped.ground.hatch');
            obj.LayerOrder = [obj.LayerOrder, ...
                {'lmz.quadruped.ground.field','lmz.quadruped.ground.hatch'}];

            obj.Handles.Body.Background = patchGeometry(obj.Axes, ...
                body.Background, obj.Style.body.backgroundColor, 'none', ...
                0.5, 'lmz.quadruped.body.background');
            obj.Handles.Body.Shading = patchGeometry(obj.Axes, ...
                body.Shading, 'none', obj.Style.body.shadeColor, ...
                obj.Style.body.shadeWidth, 'lmz.quadruped.body.shading');
            obj.Handles.Body.Outline = plot(obj.Axes, ...
                body.Outline.Points(:, 1), body.Outline.Points(:, 2), '-', ...
                'Color', obj.Style.body.edgeColor, ...
                'LineWidth', obj.Style.body.outlineWidth, ...
                'Tag', 'lmz.quadruped.body.outline');
            obj.LayerOrder = [obj.LayerOrder, ...
                {'lmz.quadruped.body.background', ...
                 'lmz.quadruped.body.shading', ...
                 'lmz.quadruped.body.outline'}];

            obj.Handles.COM.Outer = patchGeometry(obj.Axes, com.Outer, ...
                obj.Style.com.outerColor, obj.Style.com.edgeColor, ...
                obj.Style.com.outerWidth, 'lmz.quadruped.com.outer');
            obj.Handles.COM.Inner = patchGeometry(obj.Axes, com.Inner, ...
                'flat', obj.Style.com.edgeColor, obj.Style.com.innerWidth, ...
                'lmz.quadruped.com.inner');
            set(obj.Handles.COM.Inner, 'FaceVertexCData', com.InnerFaceColors);
            obj.LayerOrder = [obj.LayerOrder, ...
                {'lmz.quadruped.com.outer','lmz.quadruped.com.inner'}];

            [obj.Handles.LegBR, tags] = createLeg(obj.Axes, ...
                frame.Geometry{3}, obj.Style, 'br');
            obj.LayerOrder = [obj.LayerOrder, tags];
            [obj.Handles.LegFR, tags] = createLeg(obj.Axes, ...
                frame.Geometry{4}, obj.Style, 'fr');
            obj.LayerOrder = [obj.LayerOrder, tags];

            obj.Handles.Forces = gobjects(1, 4);
            legCodes = {'bl','fl','br','fr'};
            for leg = 1:4
                tag = ['lmz.quadruped.force.' legCodes{leg}];
                obj.Handles.Forces(leg) = quiver(obj.Axes, nan, nan, ...
                    nan, nan, 0, 'Color', obj.Style.force.color, ...
                    'LineWidth', obj.Style.force.lineWidth, 'Tag', tag);
                obj.LayerOrder{end+1} = tag;
            end

            obj.Handles.Title = text(obj.Axes, frame.BodyFrame(1)-1.3, ...
                1.9, 'SLIP Model Animation', ...
                'Color', obj.Style.phase.textColor, ...
                'FontSize', obj.Style.phase.titleFontSize, ...
                'FontWeight', 'bold', 'Interpreter', 'none', ...
                'Tag', 'lmz.quadruped.overlay.title');
            obj.LayerOrder{end+1} = 'lmz.quadruped.overlay.title';
            obj.Handles.Phase.Box = patchGeometry(obj.Axes, phase.Box, ...
                obj.Style.phase.boxColor, obj.Style.phase.edgeColor, ...
                obj.Style.phase.lineWidth, 'lmz.quadruped.phase.box');
            obj.LayerOrder{end+1} = 'lmz.quadruped.phase.box';
            obj.Handles.Phase.Text = gobjects(1, 4);
            for item = 1:4
                tag = sprintf('lmz.quadruped.phase.text.%d', item);
                obj.Handles.Phase.Text(item) = text(obj.Axes, ...
                    phase.TextPositions(item, 1), ...
                    phase.TextPositions(item, 2), phase.TextLabels{item}, ...
                    'Color', obj.Style.phase.textColor, ...
                    'FontSize', obj.Style.phase.fontSize, ...
                    'Interpreter', 'none', 'Tag', tag);
                obj.LayerOrder{end+1} = tag;
            end
            obj.Handles.Phase.Bars = repmat(struct('Base', [], ...
                'Duration', []), 1, 4);
            for item = 1:4
                code = lower(phase.Bars(item).Id);
                baseTag = ['lmz.quadruped.phase.' code '.base'];
                durationTag = ['lmz.quadruped.phase.' code '.duration'];
                obj.Handles.Phase.Bars(item).Base = patchGeometry(obj.Axes, ...
                    phase.Bars(item).Base, phase.Bars(item).BaseColor, ...
                    'none', 0.5, baseTag);
                obj.Handles.Phase.Bars(item).Duration = patchGeometry( ...
                    obj.Axes, phase.Bars(item).Duration, ...
                    phase.Bars(item).DurationColor, 'none', 0.5, durationTag);
                obj.LayerOrder = [obj.LayerOrder, {baseTag, durationTag}];
            end
            obj.applyOptions();
        end

        function updateHandles(obj, index)
            frame = lmzmodels.slip_quadruped.ResearchLegGeometry. ...
                frame(obj.Simulation, index);
            legFields = {'LegBL','LegFL','LegBR','LegFR'};
            for leg = 1:4
                updateLeg(obj.Handles.(legFields{leg}), frame.Geometry{leg});
            end
            body = lmzmodels.slip_quadruped.ResearchBodyGeometry.compute( ...
                frame.BodyFrame, namedParameter(obj.Simulation, 'l_b'));
            set(obj.Handles.Body.Background, ...
                'Vertices', body.Background.Vertices);
            set(obj.Handles.Body.Shading, 'Vertices', body.Shading.Vertices);
            set(obj.Handles.Body.Outline, ...
                'XData', body.Outline.Points(:, 1), ...
                'YData', body.Outline.Points(:, 2));

            com = lmzmodels.slip_quadruped.ResearchCOMGeometry.compute( ...
                frame.BodyFrame, obj.Style.com.radius);
            set(obj.Handles.COM.Outer, 'Vertices', com.Outer.Vertices);
            set(obj.Handles.COM.Inner, 'Vertices', com.Inner.Vertices);
            showCOM = namedParameter(obj.Simulation, 'l_b') ~= 0.5;
            set([obj.Handles.COM.Outer, obj.Handles.COM.Inner], ...
                'Visible', onOff(showCOM));

            phase = lmzmodels.slip_quadruped.ResearchPhaseDiagramGeometry. ...
                compute(frame.BodyFrame(1), frame.Schedule);
            set(obj.Handles.Title, 'Position', ...
                [frame.BodyFrame(1)-1.3, 1.9, 0]);
            set(obj.Handles.Phase.Box, 'Vertices', phase.Box.Vertices);
            for item = 1:4
                set(obj.Handles.Phase.Text(item), 'Position', ...
                    [phase.TextPositions(item, :), 0]);
                set(obj.Handles.Phase.Bars(item).Base, ...
                    'Vertices', phase.Bars(item).Base.Vertices, ...
                    'FaceColor', phase.Bars(item).BaseColor);
                set(obj.Handles.Phase.Bars(item).Duration, ...
                    'Vertices', phase.Bars(item).Duration.Vertices, ...
                    'FaceColor', phase.Bars(item).DurationColor);
            end
            updateForces(obj, frame, index);
            if obj.CameraFollow
                window = [-1.5 1.5];
                if ~isempty(obj.Profile) && ...
                        isfield(obj.Profile.Camera, 'followWindow') && ...
                        numel(obj.Profile.Camera.followWindow) == 2
                    window = reshape(obj.Profile.Camera.followWindow, 1, 2);
                end
                xlim(obj.Axes, frame.BodyFrame(1)+window);
            end
            obj.applyOptions();
        end

        function applyOptions(obj)
            if isempty(fieldnames(obj.Handles)), return, end
            groundStyle = 'hatched';
            if isfield(obj.Options, 'GroundStyle') && ...
                    (ischar(obj.Options.GroundStyle) || ...
                     (isstring(obj.Options.GroundStyle) && ...
                      isscalar(obj.Options.GroundStyle)))
                groundStyle = char(obj.Options.GroundStyle);
            end
            showField = obj.GroundVisible && ~strcmp(groundStyle, 'none');
            showHatch = showField && strcmp(groundStyle, 'hatched');
            set(obj.Handles.Ground.Field, 'Visible', onOff(showField));
            set(obj.Handles.Ground.Hatch, 'Visible', onOff(showHatch));
            overlay = onOff(obj.DetailedOverlay);
            set(obj.Handles.Title, 'Visible', overlay);
            set(obj.Handles.Phase.Box, 'Visible', overlay);
            set(obj.Handles.Phase.Text, 'Visible', overlay);
            for item = 1:numel(obj.Handles.Phase.Bars)
                set(obj.Handles.Phase.Bars(item).Base, 'Visible', overlay);
                set(obj.Handles.Phase.Bars(item).Duration, 'Visible', overlay);
            end
            if ~obj.ShowForces
                set(obj.Handles.Forces, 'Visible', 'off');
            end
        end
    end
end

function options = profileDefaults(profile, options)
if ~isstruct(options) || ~isscalar(options)
    error('lmz:Renderer:Options', 'Renderer options must be a scalar object.');
end
if ~isfield(options, 'DetailedOverlay')
    options.DetailedOverlay = ~isempty(profile) && ...
        any(strcmp(profile.Overlays, 'detailed_phase'));
end
if ~isfield(options, 'ShowForces')
    options.ShowForces = ~isempty(profile) && ...
        any(strcmp(profile.Overlays, 'force_vectors'));
end
if ~isfield(options, 'GroundVisible'), options.GroundVisible = true; end
if ~isfield(options, 'CameraFollow')
    options.CameraFollow = ~isempty(profile) && ...
        isfield(profile.Camera, 'follow') && profile.Camera.follow;
end
end

function [handles, tags] = createLeg(ax, geometry, style, code)
prefix = ['lmz.quadruped.leg_' code '.'];
tags = {[prefix 'spring1'], [prefix 'upper_background'], ...
    [prefix 'upper_shading'], [prefix 'upper_outline'], ...
    [prefix 'lower'], [prefix 'spring2']};
handles.Spring1 = patchGeometry(ax, geometry.Spring1, 'none', ...
    style.leg.springColor, style.leg.springWidth, tags{1});
handles.UpperBackground = patchGeometry(ax, geometry.UpperBackground, ...
    style.leg.upperBackgroundColor, 'none', 0.5, tags{2});
handles.UpperShading = patchGeometry(ax, geometry.UpperShading, 'none', ...
    style.leg.shadeColor, style.leg.shadeWidth, tags{3});
handles.UpperOutline = patchGeometry(ax, geometry.UpperOutline, 'none', ...
    style.leg.outlineColor, style.leg.outlineWidth, tags{4});
handles.Lower = patchGeometry(ax, geometry.Lower, style.leg.lowerColor, ...
    style.leg.lowerEdgeColor, style.leg.lowerWidth, tags{5});
handles.Spring2 = patchGeometry(ax, geometry.Spring2, 'none', ...
    style.leg.springColor, style.leg.springWidth, tags{6});
end

function updateLeg(handles, geometry)
set(handles.Spring1, 'Vertices', geometry.Spring1.Vertices);
set(handles.UpperBackground, 'Vertices', geometry.UpperBackground.Vertices);
set(handles.UpperShading, 'Vertices', geometry.UpperShading.Vertices);
set(handles.UpperOutline, 'Vertices', geometry.UpperOutline.Vertices);
set(handles.Lower, 'Vertices', geometry.Lower.Vertices);
set(handles.Spring2, 'Vertices', geometry.Spring2.Vertices);
end

function handle = patchGeometry(ax, geometry, faceColor, edgeColor, width, tag)
handle = patch(ax, 'Faces', geometry.Faces, 'Vertices', geometry.Vertices, ...
    'FaceColor', faceColor, 'EdgeColor', edgeColor, ...
    'LineWidth', width, 'Tag', tag);
end

function updateForces(obj, frame, index)
forces = obj.Simulation.GroundReactionForces;
available = ~isempty(forces) && size(forces, 2) >= 12;
for leg = 1:4
    if obj.ShowForces && available
        horizontal = forces(index, 4+leg);
        vertical = forces(index, 8+leg);
        set(obj.Handles.Forces(leg), ...
            'XData', frame.Feet(leg, 1), 'YData', frame.Feet(leg, 2), ...
            'UData', obj.Style.force.scale*horizontal, ...
            'VData', obj.Style.force.scale*vertical, 'Visible', 'on');
    else
        set(obj.Handles.Forces(leg), 'Visible', 'off');
    end
end
end

function value = namedParameter(simulation, name)
if ~isstruct(simulation.Parameters) || ~isfield(simulation.Parameters, name) || ...
        ~isnumeric(simulation.Parameters.(name)) || ...
        ~isreal(simulation.Parameters.(name)) || ...
        ~isscalar(simulation.Parameters.(name)) || ...
        ~isfinite(simulation.Parameters.(name))
    error('lmz:slip_quadruped:GeometryParameter', ...
        'Simulation parameter %s is required.', name);
end
value = simulation.Parameters.(name);
end

function value = onOff(flag)
if flag, value = 'on'; else, value = 'off'; end
end
