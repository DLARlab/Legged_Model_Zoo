classdef SolveResult
    properties (SetAccess=private), Solution; Evaluation; ExitFlag; Output; Options; SourceSeed; RandomSeed; Provenance; end
    methods
        function obj=SolveResult(solution,evaluation,exitFlag,output,options,sourceSeed,randomSeed,provenance)
            obj.Solution=solution; obj.Evaluation=evaluation; obj.ExitFlag=exitFlag; obj.Output=output; obj.Options=options; obj.SourceSeed=sourceSeed; obj.RandomSeed=randomSeed; obj.Provenance=provenance;
        end
        function artifact=toArtifact(obj)
            artifact=obj.Solution.toArtifact();artifact.artifactType='solve-run';artifact.randomSeed=obj.RandomSeed;artifact.diagnostics=struct('ExitFlag',obj.ExitFlag,'Output',obj.Output,'ResidualNorm',obj.Evaluation.ScaledResidualNorm);artifact.solveResult=struct('Solution',obj.Solution.toStruct(),'ExitFlag',obj.ExitFlag,'Output',obj.Output,'Options',obj.Options,'Provenance',obj.Provenance);
        end
    end
end
