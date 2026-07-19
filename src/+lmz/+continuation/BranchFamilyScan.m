classdef BranchFamilyScan
    methods
        function report=run(~,problem,seed,parameterName,targets,options,context)
            homotopy=lmz.continuation.ParameterHomotopy().run(problem,seed,parameterName,targets,struct(),context);branches=cell(1,numel(targets));failures=cell(1,numel(targets));status=repmat({'blocked'},1,numel(targets));artifacts=cell(1,numel(targets));
            for index=1:numel(targets)
                try
                    pair=lmz.services.SeedService().makeSecondSeed(problem,homotopy.Solutions(index),options.SecondSeedRadius,struct(),context);
                    branches{index}=lmz.continuation.PseudoArclengthContinuation().run(problem,pair,options.ContinuationOptions,context).Branch;status{index}='completed';artifacts{index}=branches{index}.toArtifact();
                catch exception,failures{index}=exception.message;status{index}='failed';end
            end
            report=struct('ParameterName',parameterName,'Targets',targets(:)','Branches',{branches}, ...
                'Failures',{failures},'Status',{status},'OutputArtifacts',{artifacts}, ...
                'Completed',sum(strcmp(status,'completed')),'Skipped',sum(strcmp(status,'skipped')), ...
                'Failed',sum(strcmp(status,'failed')),'Blocked',sum(strcmp(status,'blocked')), ...
                'Lineage',struct('sourceSolutionId',seed.Id,'sourceModelId',seed.ModelId, ...
                'sourceProblemId',seed.ProblemId));
        end
    end
end
