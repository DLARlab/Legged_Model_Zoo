classdef SolveResult
    %SOLVERESULT Reproducible nonlinear-solve result and artifact record.
    properties (SetAccess=private), Solution; Evaluation; ExitFlag; Output; Options; SourceSeed; RandomSeed; Provenance; Progress; end
    methods
        function obj=SolveResult(solution,evaluation,exitFlag,output,options,sourceSeed,randomSeed,provenance,progress)
            if nargin<9,progress=[];end
            if ~isempty(progress)&&~isa(progress,'lmz.data.SolveProgress')
                error('lmz:Data:SolveResultProgress', ...
                    'SolveResult progress must be an lmz.data.SolveProgress.');
            end
            obj.Solution=solution; obj.Evaluation=evaluation; obj.ExitFlag=exitFlag; obj.Output=output; obj.Options=options; obj.SourceSeed=sourceSeed; obj.RandomSeed=randomSeed; obj.Provenance=provenance;obj.Progress=progress;
        end
        function artifact=toArtifact(obj)
            artifact=obj.Solution.toArtifact();artifact.artifactType='solve-run';artifact.randomSeed=obj.RandomSeed;artifact.diagnostics=struct('ExitFlag',obj.ExitFlag,'Output',obj.Output,'ResidualNorm',obj.Evaluation.ScaledResidualNorm);reason=lmz.data.SolveResult.terminationReason(obj.ExitFlag,obj.Output,obj.Progress);elapsed=lmz.data.SolveResult.numericField(obj.Provenance,'elapsedTime',NaN);evaluations=lmz.data.SolveResult.numericField(obj.Provenance,'evaluations',lmz.data.SolveResult.numericField(obj.Output,'funcCount',NaN));details=struct('Options',obj.Options,'SourceSeed',obj.SourceSeed,'RandomSeed',obj.RandomSeed,'Provenance',obj.Provenance,'ElapsedTime',elapsed,'FunctionEvaluations',evaluations,'TerminationReason',reason,'Warnings',{{}});artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);progress=struct('Events',{{}},'Snapshots',{{}},'CurrentStage','','Completed',false,'TerminationReason','');if ~isempty(obj.Progress),progress=obj.Progress.toStruct();end;artifact.solveProgress=progress;artifact.solveResult=struct('Solution',obj.Solution.toStruct(),'ExitFlag',obj.ExitFlag,'Output',obj.Output,'Options',obj.Options,'SourceSeed',obj.SourceSeed,'Provenance',obj.Provenance,'TerminationReason',reason,'Progress',progress);
        end
    end
    methods (Static, Access=private)
        function value=terminationReason(exitFlag,output,progress)
            if exitFlag>0,value='converged';elseif exitFlag==0,value='iteration-or-evaluation-limit';else,value='solver-failure';end
            if isstruct(output)&&isfield(output,'algorithm')&&strcmp(output.algorithm,'accepted-existing-seed'),value='accepted-existing-seed';end
            if isa(progress,'lmz.data.SolveProgress')&& ...
                    strcmp(progress.TerminationReason,'controlled_stop')
                value='controlled_stop';
            end
        end
        function value=numericField(source,name,fallback)
            value=fallback;if isstruct(source)&&isfield(source,name)&&isnumeric(source.(name))&&isscalar(source.(name)),value=source.(name);end
        end
    end
end
