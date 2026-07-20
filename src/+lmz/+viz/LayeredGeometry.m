classdef LayeredGeometry < lmz.viz.Geometry
    %LAYEREDGEOMETRY Ordered collection of named geometry layers.
    properties (SetAccess=private)
        Layers
    end
    methods
        function obj=LayeredGeometry(name,layers,metadata)
            if nargin==0,name='geometry';layers={};end
            if nargin<3,metadata=struct();end
            obj@lmz.viz.Geometry(name,metadata);
            if ~iscell(layers)||~all(cellfun(@(item)isa(item,'lmz.viz.Geometry'),layers))
                error('lmz:Geometry:Layers','Layers must contain Geometry values.');
            end
            obj.Layers=reshape(layers,1,[]);
        end
        function value=toStruct(obj)
            value=toStruct@lmz.viz.Geometry(obj);
            value.layers=cellfun(@(item)item.toStruct(),obj.Layers, ...
                'UniformOutput',false);
        end
    end
end
