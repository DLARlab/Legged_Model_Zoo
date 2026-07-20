classdef HopperPlotPlugin < lmz.viz.PlotPlugin
    %HOPPERPLOTPLUGIN Generic scene and plots for the built-in tutorial.
    properties (SetAccess = private)
        ScenePath
    end
    methods
        function obj = HopperPlotPlugin(scenePath)
            obj.ScenePath = scenePath;
        end

        function value = sceneSpec(obj)
            value = lmz.viz.SceneSpec.fromJson( ...
                obj.ScenePath, fileparts(obj.ScenePath));
        end

        function value = kinematicsFrame(~, simulation, index)
            x = simulation.state('x');
            y = simulation.state('y');
            frames = struct('world', [0 0 0], ...
                'body', [x(index) y(index) 0], ...
                'ground_contact', [x(index) 0 0]);
            vectors = struct('vertical_force', [0 0]);
            value = lmz.viz.KinematicsFrame( ...
                simulation.Time(index), index, frames, ...
                'Vectors', vectors);
        end

        function value = plotDescriptors(~)
            value = struct('id', {'trajectory','states'}, ...
                'label', {'Hopper trajectory','Hopper states'});
        end

        function handles = plot(~, axesHandle, descriptorId, simulation, ~)
            cla(axesHandle);
            switch descriptorId
                case 'trajectory'
                    handles = plot(axesHandle, ...
                        simulation.state('x'), simulation.state('y'), ...
                        'LineWidth', 1.5);
                    xlabel(axesHandle, 'x');
                    ylabel(axesHandle, 'y');
                case 'states'
                    handles = plot(axesHandle, simulation.Time, ...
                        simulation.States, 'LineWidth', 1.2);
                    xlabel(axesHandle, 'time');
                    ylabel(axesHandle, 'state');
                otherwise
                    error('lmz:tutorial_hopper:Plot', ...
                        'Unknown plot descriptor %s.', descriptorId);
            end
            grid(axesHandle, 'on');
        end
    end
end
