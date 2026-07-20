classdef OptimizationResult
    %OPTIMIZATIONRESULT Reproducible optimization result and artifact record.
    properties (SetAccess=private), Solution; Objective; Terms; ExitFlag; Output; History; Options; SourceSeed; RandomSeed; Provenance; end
    methods
        function obj=OptimizationResult(solution,objective,terms,exitFlag,output,history,options,sourceSeed,randomSeed,provenance)
            obj.Solution=solution; obj.Objective=objective; obj.Terms=terms; obj.ExitFlag=exitFlag; obj.Output=output; obj.History=history; obj.Options=options; obj.SourceSeed=sourceSeed; obj.RandomSeed=randomSeed; obj.Provenance=provenance;
        end
        function artifact=toArtifact(obj)
            artifact=obj.Solution.toArtifact();artifact.artifactType='optimization-run';artifact.randomSeed=obj.RandomSeed;artifact.diagnostics=struct('ExitFlag',obj.ExitFlag,'Output',obj.Output,'Objective',obj.Objective,'Terms',obj.Terms);reason=lmz.data.OptimizationResult.terminationReason(obj.ExitFlag);elapsed=lmz.data.OptimizationResult.numericField(obj.Provenance,'elapsedTime',NaN);evaluations=lmz.data.OptimizationResult.numericField(obj.Output,'funcCount',NaN);details=struct('Options',obj.Options,'SourceSeed',obj.SourceSeed,'RandomSeed',obj.RandomSeed,'Provenance',obj.Provenance,'ElapsedTime',elapsed,'FunctionEvaluations',evaluations,'TerminationReason',reason,'Warnings',{{}});artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);artifact.optimizationResult=struct('Solution',obj.Solution.toStruct(),'Objective',obj.Objective,'Terms',obj.Terms,'History',obj.History,'Options',obj.Options,'SourceSeed',obj.SourceSeed,'Provenance',obj.Provenance,'TerminationReason',reason);
        end
    end
    methods (Static, Access=private)
        function value=terminationReason(exitFlag)
            if exitFlag>0,value='converged';elseif exitFlag==0,value='iteration-or-evaluation-limit';else,value='solver-failure';end
        end
        function value=numericField(source,name,fallback)
            value=fallback;if isstruct(source)&&isfield(source,name)&&isnumeric(source.(name))&&isscalar(source.(name)),value=source.(name);end
        end
    end
end
