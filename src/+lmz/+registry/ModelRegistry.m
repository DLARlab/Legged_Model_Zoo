classdef ModelRegistry
    properties (SetAccess=private), Entries; CatalogRoot; end
    methods (Static)
        function obj=discover(catalogRoot)
            if nargin<1
                here=fileparts(mfilename('fullpath')); catalogRoot=fullfile(here,'..','..','..','..','catalog');
            end
            obj=lmz.registry.ModelRegistry(catalogRoot);
        end
    end
    methods
        function obj=ModelRegistry(root)
            obj.CatalogRoot=char(java.io.File(root).getCanonicalPath()); files=dir(fullfile(root,'*','manifest.json')); entries=struct([]); ids={};
            for k=1:numel(files)
                m=jsondecode(fileread(fullfile(files(k).folder,files(k).name)));
                required={'schemaVersion','id','version','implementationClass','problems'};
                for j=1:numel(required), if ~isfield(m,required{j}), error('lmz:Manifest','Missing %s.',required{j}); end, end
                if ~strncmp(m.implementationClass,'lmzmodels.',10), error('lmz:UnsafeBinding','Implementation must be in lmzmodels namespace.'); end
                if any(strcmp(m.id,ids)), error('lmz:DuplicateModel','Duplicate model id %s.',m.id); end
                ids{end+1}=m.id; entries=[entries;m]; %#ok<AGROW>
            end
            obj.Entries=entries;
        end
        function ids=listModels(obj), ids=arrayfun(@(x)x.id,obj.Entries,'UniformOutput',false); end
        function m=getManifest(obj,id)
            i=find(strcmp(id,obj.listModels()),1); if isempty(i), error('lmz:UnknownModel','Unknown model %s.',id); end; m=obj.Entries(i);
        end
        function model=createModel(obj,id)
            m=obj.getManifest(id); ctor=str2func(m.implementationClass); model=ctor();
        end
    end
end
