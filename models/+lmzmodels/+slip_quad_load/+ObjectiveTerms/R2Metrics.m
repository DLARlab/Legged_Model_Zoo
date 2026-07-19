classdef R2Metrics
    methods (Static)
        function [metrics,diagnostics]=compute(duration,footfall,loading,weights)
            [metrics.strideduration,guardDuration]=one(duration.Source,duration.Target);
            [metrics.footfalltiming,guardFootfall]=one(footfall.Source,footfall.Diagnostics.R2Target);
            [metrics.loadingforce,guardLoading]=one(loading.Source,loading.Target);
            total=sum(weights);guardWeighted=false;
            if total<=eps,metrics.weighted=mean([metrics.strideduration metrics.footfalltiming metrics.loadingforce]);guardWeighted=true;
            else,metrics.weighted=(weights(1)*metrics.strideduration+weights(2)*metrics.footfalltiming+weights(3)*metrics.loadingforce)/total;end
            diagnostics=struct('ZeroVarianceGuard',struct('StrideDuration',guardDuration, ...
                'FootfallTiming',guardFootfall,'LoadingForce',guardLoading,'ZeroWeight',guardWeighted));
        end
    end
end
function [value,guarded]=one(source,target)
source=source(:);target=target(:);rss=sum((source-target).^2);tss=sum((source-mean(source)).^2);
tolerance=eps(max(1,max(abs(source))))*max(1,numel(source));guarded=tss<=tolerance;
if guarded,value=double(rss<=tolerance);else,value=1-rss/tss;end
end
