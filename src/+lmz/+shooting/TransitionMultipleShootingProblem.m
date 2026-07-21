classdef TransitionMultipleShootingProblem < lmz.shooting.MultipleShootingProblem
    %TRANSITIONMULTIPLESHOOTINGPROBLEM Final target without intermediate closure.
    methods
        function obj=TransitionMultipleShootingProblem(model,shootingSchema, ...
                parameterSchema,defaultParameters,horizon,segmentEvaluator, ...
                configuration)
            if nargin<7,configuration=struct();end
            configuration.Formulation='transition';
            id=fieldOr(configuration,'ProblemId','multiple_shooting_transition');
            obj@lmz.shooting.MultipleShootingProblem(model,id, ...
                shootingSchema,parameterSchema,defaultParameters,horizon, ...
                segmentEvaluator,configuration);
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
