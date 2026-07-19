classdef SolverOptions
    properties
        FunctionTolerance=1e-10; StepTolerance=1e-10; OptimalityTolerance=1e-10
        MaxIterations=200; MaxFunctionEvaluations=2000; Display='off'; Algorithm='levenberg-marquardt'
    end
    methods
        function obj=SolverOptions(value)
            if nargin, names=fieldnames(value); for index=1:numel(names), if isprop(obj,names{index}),obj.(names{index})=value.(names{index});end,end,end
        end
        function value=toStruct(obj), names=properties(obj); value=struct(); for index=1:numel(names),value.(names{index})=obj.(names{index});end,end
    end
end
