classdef Solution
    properties
        Id char=''; ModelId char=''; ProblemId char=''; Decision double=[]; Decoded=struct(); Evaluation=[]; Metadata=struct(); Provenance=struct()
    end
    methods
        function obj=Solution(varargin),if nargin>0,s=varargin{1};f=fieldnames(s);for i=1:numel(f),if isprop(obj,f{i}),obj.(f{i})=s.(f{i});end,end,end
        function s=toStruct(obj),p=properties(obj);s=struct();for i=1:numel(p),s.(p{i})=obj.(p{i});end,end
    end
end
