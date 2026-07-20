classdef PolylineGeometry < lmz.viz.Geometry
    %POLYLINEGEOMETRY Immutable ordered 2-D/3-D points.
    properties (SetAccess=private)
        Points
    end
    methods
        function obj=PolylineGeometry(name,points,metadata)
            if nargin==0,name='geometry';points=[0 0;0 0];end
            if nargin<3,metadata=struct();end
            obj@lmz.viz.Geometry(name,metadata);
            if ~isnumeric(points)||~isreal(points)||size(points,1)<2|| ...
                    ~any(size(points,2)==[2 3])||any(~isfinite(points(:)))
                error('lmz:Geometry:Points','Polyline points must be finite N-by-2 or N-by-3.');
            end
            obj.Points=points;
        end
        function value=toStruct(obj)
            value=toStruct@lmz.viz.Geometry(obj);value.points=obj.Points;
        end
    end
end
