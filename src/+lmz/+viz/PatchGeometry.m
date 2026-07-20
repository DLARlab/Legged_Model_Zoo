classdef PatchGeometry < lmz.viz.Geometry
    %PATCHGEOMETRY Immutable vertices and polygonal faces.
    properties (SetAccess=private)
        Vertices
        Faces
    end
    methods
        function obj=PatchGeometry(name,vertices,faces,metadata)
            if nargin==0,name='geometry';vertices=[0 0];faces=1;end
            if nargin<4,metadata=struct();end
            obj@lmz.viz.Geometry(name,metadata);
            if ~isnumeric(vertices)||~isreal(vertices)|| ...
                    ~any(size(vertices,2)==[2 3])||any(~isfinite(vertices(:)))|| ...
                    isempty(vertices)
                error('lmz:Geometry:Vertices','Patch vertices must be finite N-by-2 or N-by-3.');
            end
            if ~isnumeric(faces)||~isreal(faces)||isempty(faces)|| ...
                    any(~isfinite(faces(:)))||any(faces(:)~=fix(faces(:)))|| ...
                    any(faces(:)<1)||any(faces(:)>size(vertices,1))
                error('lmz:Geometry:Faces','Patch faces must index the supplied vertices.');
            end
            obj.Vertices=vertices;obj.Faces=faces;
        end
        function value=toStruct(obj)
            value=toStruct@lmz.viz.Geometry(obj);
            value.vertices=obj.Vertices;value.faces=obj.Faces;
        end
    end
end
