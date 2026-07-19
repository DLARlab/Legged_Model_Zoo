classdef ContinuationResult
    properties (SetAccess=private), Branch; Snapshots; TerminationReason; Options; Diagnostics; end
    methods
        function obj=ContinuationResult(branch,snapshots,reason,options,diagnostics)
            obj.Branch=branch;obj.Snapshots=snapshots;obj.TerminationReason=reason;obj.Options=options;obj.Diagnostics=diagnostics;
        end
        function artifact=toArtifact(obj)
            snapshots=cell(numel(obj.Snapshots),1);
            for index=1:numel(obj.Snapshots)
                snapshots{index}=obj.Snapshots(index).toStruct();
            end
            artifact=obj.Branch.toArtifact();artifact.artifactType='continuation-run';artifact.diagnostics=obj.Diagnostics;artifact.continuationResult=struct('Branch',obj.Branch.toStruct(),'Snapshots',{snapshots},'TerminationReason',obj.TerminationReason,'Options',obj.Options,'Diagnostics',obj.Diagnostics);
        end
    end
end
