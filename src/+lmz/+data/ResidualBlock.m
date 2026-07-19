classdef ResidualBlock
    properties (SetAccess=private), Name; Values; Scale; end
    methods
        function obj=ResidualBlock(name,values,scale)
            if nargin<3, scale=ones(size(values)); end
            if any(~isfinite(values(:)))||any(~isfinite(scale(:)))||any(scale(:)<=0), error('lmz:Data:InvalidResidualBlock','Residual block values/scales are invalid.'); end
            obj.Name=name; obj.Values=values(:); obj.Scale=scale(:);
            if isscalar(obj.Scale), obj.Scale=repmat(obj.Scale,size(obj.Values)); end
            if numel(obj.Scale)~=numel(obj.Values), error('lmz:Data:ResidualScaleSize','Residual scale size mismatch.'); end
        end
        function value=scaled(obj), value=obj.Values./obj.Scale; end
        function value=toStruct(obj), value=struct('Name',obj.Name,'Values',obj.Values,'Scale',obj.Scale); end
    end
end
