classdef DiagonalMetric
    properties (SetAccess=private), Scale; end
    methods
        function obj=DiagonalMetric(scale)
            if any(~isfinite(scale))||any(scale<=0), error('lmz:InvalidScale','Scales must be positive and finite.'); end
            obj.Scale=scale(:);
        end
        function n=norm(obj,d), n=norm(d(:)./obj.Scale); end
        function y=inner(obj,a,b), y=(a(:)./obj.Scale)'*(b(:)./obj.Scale); end
    end
end
