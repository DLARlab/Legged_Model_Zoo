classdef SceneRenderer2D < lmz.viz.Renderer
    %SCENERENDERER2D Graphics renderer for validated declarative scenes.
    properties (SetAccess = private)
        Spec
        Plugin
    end
    methods
        function obj = SceneRenderer2D(axesHandle, spec, simulation, plugin,profile,options)
            if nargin<5,profile=[];end
            if nargin<6,options=struct();end
            if isempty(axesHandle) || ~isgraphics(axesHandle, 'axes')
                error('lmz:Scene:Axes', 'A valid axes is required.');
            end
            if ~isa(spec, 'lmz.viz.SceneSpec') || ...
                    ~isa(plugin, 'lmz.viz.PlotPlugin') || ...
                    ~isa(simulation, 'lmz.api.SimulationResult')
                error('lmz:Scene:RendererInput', ...
                    'SceneSpec, SimulationResult, and PlotPlugin are required.');
            end
            obj@lmz.viz.Renderer(axesHandle,[],profile,options);
            obj.Spec = spec;
            obj.Plugin = plugin;
            obj.initialize(simulation);
        end

        function delete(obj)
            delete@lmz.viz.Renderer(obj);obj.Plugin=[];
        end
    end

    methods (Access=protected)
        function updateHandles(obj, index)
            if isempty(obj.Axes) || ~isgraphics(obj.Axes)
                return
            end
            frame = obj.Plugin.kinematicsFrame(obj.Simulation, index);
            if ~isa(frame, 'lmz.viz.KinematicsFrame')
                error('lmz:Scene:KinematicsContract', ...
                    'PlotPlugin must return KinematicsFrame.');
            end
            for primitiveIndex = 1:numel(obj.Spec.Primitives)
                primitive = obj.Spec.Primitives{primitiveIndex};
                graphicsHandle = obj.Handles{primitiveIndex};
                switch primitive.type
                    case 'ground'
                        y = fieldOr(primitive, 'y', 0);
                        range = fieldOr(primitive, 'xRange', [-2 2]);
                        set(graphicsHandle, 'XData', range, 'YData', [y y], ...
                            'Visible',onOff(obj.GroundVisible));
                    case 'polygon'
                        center = frame.position(primitive.frame);
                        angle = frame.angle(primitive.frame);
                        vertices = fieldOr(primitive, 'vertices', ...
                            [-0.2 -0.08; 0.2 -0.08; 0.2 0.08; -0.2 0.08]);
                        rotation = [cos(angle) -sin(angle); sin(angle) cos(angle)];
                        points = vertices * rotation.' + center;
                        set(graphicsHandle, 'XData', points(:, 1), 'YData', points(:, 2));
                    case 'marker'
                        point = frame.position(primitive.frame);
                        set(graphicsHandle, 'XData', point(1), 'YData', point(2));
                    case {'line','rope'}
                        first = frame.position(primitive.from);
                        second = frame.position(primitive.to);
                        set(graphicsHandle, 'XData', [first(1) second(1)], ...
                            'YData', [first(2) second(2)]);
                    case 'spring'
                        first = frame.position(primitive.from);
                        second = frame.position(primitive.to);
                        points = lmz.viz.SceneRenderer2D.springPoints(first, second);
                        set(graphicsHandle, 'XData', points(:, 1), 'YData', points(:, 2));
                    case 'force_vector'
                        point = frame.position(primitive.frame);
                        vector = frame.vector(primitive.vector) * ...
                            fieldOr(primitive, 'scale', 1);
                        set(graphicsHandle, 'XData', point(1), 'YData', point(2), ...
                            'UData', vector(1), 'VData', vector(2));
                    case 'trail'
                        points = zeros(index, 2);
                        for trailIndex = 1:index
                            historical = obj.Plugin.kinematicsFrame( ...
                                obj.Simulation, trailIndex);
                            points(trailIndex, :) = ...
                                historical.position(primitive.frame);
                        end
                        set(graphicsHandle, 'XData', points(:, 1), 'YData', points(:, 2));
                    case 'text'
                        point = frame.position(primitive.frame);
                        offset = fieldOr(primitive, 'offset', [0 0]);
                        point = point + reshape(offset, 1, 2);
                        label = fieldOr(primitive, 'text', '');
                        set(graphicsHandle, 'Position', [point 0], ...
                            'String', label);
                end
            end
        end

        function buildHandles(obj)
            wasHeld=ishold(obj.Axes);hold(obj.Axes, 'on');
            obj.Handles = cell(1, numel(obj.Spec.Primitives));
            for index = 1:numel(obj.Spec.Primitives)
                primitive = obj.Spec.Primitives{index};
                color = profileColor(obj,primitive,index);
                width = fieldOr(primitive, 'lineWidth', 1.5);
                switch primitive.type
                    case 'ground'
                        graphicsHandle = plot(obj.Axes, nan, nan, '-', ...
                            'Color', color, 'LineWidth', width);
                    case 'polygon'
                        graphicsHandle = patch('Parent',obj.Axes, ...
                            'XData',nan,'YData',nan,'FaceColor',color, ...
                            'EdgeColor',color,'FaceAlpha',0.35);
                    case 'marker'
                        graphicsHandle = plot(obj.Axes, nan, nan, ...
                            fieldOr(primitive, 'marker', 'o'), ...
                            'Color', color, 'MarkerFaceColor', color, ...
                            'MarkerSize', fieldOr(primitive, 'markerSize', 7));
                    case {'line','spring','rope','trail'}
                        style = '-';
                        if strcmp(primitive.type, 'rope'), style = '--'; end
                        graphicsHandle = plot(obj.Axes, nan, nan, style, ...
                            'Color', color, 'LineWidth', width);
                    case 'force_vector'
                        graphicsHandle = quiver(obj.Axes, nan, nan, nan, nan, 0, ...
                            'Color', color, 'LineWidth', width);
                    case 'text'
                        graphicsHandle = text(obj.Axes, 0, 0, '', ...
                            'Color', color, 'Interpreter', 'none');
                end
                obj.Handles{index} = graphicsHandle;
            end
            if ~wasHeld,hold(obj.Axes, 'off');end
            if isempty(obj.Profile)
                xlabel(obj.Axes, 'x');ylabel(obj.Axes, 'y');
                title(obj.Axes, 'Generic hybrid scene');
            end
        end

        function applyOptions(obj)
            if ~obj.IsInitialized,return,end
            for index=1:numel(obj.Spec.Primitives)
                if strcmp(obj.Spec.Primitives{index}.type,'ground')&& ...
                        isgraphics(obj.Handles{index})
                    set(obj.Handles{index},'Visible',onOff(obj.GroundVisible));
                end
            end
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

function color=profileColor(obj,primitive,index)
color=fieldOr(primitive,'color',[0.15 0.15 0.15]);
if isempty(obj.Profile),return,end
if strcmp(obj.Profile.Id,'high_contrast')
    palette=[0 0 0;0 0.32 0.95;0.9 0.2 0;0.15 0.62 0.15;0.58 0.12 0.78];
    color=palette(1+mod(index-1,size(palette,1)),:);
elseif isfield(obj.Profile.Style,'primaryColor')
    color=obj.Profile.Style.primaryColor;
end
end

function value=onOff(flag)
if flag,value='on';else,value='off';end
end

function value = fieldOr(source, name, fallback)
if isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
