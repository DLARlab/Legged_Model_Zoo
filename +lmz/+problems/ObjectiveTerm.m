classdef ObjectiveTerm
    methods (Static)
        function term=create(key,residual,weight,diagnostics),if nargin<4,diagnostics=struct();end;term=struct('key',char(key),'residual',residual(:),'weight',weight,'diagnostics',diagnostics);end
        function [value,diagnostic]=rSquared(observed,predicted),observed=observed(:);predicted=predicted(:);if numel(observed)~=numel(predicted),error('lmz:MetricSize','Observed and predicted vectors must match.');end;tss=sum((observed-mean(observed)).^2);if tss==0,value=NaN;diagnostic='zero_variance';else,value=1-sum((observed-predicted).^2)/tss;diagnostic='ok';end,end
        function [value,valid]=weightedMetric(values,weights),weights=weights(:);values=values(:);den=sum(weights);valid=isfinite(den)&&den>0;if valid,value=sum(weights.*values)/den;else,value=NaN;end,end
    end
end
