classdef OptimizationResult
    properties (SetAccess=private), Solution; Objective; Terms; ExitFlag; Output; History; Options; SourceSeed; RandomSeed; Provenance; end
    methods
        function obj=OptimizationResult(solution,objective,terms,exitFlag,output,history,options,sourceSeed,randomSeed,provenance)
            obj.Solution=solution; obj.Objective=objective; obj.Terms=terms; obj.ExitFlag=exitFlag; obj.Output=output; obj.History=history; obj.Options=options; obj.SourceSeed=sourceSeed; obj.RandomSeed=randomSeed; obj.Provenance=provenance;
        end
        function artifact=toArtifact(obj)
            artifact=obj.Solution.toArtifact();artifact.artifactType='optimization-run';artifact.randomSeed=obj.RandomSeed;artifact.diagnostics=struct('ExitFlag',obj.ExitFlag,'Output',obj.Output,'Objective',obj.Objective,'Terms',obj.Terms);artifact.optimizationResult=struct('Solution',obj.Solution.toStruct(),'Objective',obj.Objective,'Terms',obj.Terms,'History',obj.History,'Options',obj.Options,'Provenance',obj.Provenance);
        end
    end
end
