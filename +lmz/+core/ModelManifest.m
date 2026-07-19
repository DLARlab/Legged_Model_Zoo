classdef ModelManifest
    properties (SetAccess=private), Data struct; Path char; end
    methods
        function obj=ModelManifest(path),obj.Path=char(path);obj.Data=lmz.io.ManifestLoader.load(path);end
        function v=get(obj,key),v=obj.Data.(key);end
    end
end
