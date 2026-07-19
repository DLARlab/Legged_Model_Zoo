classdef OptimizationOptions
    properties, Algorithm='interior-point'; Display='off'; MaxIterations=200; MaxFunctionEvaluations=2000; OptimalityTolerance=1e-10; StepTolerance=1e-10; ConstraintTolerance=1e-8; end
    methods
        function obj=OptimizationOptions(value),if nargin,names=fieldnames(value);for index=1:numel(names),if isprop(obj,names{index}),obj.(names{index})=value.(names{index});end,end,end,end
        function value=toStruct(obj),names=properties(obj);value=struct();for index=1:numel(names),value.(names{index})=obj.(names{index});end,end
    end
end
