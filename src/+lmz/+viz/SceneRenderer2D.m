classdef SceneRenderer2D < handle
    %SCENERENDERER2D Graphics renderer for validated declarative scenes.
    properties (SetAccess = private)
        Axes
        Spec
        Simulation
        Plugin
        Handles = {}
        CurrentIndex = 1
    end
    methods
        function obj = SceneRenderer2D(axesHandle, spec, simulation, plugin)
            if isempty(axesHandle) || ~isgraphics(axesHandle, 'axes')
                error('lmz:Scene:Axes', 'A valid axes is required.');
            end
            if ~isa(spec, 'lmz.viz.SceneSpec') || ...
                    ~isa(plugin, 'lmz.viz.PlotPlugin') || ...
                    ~isa(simulation, 'lmz.api.SimulationResult')
                error('lmz:Scene:RendererInput', ...
                    'SceneSpec, SimulationResult, and PlotPlugin are required.');
            end
            obj.Axes = axesHandle;
            obj.Spec = spec;
            obj.Simulation = simulation;
            obj.Plugin = plugin;
            obj.build();
            obj.updateFrame(1);
        end

        function updateFrame(obj, index)
            if isempty(obj.Axes) || ~isgraphics(obj.Axes)
                return
            end
            if index >= 0 && index <= 1 && index ~= fix(index)
                index = 1 + round(index * (numel(obj.Simulation.Time) - 1));
            end
            index = max(1, min(numel(obj.Simulation.Time), round(index)));
            frame = obj.Plugin.kinematicsFrame(obj.Simulation, index);
            if ~isa(frame, 'lmz.viz.KinematicsFrame')
                error('lmz:Scene:KinematicsContract', ...
                    'PlotPlugin must return KinematicsFrame.');
            end
            for primitiveIndex = 1:numel(obj.Spec.Primitives)
                primitive = obj.Spec.Primitives{primitiveIndex};
                handle = obj.Handles{primitiveIndex};
                switch primitive.type
                    case 'ground'
                        y = fieldOr(primitive, 'y', 0);
                        range = fieldOr(primitive, 'xRange', [-2 2]);
                        set(handle, 'XData', range, 'YData', [y y]);
                    case 'polygon'
                        center = frame.position(primitive.frame);
                        angle = frame.angle(primitive.frame);
                        vertices = fieldOr(primitive, 'vertices', ...
                            [-0.2 -0.08; 0.2 -0.08; 0.2 0.08; -0.2 0.08]);
                        rotation = [cos(angle) -sin(angle); sin(angle) cos(angle)];
                        points = vertices * rotation.' + center;
                        set(handle, 'XData', points(:, 1), 'YData', points(:, 2));
                    case 'marker'
                        point = frame.position(primitive.frame);
                        set(handle, 'XData', point(1), 'YData', point(2));
                    case {'line','rope'}
                        first = frame.position(primitive.from);
                        second = frame.position(primitive.to);
                        set(handle, 'XData', [first(1) second(1)], ...
                            'YData', [first(2) second(2)]);
                    case 'spring'
                        first = frame.position(primitive.from);
                        second = frame.position(primitive.to);
                        points = lmz.viz.SceneRenderer2D.springPoints(first, second);
                        set(handle, 'XData', points(:, 1), 'YData', points(:, 2));
                    case 'force_vector'
                        point = frame.position(primitive.frame);
                        vector = frame.vector(primitive.vector) * ...
                            fieldOr(primitive, 'scale', 1);
                        set(handle, 'XData', point(1), 'YData', point(2), ...
                            'UData', vector(1), 'VData', vector(2));
                    case 'trail'
                        points = zeros(index, 2);
                        for trailIndex = 1:index
                            historical = obj.Plugin.kinematicsFrame( ...
                                obj.Simulation, trailIndex);
                            points(trailIndex, :) = ...
                                historical.position(primitive.frame);
                        end
                        set(handle, 'XData', points(:, 1), 'YData', points(:, 2));
                    case 'text'
                        point = frame.position(primitive.frame);
                        offset = fieldOr(primitive, 'offset', [0 0]);
                        point = point + reshape(offset, 1, 2);
                        label = fieldOr(primitive, 'text', '');
                        set(handle, 'Position', [point 0], ...
                            'String', label);
                end
            end
            obj.CurrentIndex = index;
            drawnow limitrate
        end

        function clear(obj)
            if ~isempty(obj.Axes) && isgraphics(obj.Axes)
                cla(obj.Axes);
            end
            obj.Handles = {};
        end

        function delete(obj)
            obj.clear();
            obj.Simulation = [];
            obj.Plugin = [];
        end
    end

    methods (Access = private)
        function build(obj)
            cla(obj.Axes);
            hold(obj.Axes, 'on');
            grid(obj.Axes, 'on');
            axis(obj.Axes, 'equal');
            obj.Handles = cell(1, numel(obj.Spec.Primitives));
            for index = 1:numel(obj.Spec.Primitives)
                primitive = obj.Spec.Primitives{index};
                color = fieldOr(primitive, 'color', [0.15 0.15 0.15]);
                width = fieldOr(primitive, 'lineWidth', 1.5);
                switch primitive.type
                    case 'ground'
                        handle = plot(obj.Axes, nan, nan, '-', ...
                            'Color', color, 'LineWidth', width);
                    case 'polygon'
                        handle = patch(obj.Axes, nan, nan, color, ...
                            'EdgeColor', color, 'FaceAlpha', 0.35);
                    case 'marker'
                        handle = plot(obj.Axes, nan, nan, ...
                            fieldOr(primitive, 'marker', 'o'), ...
                            'Color', color, 'MarkerFaceColor', color, ...
                            'MarkerSize', fieldOr(primitive, 'markerSize', 7));
                    case {'line','spring','rope','trail'}
                        style = '-';
                        if strcmp(primitive.type, 'rope'), style = '--'; end
                        handle = plot(obj.Axes, nan, nan, style, ...
                            'Color', color, 'LineWidth', width);
                    case 'force_vector'
                        handle = quiver(obj.Axes, nan, nan, nan, nan, 0, ...
                            'Color', color, 'LineWidth', width);
                    case 'text'
                        handle = text(obj.Axes, 0, 0, '', ...
                            'Color', color, 'Interpreter', 'none');
                end
                obj.Handles{index} = handle;
            end
            hold(obj.Axes, 'off');
            xlabel(obj.Axes, 'x');
            ylabel(obj.Axes, 'y');
            title(obj.Axes, 'Generic hybrid scene');
        end
    end

    methods (Static, Access = private)
        function points = springPoints(first, second)
            count = 12;
            fraction = linspace(0, 1, count).';
            direction = second - first;
            lengthValue = norm(direction);
            if lengthValue <= eps
                points = repmat(first, count, 1);
                return
            end
            normal = [-direction(2) direction(1)] / lengthValue;
            offset = zeros(count, 1);
            offset(2:end-1) = 0.025 * (-1).^(1:count-2).';
            points = first + fraction .* direction + offset .* normal;
        end
    end
end

function value = fieldOr(source, name, fallback)
if isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
