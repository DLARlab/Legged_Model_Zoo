classdef ContinuationResult
    properties (SetAccess=private), Branch; Snapshots; TerminationReason; Options; Diagnostics; end
    methods
        function obj=ContinuationResult(branch,snapshots,reason,options,diagnostics)
            obj.Branch=branch;obj.Snapshots=snapshots;obj.TerminationReason=reason;obj.Options=options;obj.Diagnostics=diagnostics;
        end
        function artifact=toArtifact(obj)
            artifact=obj.Branch.toArtifact();artifact.artifactType='continuation-run';artifact.diagnostics=obj.Diagnostics;artifact.continuationResult=struct('Branch',obj.Branch.toStruct(),'TerminationReason',obj.TerminationReason,'Options',obj.Options,'Diagnostics',obj.Diagnostics);
        end
    end
end
