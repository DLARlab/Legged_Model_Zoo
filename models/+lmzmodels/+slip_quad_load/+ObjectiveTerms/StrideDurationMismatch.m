classdef StrideDurationMismatch
    methods (Static)
        function term=evaluate(parameterRows,tExperimental,weight)
            count=size(parameterRows,1);source=[];target=[];value=0;
            for stride=1:count
                observed=getStride(tExperimental,stride);predicted=linspace(0,parameterRows(stride,9),numel(observed));
                observed=observed(:).';value=value+norm(observed-predicted);
                source=[source observed];target=[target predicted]; %#ok<AGROW>
            end
            term=struct('Name','stride_duration','Weight',weight,'Normalization','none', ...
                'ResamplingPolicy','uniform source-length grid from 0 to tAPEX', ...
                'Source',source,'Target',target,'Value',value, ...
                'Diagnostics',struct('StrideCount',count,'PerSourceLength',lengthsOf(tExperimental,count)));
        end
    end
end
function value=getStride(data,index)
if iscell(data),value=data{index};else,value=data(index,:);end
end
function value=lengthsOf(data,count)
value=zeros(1,count);for index=1:count,value(index)=numel(getStride(data,index));end
end
