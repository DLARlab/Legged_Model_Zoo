classdef VariableChart
    properties (SetAccess=private), Schema; end
    methods
        function obj=VariableChart(schema), obj.Schema=schema; end
        function d=difference(obj,a,b)
            obj.Schema.validateVector(a); obj.Schema.validateVector(b); a=a(:); b=b(:); d=a-b;
            periods=obj.Schema.resolvePeriods(b);
            for k=1:obj.Schema.count()
                if isfinite(periods(k)), T=periods(k); d(k)=mod(d(k)+T/2,T)-T/2; end
            end
        end
        function u=retract(obj,base,delta)
            base=base(:); u=base+delta(:); periods=obj.Schema.resolvePeriods(base);
            for k=1:obj.Schema.count()
                if isfinite(periods(k)), u(k)=mod(u(k),periods(k)); end
            end
            obj.Schema.validateVector(u);
        end
        function u=canonicalize(obj,u), u=obj.retract(u,zeros(size(u))); end
    end
end
