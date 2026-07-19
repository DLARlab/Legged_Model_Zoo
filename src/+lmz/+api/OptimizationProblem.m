classdef OptimizationProblem < lmz.api.BaseProblem
    %OPTIMIZATIONPROBLEM Base contract for objective/constraint problems.
    methods
        function obj=OptimizationProblem(varargin), obj@lmz.api.BaseProblem(varargin{:}); end
        function [lower,upper]=bounds(obj)
            lower=arrayfun(@(s)s.LowerBound,obj.DecisionSchema.Specs(:));
            upper=arrayfun(@(s)s.UpperBound,obj.DecisionSchema.Specs(:));
        end
        function [c,ceq]=nonlinearConstraints(~,varargin), c=[]; ceq=[]; end %#ok<INUSD>
        function value=optionalLinearConstraints(~), value=struct('A',[],'b',[],'Aeq',[],'beq',[]); end
    end
    methods (Abstract)
        [value,terms,diagnostics]=evaluateObjective(obj,u,p,context)
        value=objectiveTerms(obj)
    end
end
