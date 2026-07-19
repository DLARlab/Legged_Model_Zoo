classdef LoadingForceMismatch
    methods (Static)
        function term=evaluate(raw,experimental,weight)
            count=raw.StrideCount;source=[];target=[];value=0;perStride=zeros(count,1);methods=cell(1,count);
            for stride=1:count
                boundary=raw.StrideBoundaries(stride);indices=boundary.RawStartIndex:boundary.RawEndIndex;
                predicted=raw.LegacyTuglineForce(indices);observed=getStride(experimental,stride);
                [resampled,method]=lmzmodels.slip_quad_load.ObjectiveTerms.LoadingForceMismatch.resample(observed,predicted);
                resampled=resampled(:);predicted=predicted(:);perStride(stride)=norm(resampled-predicted);value=value+perStride(stride);
                source=[source;resampled];target=[target;predicted];methods{stride}=method; %#ok<AGROW>
            end
            term=struct('Name','loading_force','Weight',weight,'Normalization','none', ...
                'ResamplingPolicy','normalized-index spline when upsampling, makima otherwise', ...
                'Source',source,'Target',target,'Value',value, ...
                'Diagnostics',struct('StrideCount',count,'PerStrideValue',perStride,'Methods',{methods}));
        end
        function [value,method]=resample(source,target)
            source=source(:);targetLength=numel(target);
            if isempty(source)||targetLength<1,error('lmz:QuadLoad:ForceData','Force traces cannot be empty.');end
            if numel(source)==1,value=repmat(source,targetLength,1);method='constant';return,end
            sourceIndex=linspace(0,1,numel(source));targetIndex=linspace(0,1,targetLength);
            if numel(source)<targetLength,method='spline';else,method='makima';end
            value=interp1(sourceIndex,source,targetIndex,method).';
        end
    end
end
function value=getStride(data,index)
if iscell(data),value=data{index};else,value=data(:,index);end
end
