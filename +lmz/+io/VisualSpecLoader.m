classdef VisualSpecLoader
    methods (Static),function spec=load(path),spec=jsondecode(fileread(path));if ~isfield(spec,'schema_version')||~isfield(spec,'primitives'),error('lmz:VisualSpec','Invalid visual specification.');end,end,end
end
