classdef ManifestLoader
    methods (Static)
        function manifest=load(path)
            if ~isfile(path),error('lmz:ManifestMissing','Manifest not found: %s',path);end
            manifest=jsondecode(fileread(path)); report=lmz.io.ManifestLoader.validate(manifest,fileparts(path)); report.throwIfInvalid();
        end
        function report=validate(m,folder)
            if nargin<2,folder='';end;report=lmz.core.ValidationReport(); req={'schema_version','id','display_name','model_version','model_class','visual_asset','capabilities','states','parameters','problems'};
            for i=1:numel(req),if ~isfield(m,req{i}),report=report.addError(['Missing manifest field: ' req{i}]);end,end
            if ~report.IsValid,return;end
            for field={'states','parameters'},entries=m.(field{1});if ~isempty(entries),keys={entries.key};if numel(unique(keys))~=numel(keys),report=report.addError([field{1} ' keys must be unique.']);end;for j=1:numel(entries),e=entries(j);if e.scale<=0||e.lower>e.upper||~isfinite(e.default),report=report.addError(['Invalid schema entry: ' e.key]);end,end,end,end
            if ~isempty(folder)&&~isfile(fullfile(folder,m.visual_asset)),report=report.addError('Visual asset does not exist.');end
            if isempty(which(m.model_class)),report=report.addError(['Model class is not on path: ' m.model_class]);end
            if ~isempty(m.problems),ids={m.problems.id};if numel(unique(ids))~=numel(ids),report=report.addError('Problem IDs must be unique.');end,end
        end
    end
end
