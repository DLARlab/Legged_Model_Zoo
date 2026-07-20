classdef (Abstract) ResearchRenderer < lmz.viz.Renderer
    %RESEARCHRENDERER Marker base for source-derived scientific renderers.
    properties (Constant)
        FidelityKind='research_legacy'
    end
    methods
        function obj=ResearchRenderer(varargin)
            obj@lmz.viz.Renderer(varargin{:});
        end
    end
end
