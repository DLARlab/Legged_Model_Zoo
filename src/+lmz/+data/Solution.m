classdef Solution
    properties, ModelId; ModelVersion; ProblemId; ProblemVersion; DecisionValues; ParameterValues; Observables; Residuals; Diagnostics; Provenance; end
    methods
        function obj=Solution(s), if nargin, f=fieldnames(s); for k=1:numel(f), obj.(f{k})=s.(f{k}); end, end, end
        function s=toStruct(obj), p=properties(obj); s=struct(); for k=1:numel(p), s.(p{k})=obj.(p{k}); end, end
    end
end
