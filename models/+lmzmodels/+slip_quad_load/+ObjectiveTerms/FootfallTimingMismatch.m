classdef FootfallTimingMismatch
    methods (Static)
        function term=evaluate(parameterRows,experimental,weight)
            order=[1 2 3 4 7 8 5 6];count=size(parameterRows,1);
            source=[];target=[];r2Target=[];value=0;perStride=zeros(count,1);
            for stride=1:count
                predicted=parameterRows(stride,order)./parameterRows(stride,9);
                observed=experimental(stride,:);perStride(stride)=norm(predicted-observed);value=value+perStride(stride);
                source=[source observed];target=[target predicted];r2Target=[r2Target predicted+(stride-1)]; %#ok<AGROW>
            end
            term=struct('Name','footfall_timing','Weight',weight,'Normalization','event time divided by tAPEX', ...
                'ResamplingPolicy','none','Source',source,'Target',target,'Value',value, ...
                'Diagnostics',struct('StrideCount',count,'Permutation',order, ...
                'PerStrideValue',perStride,'R2Target',r2Target, ...
                'SourceLaterStrideOffsetPreserved',true));
        end
    end
end
