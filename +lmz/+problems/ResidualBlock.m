classdef ResidualBlock
    methods (Static), function b=create(key,kind,values,scale),if nargin<4,scale=ones(size(values));end;b=struct('key',char(key),'kind',char(kind),'values',values(:),'scale',lmz.core.NamedVectorSchema.expand(scale,numel(values)));end,end
end
