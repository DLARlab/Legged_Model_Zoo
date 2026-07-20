classdef (Abstract) PlotPlugin < handle
    %PLOTPLUGIN Model-owned generic scene and named-plot extension point.
    methods
        function renderer = createRenderer(obj, axesHandle, simulation)
            renderer = lmz.viz.SceneRenderer2D( ...
                axesHandle, obj.sceneSpec(), simulation, obj);
        end
    end
    methods (Abstract)
        value = sceneSpec(obj)
        value = kinematicsFrame(obj, simulation, index)
        value = plotDescriptors(obj)
        handles = plot(obj, axesHandle, descriptorId, simulation, options)
    end
end
