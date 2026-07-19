classdef ContinuationService
    methods
        function result=run(~,problem,pair,options,context)
            if isstruct(options),options=lmz.continuation.ContinuationOptions(options);end
            result=lmz.continuation.PseudoArclengthContinuation().run(problem,pair,options,context); context.progress(1,'Continuation complete');
        end
        function result=parameterHomotopy(~,problem,seed,parameterName,targets,options,context)
            result=lmz.continuation.ParameterHomotopy().run(problem,seed,parameterName,targets,options,context);
        end
        function report=branchFamilyScan(~,problem,seed,parameterName,targets,options,context)
            defaults=struct('SecondSeedRadius',0.03,'ContinuationOptions',lmz.continuation.ContinuationOptions(struct('MaximumPoints',6,'BothDirections',false)));
            if nargin>=7&&~isempty(options),if isfield(options,'SecondSeedRadius'),defaults.SecondSeedRadius=options.SecondSeedRadius;end;if isfield(options,'ContinuationOptions'),defaults.ContinuationOptions=lmz.continuation.ContinuationOptions(options.ContinuationOptions);end,end
            report=lmz.continuation.BranchFamilyScan().run(problem,seed,parameterName,targets,defaults,context);
        end
    end
end
