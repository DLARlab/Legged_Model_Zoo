classdef Geometry
    %GEOMETRY Validated numeric geometry with provenance metadata.
    properties (SetAccess=private)
        Name
        Metadata
    end
    methods
        function obj=Geometry(name,metadata)
            if nargin==0,return,end
            if nargin<2,metadata=struct();end
            if ~ischar(name)||isempty(regexp(name,'^[A-Za-z][A-Za-z0-9_]*$','once'))
                error('lmz:Geometry:Name','Geometry name must be an identifier.');
            end
            if ~isstruct(metadata)||~isscalar(metadata)
                error('lmz:Geometry:Metadata','Geometry metadata must be one object.');
            end
            obj.Name=name;obj.Metadata=metadata;
        end
        function value=toStruct(obj)
            value=struct('name',obj.Name,'metadata',obj.Metadata);
        end
    end
end
