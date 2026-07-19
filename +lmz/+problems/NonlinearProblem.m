classdef (Abstract) NonlinearProblem < handle
    methods (Abstract), metadata=metadata(obj); schema=decisionSchema(obj); evaluation=evaluate(obj,decisionVector,request); end
    methods
        function z=canonicalize(~,z),z=z(:);end
        function report=validateDecision(obj,z),report=obj.decisionSchema().validateVector(z);end
        function clearCache(~),end
    end
end
