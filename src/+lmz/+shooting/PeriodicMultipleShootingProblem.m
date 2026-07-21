classdef PeriodicMultipleShootingProblem < lmz.shooting.MultipleShootingProblem
    %PERIODICMULTIPLESHOOTINGPROBLEM Final closure after explicit defects.
    methods
        function obj=PeriodicMultipleShootingProblem(model,shootingSchema, ...
                parameterSchema,defaultParameters,horizon,segmentEvaluator, ...
                configuration)
            if nargin<7,configuration=struct();end
            configuration.Formulation='periodic';
            id=fieldOr(configuration,'ProblemId','multiple_shooting');
            obj@lmz.shooting.MultipleShootingProblem(model,id, ...
                shootingSchema,parameterSchema,defaultParameters,horizon, ...
                segmentEvaluator,configuration);
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
