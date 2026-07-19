classdef BranchFamilyScan
    methods
        function report=run(~,problem,seed,parameterName,targets,options,context)
            homotopy=lmz.continuation.ParameterHomotopy().run(problem,seed,parameterName,targets,struct(),context);branches=cell(1,numel(targets));failures=cell(1,numel(targets));
            for index=1:numel(targets)
                try
                    pair=lmz.services.SeedService().makeSecondSeed(problem,homotopy.Solutions(index),options.SecondSeedRadius,struct(),context);
                    branches{index}=lmz.continuation.PseudoArclengthContinuation().run(problem,pair,options.ContinuationOptions,context).Branch;
                catch exception,failures{index}=exception.message;end
            end
            report=struct('ParameterName',parameterName,'Targets',targets(:)','Branches',{branches}, ...
                'Failures',{failures},'Completed',sum(cellfun(@(x)~isempty(x),branches)), ...
                'Failed',sum(cellfun(@(x)~isempty(x),failures)),'Lineage',struct('sourceSolutionId',seed.Id));
        end
    end
end
