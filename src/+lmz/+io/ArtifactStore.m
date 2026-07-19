classdef ArtifactStore
    methods (Static)
        function save(path,artifact)
            lmz.io.ArtifactStore.validate(artifact); folder=fileparts(path); if isempty(folder), folder=pwd; end
            tmp=[tempname(folder) '.mat']; cleanup=onCleanup(@()lmz.io.ArtifactStore.removeTemp(tmp));
            save(tmp,'artifact'); [ok,msg]=movefile(tmp,path,'f'); if ~ok, error('lmz:ArtifactWrite','%s',msg); end
            clear cleanup
        end
        function artifact=load(path)
            x=load(path,'artifact'); if ~isfield(x,'artifact'), error('lmz:ArtifactFormat','Missing top-level artifact.'); end
            artifact=x.artifact; lmz.io.ArtifactStore.validate(artifact);
        end
        function validate(a)
            required={'schemaVersion','artifactType','modelId','modelVersion','problemId','problemVersion','decisionSchema','parameterSchema','decisionValues','parameterValues','createdAt','matlabVersion','codeVersion'};
            for k=1:numel(required), if ~isfield(a,required{k}), error('lmz:ArtifactFormat','Missing artifact field %s.',required{k}); end, end
        end
        function removeTemp(path), if exist(path,'file'), delete(path); end, end
    end
end
