classdef ModelRegistry < handle
    properties (SetAccess=private), AssetRoot char; Manifests struct=struct([]); end
    methods
        function obj=ModelRegistry(assetRoot),if nargin<1,assetRoot=fullfile(lmz.core.ModelRegistry.projectRoot(),'assets','models');end;obj.AssetRoot=char(assetRoot);obj.refresh();end
        function refresh(obj)
            files=dir(fullfile(obj.AssetRoot,'*','manifest.json'));out=struct([]);
            for i=1:numel(files),p=fullfile(files(i).folder,files(i).name);try,m=lmz.io.ManifestLoader.load(p);m.manifest_path=p;if isempty(out),out=m;else,out(end+1)=m;end;catch ME,warning('lmz:ManifestSkipped','Skipping %s: %s',p,ME.message);end,end;obj.Manifests=out;
        end
        function ids=ids(obj),if isempty(obj.Manifests),ids={};else,ids={obj.Manifests.id};end,end
        function m=manifest(obj,id),i=find(strcmp(obj.ids(),char(id)),1);if isempty(i),error('lmz:UnknownModel','Unknown model %s.',id);end;m=obj.Manifests(i);end
        function model=create(obj,id),m=obj.manifest(id);model=feval(m.model_class);end
    end
    methods (Static),function p=projectRoot(),p=fileparts(fileparts(fileparts(mfilename('fullpath'))));end,end
end
