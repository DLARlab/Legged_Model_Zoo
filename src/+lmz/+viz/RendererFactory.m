classdef RendererFactory < handle
    %RENDERERFACTORY Create trusted renderers selected by graphics config.
    properties (SetAccess=private)
        ModelRegistry
        ProfileRegistry
    end
    methods
        function obj=RendererFactory(modelRegistry,profileRegistry)
            if nargin<1,modelRegistry=lmz.registry.ModelRegistry.discover();end
            if nargin<2
                profileRegistry=lmz.viz.VisualizationProfileRegistry(modelRegistry);
            end
            if ~isa(modelRegistry,'lmz.registry.ModelRegistry')|| ...
                    ~isa(profileRegistry,'lmz.viz.VisualizationProfileRegistry')
                error('lmz:RendererFactory:Registry', ...
                    'Model and visualization profile registries are required.');
            end
            obj.ModelRegistry=modelRegistry;obj.ProfileRegistry=profileRegistry;
        end

        function [renderer,profile]=createRenderer(obj,axesHandle,simulation, ...
                modelId,problemId,profileId,options)
            if nargin<6,profileId='';end
            if nargin<7,options=struct();end
            if ~isa(simulation,'lmz.api.SimulationResult')
                error('lmz:RendererFactory:Simulation','SimulationResult is required.');
            end
            profile=obj.ProfileRegistry.resolve(modelId,problemId,profileId);
            model=obj.ModelRegistry.createModel(modelId);
            if strcmp(profile.RendererClass,'lmz.viz.SceneRenderer2D')
                plugin=visualizationPlugin(model);
                if isempty(plugin)
                    error('lmz:RendererFactory:GenericPlugin', ...
                        'Model %s has no generic visualization plugin.',modelId);
                end
                if isempty(profile.ScenePath),spec=plugin.sceneSpec();else
                    spec=lmz.viz.SceneSpec.fromJson(profile.ScenePath, ...
                        fileparts(profile.ScenePath));
                end
                renderer=lmz.viz.SceneRenderer2D(axesHandle,spec,simulation, ...
                    plugin,profile,options);
            else
                constructor=str2func(profile.RendererClass);
                renderer=constructor(axesHandle,simulation,profile,options);
            end
            if ~isa(renderer,'lmz.viz.Renderer')
                try
                    delete(renderer);
                catch
                end
                error('lmz:RendererFactory:Contract', ...
                    ['Configured renderer must derive from lmz.viz.Renderer ' ...
                    'and implement its stable lifecycle contract.']);
            end
        end

        function rendered=renderPlots(obj,axesMap,simulation,modelId,profile)
            rendered=false;model=obj.ModelRegistry.createModel(modelId);
            if ismethod(model,'plotSimulation')
                model.plotSimulation(axesMap,simulation,profile);rendered=true;return
            end
            plugin=visualizationPlugin(model);
            if ~isempty(plugin)&&ismethod(plugin,'plotSimulation')
                plugin.plotSimulation(axesMap,simulation,profile);rendered=true;
                return
            end
            if ~isempty(plugin)
                descriptors=plugin.plotDescriptors();
                targets={axesMap.Torso,axesMap.Back,axesMap.Front, ...
                    axesMap.Forces,axesMap.Auxiliary};
                count=min(numel(descriptors),numel(targets));
                for index=1:count
                    plugin.plot(targets{index},descriptors(index).id, ...
                        simulation,struct('Profile',profile.Id));
                end
                for index=count+1:numel(targets),cla(targets{index});end
                rendered=count>0;
            end
        end
    end
end

function plugin=visualizationPlugin(model)
plugin=[];
if ismethod(model,'getVisualizationPlugin'),plugin=model.getVisualizationPlugin();end
if ~isempty(plugin)&&~isa(plugin,'lmz.viz.PlotPlugin')
    error('lmz:RendererFactory:PluginContract', ...
        'Visualization plugin must implement lmz.viz.PlotPlugin.');
end
end
