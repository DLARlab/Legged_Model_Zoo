classdef ContinuationResult
    %CONTINUATIONRESULT Branch trace, diagnostics, seeds, and run metadata.
    properties (SetAccess=private), Branch; Snapshots; TerminationReason; Options; Diagnostics; SourcePair; RandomSeed; Provenance; end
    methods
        function obj=ContinuationResult(branch,snapshots,reason,options,diagnostics,sourcePair,randomSeed,provenance)
            if nargin<6||isempty(sourcePair),sourcePair=lmz.data.ContinuationResult.branchSeedPair(branch);end
            if nargin<7||isempty(randomSeed),randomSeed=0;end
            if nargin<8||isempty(provenance),provenance=struct();end
            obj.Branch=branch;obj.Snapshots=snapshots;obj.TerminationReason=reason;obj.Options=options;obj.Diagnostics=diagnostics;obj.SourcePair=sourcePair;obj.RandomSeed=randomSeed;obj.Provenance=provenance;
        end
        function artifact=toArtifact(obj)
            snapshots=cell(numel(obj.Snapshots),1);
            for index=1:numel(obj.Snapshots)
                snapshots{index}=obj.Snapshots(index).toStruct();
            end
            artifact=obj.Branch.toArtifact();artifact.artifactType='continuation-run';artifact.diagnostics=obj.Diagnostics;elapsed=lmz.data.ContinuationResult.numericField(obj.Provenance,'elapsedTime',NaN);evaluations=lmz.data.ContinuationResult.functionEvaluations(obj.Snapshots);details=struct('Options',obj.Options,'SourcePair',obj.SourcePair,'RandomSeed',obj.RandomSeed,'Provenance',obj.Provenance,'ElapsedTime',elapsed,'FunctionEvaluations',evaluations,'TerminationReason',obj.TerminationReason,'Warnings',{{}});artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);artifact.continuationResult=struct('Branch',obj.Branch.toStruct(),'Snapshots',{snapshots},'TerminationReason',obj.TerminationReason,'Options',obj.Options,'SourcePair',obj.SourcePair,'Provenance',obj.Provenance,'Diagnostics',obj.Diagnostics);
        end
    end
    methods (Static, Access=private)
        function value=branchSeedPair(branch)
            value=struct();if branch.pointCount()<2,return,end
            value=struct('First',branch.point(1).toStruct(), ...
                'Second',branch.point(2).toStruct(),'RequestedRadius',NaN, ...
                'AchievedRadius',branch.Arclength(2)-branch.Arclength(1), ...
                'Diagnostics',struct('source','branch-prefix'));
        end
        function value=numericField(source,name,fallback)
            value=fallback;if isstruct(source)&&isfield(source,name)&&isnumeric(source.(name))&&isscalar(source.(name)),value=source.(name);end
        end
        function value=functionEvaluations(snapshots)
            value=0;known=false;
            for index=1:numel(snapshots)
                diagnostics=snapshots(index).Diagnostics;
                if isfield(diagnostics,'CorrectorOutput')&&isstruct(diagnostics.CorrectorOutput)&&isfield(diagnostics.CorrectorOutput,'funcCount')
                    value=value+diagnostics.CorrectorOutput.funcCount;known=true;
                end
            end
            if ~known,value=NaN;end
        end
    end
end
