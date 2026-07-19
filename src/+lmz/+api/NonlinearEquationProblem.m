classdef NonlinearEquationProblem < lmz.api.BaseProblem
    %NONLINEAREQUATIONPROBLEM Base contract for deterministic residuals.
    methods
        function obj=NonlinearEquationProblem(varargin), obj@lmz.api.BaseProblem(varargin{:}); end
        function value=residual(obj,u,p,context)
            value=obj.evaluate(u,p,context,false).ScaledResidual;
        end
        function value=unknownDimension(obj), value=obj.DecisionSchema.count(); end
        function value=residualDimension(obj)
            context=lmz.api.RunContext.synchronous(0);
            value=numel(obj.residual(obj.DecisionSchema.defaults(),obj.DefaultParameters,context));
        end
        function value=expectedLocalDimension(~), value=1; end
        function value=optionalJacobian(~,varargin), value=[]; end %#ok<INUSD>
        function [value,diagnostics]=projectSeed(~,u,varargin) %#ok<INUSD>
            value=u(:); diagnostics=struct('ChangedVariables',{{}},'Version','identity-v1');
        end
    end
    methods (Abstract)
        evaluation=evaluate(obj,u,p,context,includeSimulation)
    end
end
