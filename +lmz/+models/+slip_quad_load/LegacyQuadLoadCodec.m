classdef LegacyQuadLoadCodec
    properties (Constant), FirstStrideWidth=44; AdditionalStrideWidth=13; end
    methods
        function n=strideCount(obj,v),n=(numel(v)-obj.FirstStrideWidth)/obj.AdditionalStrideWidth+1;if n<1||fix(n)~=n,error('lmz:LegacyFormat','Length must be 44 + 13*(N-1).');end,end
        function data=decode(obj,v),v=v(:);n=obj.strideCount(v);data=struct('shared',v(1:44),'strides',{cell(1,n)});data.strides{1}=struct('initial',v(1:13),'events',v(14:22),'stride_parameters',v(28:31));for i=2:n,o=44+(i-2)*13;data.strides{i}=struct('initial',[],'events',v(o+(1:9)),'stride_parameters',v(o+(10:13)));end,end
        function v=encode(obj,data),n=numel(data.strides);v=data.shared(:);if numel(v)~=obj.FirstStrideWidth,error('lmz:LegacyFormat','Shared first stride requires 44 values.');end;for i=2:n,s=data.strides{i};v=[v;s.events(:);s.stride_parameters(:)];end;obj.strideCount(v);end
    end
end
